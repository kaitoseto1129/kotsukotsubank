//
//  SupabaseSync.swift
//  コツコツバンク
//
//  子ども・目標・タスクを Supabase 経由で端末間同期する。
//  方式: ローカル(SwiftData)を編集の起点としつつ、変更を Supabase に upsert し、
//  他端末の変更を updated_at の新しい順で取り込む「ラストライトウィン」。
//  リアルタイム購読はせず、ログイン時・アプリ復帰時・ローカル保存後(3秒デバウンス)に同期する。
//

import Foundation
import SwiftData
import Supabase
import CryptoKit

// MARK: - 削除の伝播用「墓標」

/// ローカルで行を hard delete する直前に1件挿入する。
/// 同期時に Supabase 側の該当行へ deleted_at を立て、他端末はそれを見て削除する。
@Model
final class SyncTombstone {
    var rowID: UUID = UUID()
    /// "child_profiles" / "goals" / "missions"
    var table: String = ""
    var accountID: UUID = UUID()
    var createdAt: Date = Date.now

    init(rowID: UUID, table: String, accountID: UUID) {
        self.rowID = rowID
        self.table = table
        self.accountID = accountID
        self.createdAt = .now
    }
}

// MARK: - タイムスタンプ変換

enum SyncTime {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func string(_ date: Date) -> String { withFraction.string(from: date) }

    /// Postgres の timestamptz("2026-09-05T12:34:56.789123+00:00" 等)をゆるくパースする。
    static func date(_ raw: String?) -> Date? {
        guard var s = raw, !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: " ", with: "T")
        // タイムゾーンが "+00" のように分が無ければ ":00" を補う
        if let tz = s.range(of: #"[+-]\d{2}$"#, options: .regularExpression) {
            s.replaceSubrange(tz, with: s[tz] + ":00")
        }
        // 小数秒を最大3桁に丸める(ISO8601DateFormatter は3桁想定)
        if let dot = s.range(of: #"\.\d+"#, options: .regularExpression) {
            let digits = s[dot].dropFirst().prefix(3)
            s.replaceSubrange(dot, with: "." + digits)
        }
        return withFraction.date(from: s) ?? plain.date(from: s)
    }
}

// MARK: - 行 DTO(列名に合わせて snake_case)

private struct ChildRow: Codable {
    var id: String
    var account_id: String
    var name: String
    var avatar_system_image: String
    var color_hex: String
    var avatar_image_data: String?
    var background_color_hex: String
    var empty_state_icon_name: String
    var parent_turn_pending: Bool
    var last_level5_streak_trigger: Int
    var parent_turn_task_title: String?
    var created_at: String
    var updated_at: String
    var deleted_at: String?
}

private struct GoalRow: Codable {
    var id: String
    var account_id: String
    var child_id: String
    var title: String
    var price: Double
    var product_url: String?
    var image_data: String?
    var redeemed_at: String?
    var created_at: String
    var updated_at: String
    var deleted_at: String?
}

private struct MissionRow: Codable {
    var id: String
    var account_id: String
    var child_id: String
    var title: String
    var reward: Double
    var reward_unit_raw: String
    var category_raw: String
    var status_raw: String
    var due_date: String?
    var completed_at: String?
    var timer_accumulated_seconds: Double
    var timer_started_at: String?
    var photo_data: String?
    var comment: String?
    var parent_feedback: String?
    var celebration_played: Bool
    var preset_icon_name: String?
    var created_at: String
    var updated_at: String
    var deleted_at: String?
}

/// 墓標を Supabase に送るときの最小ペイロード(NOT NULL 列は DB のデフォルトに任せる)
private struct TombstoneRow: Encodable {
    var id: String
    var account_id: String
    var updated_at: String
    var deleted_at: String
}

// MARK: - 同期本体

@MainActor
final class SupabaseSync {
    static let shared = SupabaseSync()
    private init() {}

    private var accountID: UUID?
    private var context: ModelContext?
    private var saveObserver: NSObjectProtocol?
    private var debounce: Task<Void, Never>?
    private var running = false
    private var applyingRemote = false
    private var signatures: [String: String] = [:]

    private let epochString = SyncTime.string(Date(timeIntervalSince1970: 0))

    // MARK: ライフサイクル

    func start(accountID: UUID, context: ModelContext) {
        if self.accountID != accountID {
            signatures = Self.loadSignatures(accountID: accountID)
        }
        self.accountID = accountID
        self.context = context
        backfillAccountIDsFromChildren(context: context)
        if saveObserver == nil {
            saveObserver = NotificationCenter.default.addObserver(
                forName: ModelContext.didSave, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onLocalSave() }
            }
        }
        Task { await syncNow() }
    }

    func stop() {
        if let saveObserver { NotificationCenter.default.removeObserver(saveObserver) }
        saveObserver = nil
        debounce?.cancel()
        debounce = nil
        accountID = nil
        context = nil
    }

    private func onLocalSave() {
        guard !applyingRemote, accountID != nil else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { return }
            await self?.syncNow()
        }
    }

    /// アプリ復帰時などに外から呼ぶ
    func syncNow() async {
        guard let accountID, let context, !running else { return }
        running = true
        defer { running = false }
        do {
            try await pushLocalChanges(accountID: accountID, context: context)
            try await pullRemoteChanges(accountID: accountID, context: context)
        } catch {
            print("SupabaseSync: \(error)")
        }
    }

    // MARK: 既存データの accountID 補正

    /// 旧バージョンで作られた目標/タスクは accountID が未設定(ランダム)なので、
    /// 紐づく子どもの accountID で上書きしておく。
    private func backfillAccountIDsFromChildren(context: ModelContext) {
        let children = (try? context.fetch(FetchDescriptor<ChildProfile>())) ?? []
        guard !children.isEmpty else { return }
        let map = Dictionary(children.map { ($0.id, $0.accountID) }, uniquingKeysWith: { first, _ in first })
        for g in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] {
            if let acc = map[g.childID], g.accountID != acc { g.accountID = acc }
        }
        for m in (try? context.fetch(FetchDescriptor<Mission>())) ?? [] {
            if let acc = map[m.childID], m.accountID != acc { m.accountID = acc }
        }
    }

    /// ログイン時に、ローカルのアカウント/子ども/目標/タスクの所属IDを Supabase のユーザーIDに揃える。
    /// (旧アプリで作ったアカウントは id が Supabase の uid と一致しないため)
    static func normalizeLocalIdentities(account: FamilyAccount, supabaseUserID: UUID, context: ModelContext) {
        let children = (try? context.fetch(FetchDescriptor<ChildProfile>())) ?? []
        let map = Dictionary(children.map { ($0.id, $0.accountID) }, uniquingKeysWith: { first, _ in first })
        for g in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] {
            if let acc = map[g.childID] { g.accountID = acc }
        }
        for m in (try? context.fetch(FetchDescriptor<Mission>())) ?? [] {
            if let acc = map[m.childID] { m.accountID = acc }
        }

        let oldID = account.id
        guard oldID != supabaseUserID else { return }
        account.id = supabaseUserID
        for c in children where c.accountID == oldID { c.accountID = supabaseUserID }
        for g in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] where g.accountID == oldID {
            g.accountID = supabaseUserID
        }
        for m in (try? context.fetch(FetchDescriptor<Mission>())) ?? [] where m.accountID == oldID {
            m.accountID = supabaseUserID
        }
    }

    // MARK: push

    private func pushLocalChanges(accountID: UUID, context: ModelContext) async throws {
        let acc = accountID
        let children = try context.fetch(FetchDescriptor<ChildProfile>(predicate: #Predicate { $0.accountID == acc }))
        let goals = try context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.accountID == acc }))
        let missions = try context.fetch(FetchDescriptor<Mission>(predicate: #Predicate { $0.accountID == acc }))

        // 1行ずつ upsert する。写真つきタスクなどで1件失敗しても他をブロックしないため、
        // 成功した行だけ署名キャッシュを更新して次回スキップする。
        for c in children {
            let sig = signature(child: c)
            guard isDirty(id: c.id, signature: sig) else { continue }
            c.updatedAt = .now
            do {
                try await supabase.from("child_profiles").upsert(row(child: c), onConflict: "id").execute()
                signatures[c.id.uuidString] = sig
            } catch { print("SupabaseSync push child \(c.id): \(error)") }
        }
        for g in goals {
            let sig = signature(goal: g)
            guard isDirty(id: g.id, signature: sig) else { continue }
            g.updatedAt = .now
            do {
                try await supabase.from("goals").upsert(row(goal: g), onConflict: "id").execute()
                signatures[g.id.uuidString] = sig
            } catch { print("SupabaseSync push goal \(g.id): \(error)") }
        }
        for m in missions {
            let sig = signature(mission: m)
            guard isDirty(id: m.id, signature: sig) else { continue }
            m.updatedAt = .now
            do {
                try await supabase.from("missions").upsert(row(mission: m), onConflict: "id").execute()
                signatures[m.id.uuidString] = sig
            } catch { print("SupabaseSync push mission \(m.id): \(error)") }
        }

        // 墓標(削除の伝播)
        let tombs = try context.fetch(FetchDescriptor<SyncTombstone>(predicate: #Predicate { $0.accountID == acc }))
        let now = SyncTime.string(.now)
        for t in tombs {
            let payload = TombstoneRow(id: t.rowID.uuidString.lowercased(),
                                       account_id: acc.uuidString.lowercased(),
                                       updated_at: now, deleted_at: now)
            do {
                try await supabase.from(t.table).upsert(payload, onConflict: "id").execute()
                applyingRemote = true
                context.delete(t)
                applyingRemote = false
                signatures.removeValue(forKey: t.rowID.uuidString)
            } catch { print("SupabaseSync push tombstone \(t.rowID): \(error)") }
        }

        // 端末から消えた行の署名は掃除する
        let liveIDs = Set(children.map { $0.id.uuidString } + goals.map { $0.id.uuidString } + missions.map { $0.id.uuidString })
        for key in signatures.keys where !liveIDs.contains(key) { signatures.removeValue(forKey: key) }
        Self.saveSignatures(signatures, accountID: acc)
    }

    // MARK: pull

    private func pullRemoteChanges(accountID: UUID, context: ModelContext) async throws {
        let acc = accountID
        let since = Self.lastPull(accountID: acc) ?? epochString
        var newestSeen = since

        // --- children ---
        let childRows: [ChildRow] = try await supabase.from("child_profiles")
            .select()
            .eq("account_id", value: acc.uuidString.lowercased())
            .gt("updated_at", value: since)
            .execute().value
        if !childRows.isEmpty {
            let locals = try context.fetch(FetchDescriptor<ChildProfile>(predicate: #Predicate { $0.accountID == acc }))
            var byID = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            applyingRemote = true
            for r in childRows {
                newestSeen = max(newestSeen, r.updated_at)
                guard let rid = UUID(uuidString: r.id) else { continue }
                if r.deleted_at != nil {
                    if let local = byID[rid] { context.delete(local); byID[rid] = nil }
                    continue
                }
                let remoteDate = SyncTime.date(r.updated_at) ?? .distantPast
                if let local = byID[rid] {
                    if remoteDate > local.updatedAt { apply(r, to: local) }
                } else {
                    let c = ChildProfile(id: rid, accountID: acc, name: r.name)
                    apply(r, to: c)
                    context.insert(c)
                    byID[rid] = c
                }
            }
            applyingRemote = false
        }

        // --- goals ---
        let goalRows: [GoalRow] = try await supabase.from("goals")
            .select()
            .eq("account_id", value: acc.uuidString.lowercased())
            .gt("updated_at", value: since)
            .execute().value
        if !goalRows.isEmpty {
            let locals = try context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.accountID == acc }))
            var byID = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            applyingRemote = true
            for r in goalRows {
                newestSeen = max(newestSeen, r.updated_at)
                guard let rid = UUID(uuidString: r.id) else { continue }
                if r.deleted_at != nil {
                    if let local = byID[rid] { context.delete(local); byID[rid] = nil }
                    continue
                }
                let remoteDate = SyncTime.date(r.updated_at) ?? .distantPast
                if let local = byID[rid] {
                    if remoteDate > local.updatedAt { apply(r, to: local) }
                } else {
                    let g = Goal(id: rid, accountID: acc, title: r.title, price: r.price,
                                 childID: UUID(uuidString: r.child_id) ?? UUID())
                    apply(r, to: g)
                    context.insert(g)
                    byID[rid] = g
                }
            }
            applyingRemote = false
        }

        // --- missions ---
        let missionRows: [MissionRow] = try await supabase.from("missions")
            .select()
            .eq("account_id", value: acc.uuidString.lowercased())
            .gt("updated_at", value: since)
            .execute().value
        if !missionRows.isEmpty {
            let locals = try context.fetch(FetchDescriptor<Mission>(predicate: #Predicate { $0.accountID == acc }))
            var byID = Dictionary(locals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            applyingRemote = true
            for r in missionRows {
                newestSeen = max(newestSeen, r.updated_at)
                guard let rid = UUID(uuidString: r.id) else { continue }
                if r.deleted_at != nil {
                    if let local = byID[rid] { context.delete(local); byID[rid] = nil }
                    continue
                }
                let remoteDate = SyncTime.date(r.updated_at) ?? .distantPast
                if let local = byID[rid] {
                    if remoteDate > local.updatedAt { apply(r, to: local) }
                } else {
                    let m = Mission(id: rid, accountID: acc, title: r.title, reward: r.reward,
                                    childID: UUID(uuidString: r.child_id) ?? UUID())
                    apply(r, to: m)
                    context.insert(m)
                    byID[rid] = m
                }
            }
            applyingRemote = false
        }

        if newestSeen != since {
            Self.setLastPull(newestSeen, accountID: acc)
        }
        // 取り込んだ行はローカル＝リモートなので、次回 push しないよう署名を更新
        let allChildren = try context.fetch(FetchDescriptor<ChildProfile>(predicate: #Predicate { $0.accountID == acc }))
        let allGoals = try context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.accountID == acc }))
        let allMissions = try context.fetch(FetchDescriptor<Mission>(predicate: #Predicate { $0.accountID == acc }))
        rebuildSignatures(children: allChildren, goals: allGoals, missions: allMissions)
        Self.saveSignatures(signatures, accountID: acc)
    }

    // MARK: 署名(内容が変わったかの判定。updatedAt は含めない)

    private func isDirty(id: UUID, signature: String) -> Bool {
        signatures[id.uuidString] != signature
    }

    private func rebuildSignatures(children: [ChildProfile], goals: [Goal], missions: [Mission]) {
        var next: [String: String] = [:]
        for c in children { next[c.id.uuidString] = signature(child: c) }
        for g in goals { next[g.id.uuidString] = signature(goal: g) }
        for m in missions { next[m.id.uuidString] = signature(mission: m) }
        signatures = next
    }

    private func sha(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func signature(child c: ChildProfile) -> String {
        sha([
            c.name, c.avatarSystemImage, c.colorHex, c.backgroundColorHex, c.emptyStateIconName,
            String(c.parentTurnPending), String(c.lastLevel5StreakTrigger), c.parentTurnTaskTitle ?? "",
            c.avatarImageData?.base64EncodedString() ?? "", SyncTime.string(c.createdAt), c.accountID.uuidString
        ].joined(separator: "|"))
    }

    private func signature(goal g: Goal) -> String {
        sha([
            g.title, String(g.price), g.productURL ?? "", g.imageData?.base64EncodedString() ?? "",
            g.redeemedAt.map(SyncTime.string) ?? "", g.childID.uuidString, g.accountID.uuidString,
            SyncTime.string(g.createdAt)
        ].joined(separator: "|"))
    }

    private func signature(mission m: Mission) -> String {
        sha([
            m.title, String(m.reward), m.rewardUnitRaw, m.categoryRaw, m.statusRaw,
            m.dueDate.map(SyncTime.string) ?? "", m.completedAt.map(SyncTime.string) ?? "",
            String(m.timerAccumulatedSeconds), m.timerStartedAt.map(SyncTime.string) ?? "",
            m.photoData?.base64EncodedString() ?? "", m.comment ?? "", m.parentFeedback ?? "",
            String(m.celebrationPlayed), m.presetIconName ?? "", m.childID.uuidString,
            m.accountID.uuidString, SyncTime.string(m.createdAt)
        ].joined(separator: "|"))
    }

    // MARK: 変換 model -> row

    private func row(child c: ChildProfile) -> ChildRow {
        ChildRow(
            id: c.id.uuidString.lowercased(),
            account_id: c.accountID.uuidString.lowercased(),
            name: c.name,
            avatar_system_image: c.avatarSystemImage,
            color_hex: c.colorHex,
            avatar_image_data: c.avatarImageData?.base64EncodedString(),
            background_color_hex: c.backgroundColorHex,
            empty_state_icon_name: c.emptyStateIconName,
            parent_turn_pending: c.parentTurnPending,
            last_level5_streak_trigger: c.lastLevel5StreakTrigger,
            parent_turn_task_title: c.parentTurnTaskTitle,
            created_at: SyncTime.string(c.createdAt),
            updated_at: SyncTime.string(c.updatedAt),
            deleted_at: nil
        )
    }

    private func row(goal g: Goal) -> GoalRow {
        GoalRow(
            id: g.id.uuidString.lowercased(),
            account_id: g.accountID.uuidString.lowercased(),
            child_id: g.childID.uuidString.lowercased(),
            title: g.title,
            price: g.price,
            product_url: g.productURL,
            image_data: g.imageData?.base64EncodedString(),
            redeemed_at: g.redeemedAt.map(SyncTime.string),
            created_at: SyncTime.string(g.createdAt),
            updated_at: SyncTime.string(g.updatedAt),
            deleted_at: nil
        )
    }

    private func row(mission m: Mission) -> MissionRow {
        MissionRow(
            id: m.id.uuidString.lowercased(),
            account_id: m.accountID.uuidString.lowercased(),
            child_id: m.childID.uuidString.lowercased(),
            title: m.title,
            reward: m.reward,
            reward_unit_raw: m.rewardUnitRaw,
            category_raw: m.categoryRaw,
            status_raw: m.statusRaw,
            due_date: m.dueDate.map(SyncTime.string),
            completed_at: m.completedAt.map(SyncTime.string),
            timer_accumulated_seconds: m.timerAccumulatedSeconds,
            timer_started_at: m.timerStartedAt.map(SyncTime.string),
            photo_data: m.photoData?.base64EncodedString(),
            comment: m.comment,
            parent_feedback: m.parentFeedback,
            celebration_played: m.celebrationPlayed,
            preset_icon_name: m.presetIconName,
            created_at: SyncTime.string(m.createdAt),
            updated_at: SyncTime.string(m.updatedAt),
            deleted_at: nil
        )
    }

    // MARK: 変換 row -> model

    private func apply(_ r: ChildRow, to c: ChildProfile) {
        c.name = r.name
        c.avatarSystemImage = r.avatar_system_image
        c.colorHex = r.color_hex
        c.avatarImageData = r.avatar_image_data.flatMap { Data(base64Encoded: $0) }
        c.backgroundColorHex = r.background_color_hex
        c.emptyStateIconName = r.empty_state_icon_name
        c.parentTurnPending = r.parent_turn_pending
        c.lastLevel5StreakTrigger = r.last_level5_streak_trigger
        c.parentTurnTaskTitle = r.parent_turn_task_title
        c.createdAt = SyncTime.date(r.created_at) ?? c.createdAt
        c.updatedAt = SyncTime.date(r.updated_at) ?? .now
    }

    private func apply(_ r: GoalRow, to g: Goal) {
        g.childID = UUID(uuidString: r.child_id) ?? g.childID
        g.title = r.title
        g.price = r.price
        g.productURL = r.product_url
        g.imageData = r.image_data.flatMap { Data(base64Encoded: $0) }
        g.redeemedAt = SyncTime.date(r.redeemed_at)
        g.createdAt = SyncTime.date(r.created_at) ?? g.createdAt
        g.updatedAt = SyncTime.date(r.updated_at) ?? .now
    }

    private func apply(_ r: MissionRow, to m: Mission) {
        m.childID = UUID(uuidString: r.child_id) ?? m.childID
        m.title = r.title
        m.reward = r.reward
        m.rewardUnitRaw = r.reward_unit_raw
        m.categoryRaw = r.category_raw
        m.statusRaw = r.status_raw
        m.dueDate = SyncTime.date(r.due_date)
        m.completedAt = SyncTime.date(r.completed_at)
        m.timerAccumulatedSeconds = r.timer_accumulated_seconds
        m.timerStartedAt = SyncTime.date(r.timer_started_at)
        m.photoData = r.photo_data.flatMap { Data(base64Encoded: $0) }
        m.comment = r.comment
        m.parentFeedback = r.parent_feedback
        m.celebrationPlayed = r.celebration_played
        m.presetIconName = r.preset_icon_name
        m.createdAt = SyncTime.date(r.created_at) ?? m.createdAt
        m.updatedAt = SyncTime.date(r.updated_at) ?? .now
    }

    // MARK: 永続化(UserDefaults)

    private static func lastPullKey(_ acc: UUID) -> String { "sync.lastPull.\(acc.uuidString)" }
    private static func sigKey(_ acc: UUID) -> String { "sync.sig.\(acc.uuidString)" }

    private static func lastPull(accountID: UUID) -> String? {
        UserDefaults.standard.string(forKey: lastPullKey(accountID))
    }
    private static func setLastPull(_ value: String, accountID: UUID) {
        UserDefaults.standard.set(value, forKey: lastPullKey(accountID))
    }
    private static func loadSignatures(accountID: UUID) -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: sigKey(accountID)) as? [String: String]) ?? [:]
    }
    private static func saveSignatures(_ dict: [String: String], accountID: UUID) {
        UserDefaults.standard.set(dict, forKey: sigKey(accountID))
    }
}

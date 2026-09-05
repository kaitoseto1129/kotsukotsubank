//
//  TaskManagementView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

struct TaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    let child: ChildProfile

    @Query private var allMissions: [Mission]

    @State private var newTaskTitle = ""
    @State private var newTaskReward = ""
    @State private var newTaskCategory: TaskCategory = .chores
    @State private var newTaskPresetIcon: String?
    @State private var missionPendingDeletion: Mission?
    @State private var editingMission: Mission?
    @State private var viewingMission: Mission?
    @State private var selectedCategoryFilter: TaskCategory?
    @State private var justAddedTaskTitle: String?
    @State private var showCompletedHistory = false

    private var missionsForChild: [Mission] {
        allMissions.filter { $0.childID == child.id }.sorted { $0.createdAt > $1.createdAt }
    }

    private var submittedMissions: [Mission] {
        missionsForChild.filter { $0.status == .submitted }
    }

    /// まだ完了していない(承認済みでない)、子供に割り当てたタスクの一覧
    private var activeMissions: [Mission] {
        missionsForChild.filter { $0.status != .approved && $0.status != .submitted }
    }

    /// カテゴリで絞り込んだ、登録済みタスクの一覧(「すべて」選択時は絞り込まない)
    private var filteredActiveMissions: [Mission] {
        guard let selectedCategoryFilter else { return activeMissions }
        return activeMissions.filter { $0.category == selectedCategoryFilter }
    }

    private var approvedMissions: [Mission] {
        missionsForChild
            .filter { $0.status == .approved }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    private var rejectedMissions: [Mission] {
        missionsForChild
            .filter { $0.status == .rejected }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var currencyCode: String {
        session.account?.currencyCode ?? AppCurrency.jpy.rawValue
    }

    private var currencySymbol: String {
        (AppCurrency(rawValue: currencyCode) ?? .jpy).symbol
    }

    private var appLocale: Locale {
        appLanguage.locale
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: session.account?.languageCode ?? AppLanguage.ja.rawValue) ?? .ja
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SectionHeader(icon: "plus.circle.fill", title: "タスクを追加", color: .blue)

                VStack(spacing: 10) {
                    Menu {
                        ForEach(TaskPreset.samples) { preset in
                            Button {
                                newTaskTitle = appLanguage.localizedString(forKey: preset.title)
                                newTaskCategory = preset.category
                                newTaskPresetIcon = preset.icon
                            } label: {
                                Label {
                                    Text("\(Text(LocalizedStringKey(preset.title)))(\(currencySymbol)00)")
                                } icon: {
                                    Image(systemName: preset.icon)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("よくあるタスクから選ぶ")
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(ParentTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(ParentTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    ParentTextField(title: "タスク名", text: $newTaskTitle, icon: "pencil")
                    ParentTextField(title: "タスク価格", text: $newTaskReward, isNumeric: true, icon: AppCurrency(rawValue: currencyCode)?.systemImage ?? "yensign.circle.fill")

                    Picker("カテゴリ", selection: $newTaskCategory) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Label(LocalizedStringKey(category.label), systemImage: category.icon).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)

                    ParentPrimaryButton(
                        title: "タスク追加",
                        isEnabled: !newTaskTitle.isEmpty && Double(newTaskReward) != nil,
                        action: addTask
                    )

                    if let justAddedTaskTitle {
                        Label {
                            Text("「\(Text(LocalizedStringKey(justAddedTaskTitle)))」を追加しました")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .cardStyle()
                .animation(.easeInOut(duration: 0.25), value: justAddedTaskTitle)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("入力例")
                            .font(.subheadline.bold())
                        Text("上の「よくあるタスクから選ぶ」から選ぶか、タスク名: 「お皿洗い」 タスク価格: 「50」のように自由入力もできます")
                            .font(.footnote)
                            .foregroundStyle(.primary.opacity(0.75))
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    seedDemoData()
                } label: {
                    Label("サンプルデータを追加(動作確認用)", systemImage: "wand.and.stars")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    DemoDataSeeder.seedLevel5Streak(for: child, context: modelContext)
                } label: {
                    Label("サプライズ演出を試す(動作確認用)", systemImage: "crown.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    SoundEffects.playFanfareSound()
                } label: {
                    Label("ラッパの音を試聴(動作確認用)", systemImage: "speaker.wave.3.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if !activeMissions.isEmpty {
                    SectionHeader(icon: "list.bullet.rectangle.fill", title: "登録済みタスク", color: .indigo)

                    Picker("カテゴリで絞り込み", selection: $selectedCategoryFilter) {
                        Text("すべて").tag(TaskCategory?.none)
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            Text(LocalizedStringKey(category.label)).tag(TaskCategory?.some(category))
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 0) {
                        ForEach(filteredActiveMissions) { mission in
                            Button {
                                editingMission = mission
                            } label: {
                                HStack {
                                    statusDot(for: mission)
                                    Image(systemName: mission.category.icon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(LocalizedStringKey(mission.title))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    if let dueDate = mission.dueDate {
                                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(moneyString(mission.reward, currencyCode: currencyCode))\(mission.rewardUnit.suffix)")
                                        .font(.caption.bold())
                                        .foregroundStyle(ParentTheme.accentSoft)
                                    Button {
                                        missionPendingDeletion = mission
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(ParentTheme.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("「\(mission.title)」を削除")
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 12)

                            if mission.id != filteredActiveMissions.last?.id {
                                Divider()
                            }
                        }

                        if filteredActiveMissions.isEmpty {
                            Text("このカテゴリのタスクはありません")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 14)
                    .cardStyle(padding: 0)
                }

                SectionHeader(icon: "checkmark.seal.fill", title: "タスク承認", color: .green)

                if submittedMissions.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundStyle(.secondary)
                        Text("承認待ちのタスクはありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                } else {
                    VStack(spacing: 12) {
                        ForEach(submittedMissions) { mission in
                            ApprovalCard(
                                mission: mission,
                                onApprove: { message in approve(mission, message: message) },
                                onReject: { feedback in reject(mission, feedback: feedback) }
                            )
                        }
                    }
                }

                if !approvedMissions.isEmpty || !rejectedMissions.isEmpty {
                    Button {
                        withAnimation { showCompletedHistory.toggle() }
                    } label: {
                        HStack {
                            SectionHeader(icon: "clock.arrow.circlepath", title: "完了・却下したタスク", color: .purple)
                            Spacer()
                            Image(systemName: showCompletedHistory ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showCompletedHistory {
                        VStack(spacing: 0) {
                            ForEach(approvedMissions) { mission in
                                completedRow(mission)
                                if mission.id != approvedMissions.last?.id || !rejectedMissions.isEmpty {
                                    Divider()
                                }
                            }
                            ForEach(rejectedMissions) { mission in
                                completedRow(mission)
                                if mission.id != rejectedMissions.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .cardStyle(padding: 0)
                    }
                }
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .navigationTitle("タスク管理・承認")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
        }
        .confirmationDialog(
            "「\(missionPendingDeletion?.title ?? "")」を削除しますか?",
            isPresented: Binding(
                get: { missionPendingDeletion != nil },
                set: { if !$0 { missionPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let mission = missionPendingDeletion {
                    modelContext.delete(mission)
                }
                missionPendingDeletion = nil
            }
            Button("キャンセル", role: .cancel) {
                missionPendingDeletion = nil
            }
        }
        .sheet(item: $editingMission) { mission in
            EditTaskView(mission: mission)
        }
        .sheet(item: $viewingMission) { mission in
            MissionDetailSheet(mission: mission)
        }
    }

    @ViewBuilder
    private func completedRow(_ mission: Mission) -> some View {
        Button {
            viewingMission = mission
        } label: {
            HStack {
                Image(systemName: mission.status == .approved ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(mission.status == .approved ? .green : ParentTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(mission.title))
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text((mission.completedAt ?? mission.createdAt).formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(mission.status == .approved ? moneyString(mission.payoutAmount, currencyCode: currencyCode) : "却下")
                    .font(.caption.bold())
                    .foregroundStyle(mission.status == .approved ? ParentTheme.accentSoft : ParentTheme.accent)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func statusDot(for mission: Mission) -> some View {
        let color: Color = switch mission.status {
        case .pending: .gray
        case .inProgress: ParentTheme.accentSoft
        case .rejected: ParentTheme.accent
        default: .gray
        }
        Circle().fill(color).frame(width: 8, height: 8)
    }

    private func addTask() {
        guard let reward = Double(newTaskReward) else { return }
        let mission = Mission(
            title: newTaskTitle,
            reward: reward,
            category: newTaskCategory,
            presetIconName: newTaskPresetIcon,
            childID: child.id
        )
        modelContext.insert(mission)

        let addedTitle = newTaskTitle
        justAddedTaskTitle = addedTitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if justAddedTaskTitle == addedTitle {
                justAddedTaskTitle = nil
            }
        }

        newTaskTitle = ""
        newTaskReward = ""
        newTaskCategory = .chores
        newTaskPresetIcon = nil
    }

    private func seedDemoData() {
        DemoDataSeeder.seedMissions(for: child, context: modelContext)
    }

    /// 承認・却下は保護者自身の操作なので、その場で保護者に通知を出す必要はない
    /// (結果は子供が次にアプリを開いたときにミッションの状態として表示される)
    private func approve(_ mission: Mission, message: String) {
        mission.status = .approved
        if mission.completedAt == nil {
            mission.completedAt = .now
        }
        mission.parentFeedback = message.isEmpty ? nil : message
    }

    private func reject(_ mission: Mission, feedback: String) {
        mission.status = .rejected
        mission.photoData = nil
        mission.comment = nil
        mission.parentFeedback = feedback.isEmpty ? nil : feedback
        mission.timerAccumulatedSeconds = 0
        mission.timerStartedAt = nil
    }
}

struct SectionHeader: View {
    let icon: String
    let title: LocalizedStringKey
    var color: Color = ParentTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.system(.headline, design: .rounded))
        }
    }
}

private struct ApprovalCard: View {
    @Environment(SessionStore.self) private var session
    let mission: Mission
    let onApprove: (String) -> Void
    let onReject: (String) -> Void

    @State private var messageToChild = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LocalizedStringKey(mission.title))
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text(moneyString(mission.payoutAmount, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ParentTheme.ctaGradient)
                    .clipShape(Capsule())
            }

            if let data = mission.photoData, let image = PlatformImage(data: data) {
                image.resizableImage
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.93))
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            if let comment = mission.comment, !comment.isEmpty {
                Label(comment, systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("お子様へのメッセージ(任意。却下の理由もここに)", text: $messageToChild)
                .font(.caption)
                .padding(10)
                .background(Color(white: 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack {
                Button("却下", role: .destructive) { onReject(messageToChild) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("承認") { onApprove(messageToChild) }
                    .buttonStyle(.borderedProminent)
                    .tint(ParentTheme.accent)
            }
        }
        .cardStyle()
    }
}

private struct MissionDetailSheet: View {
    let mission: Mission
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: mission.status == .approved ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill")
                            .foregroundStyle(mission.status == .approved ? .green : ParentTheme.accent)
                        Text(mission.status == .approved ? "承認済み" : "却下")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(mission.status == .approved ? moneyString(mission.payoutAmount, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue) : "\(moneyString(mission.reward, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))\(mission.rewardUnit.suffix)")
                            .font(.subheadline.bold())
                            .foregroundStyle(ParentTheme.accentSoft)
                    }

                    Text(LocalizedStringKey(mission.title))
                        .font(.system(.title3, design: .rounded).bold())

                    if let data = mission.photoData, let image = PlatformImage(data: data) {
                        image.resizableImage
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .clipped()
                    }

                    if let comment = mission.comment, !comment.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("お子様のコメント", systemImage: "text.bubble.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(comment)
                                .font(.subheadline)
                        }
                    }

                    if let feedback = mission.parentFeedback, !feedback.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("却下の理由", systemImage: "exclamationmark.bubble.fill")
                                .font(.caption.bold())
                                .foregroundStyle(ParentTheme.accent)
                            Text(feedback)
                                .font(.subheadline)
                        }
                    }

                    Label(
                        (mission.completedAt ?? mission.createdAt).formatted(date: .long, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(ParentTheme.backgroundGradient.ignoresSafeArea())
            .preferredColorScheme(.light)
            .navigationTitle("タスク詳細")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            #endif
        }
    }
}

struct TaskPreset: Identifiable {
    let title: String
    let icon: String
    let reward: Double
    let category: TaskCategory
    var id: String { title }

    static let samples: [TaskPreset] = [
        TaskPreset(title: "お皿洗い(10分)", icon: "fork.knife", reward: 0.5, category: .chores),
        TaskPreset(title: "お風呂掃除", icon: "shower.fill", reward: 1, category: .chores),
        TaskPreset(title: "肩たたき(10分)", icon: "hand.raised.fill", reward: 1, category: .chores),
        TaskPreset(title: "ベッドメイキング", icon: "bed.double.fill", reward: 1, category: .chores),
        TaskPreset(title: "洗濯物たたみ(10分)", icon: "tshirt.fill", reward: 1, category: .chores),
        TaskPreset(title: "ゴミ出し", icon: "trash.fill", reward: 0.5, category: .chores),
        TaskPreset(title: "玄関の靴そろえ", icon: "shoe.2.fill", reward: 0.5, category: .chores),
        TaskPreset(title: "掃除機がけ", icon: "wind", reward: 1.5, category: .chores),
        TaskPreset(title: "宿題を当日1時間以内に終わらせる", icon: "pencil.and.list.clipboard", reward: 2, category: .study),
        TaskPreset(title: "テストで80点以上", icon: "star.leadinghalf.filled", reward: 1, category: .study),
        TaskPreset(title: "テストで100点", icon: "star.fill", reward: 3, category: .study),
        TaskPreset(title: "なわとび", icon: "figure.jumprope", reward: 1, category: .exercise),
        TaskPreset(title: "公園でランニング", icon: "figure.run", reward: 1, category: .exercise),
    ]
}

#Preview {
    NavigationStack {
        TaskManagementView(child: ChildProfile(accountID: UUID(), name: "子ども1"))
    }
    .environment(SessionStore())
    .modelContainer(for: [Mission.self], inMemory: true)
}

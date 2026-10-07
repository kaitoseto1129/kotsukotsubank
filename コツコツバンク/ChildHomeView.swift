//
//  ChildHomeView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

enum Palette {
    /// ページ全体の背景(ライトブルー)
    static let background = Color(red: 0.86, green: 0.93, blue: 1.0)
    static let backgroundBottom = Color(red: 0.75, green: 0.87, blue: 0.99)
    /// カードは白寄りにして、ライトブルーの背景の上で浮き上がって見えるようにする
    static let card = Color.white
    static let cardTop = Color(red: 0.97, green: 0.99, blue: 1.0)
    /// 達成の円などメインで使う濃いブルー
    static let accent = Color(red: 0.08, green: 0.24, blue: 0.55)
    /// グラデーションの相方や、控えめな強調に使う中間の青
    static let accentSoft = Color(red: 0.12, green: 0.31, blue: 0.85)
    /// 背景の上に置く本文用のテキスト色(白背景ではないので黒に近い色にする)
    static let textPrimary = Color(red: 0.09, green: 0.13, blue: 0.22)
    static let textSecondary = Color(red: 0.35, green: 0.42, blue: 0.55)
    /// 却下・期限超過など、注意を引きたい表示専用の色
    static let warning = Color(red: 0.85, green: 0.30, blue: 0.25)

    static let backgroundGlow = LinearGradient(
        colors: [background, backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [card, card],
        startPoint: .top,
        endPoint: .bottom
    )

    static let ctaGradient = LinearGradient(
        colors: [accentSoft, accentSoft],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// 子どもが選べる、子どもモードの背景色の候補(上/下のグラデーション用に2色ずつ)
let childBackgroundColorOptions: [(name: String, top: String, bottom: String)] = [
    ("ライトブルー", "DCE9FF", "C5DFFF"),
    ("ピンク", "FFE2ED", "FFC7DD"),
    ("グリーン", "E1F5E6", "C3EBCE"),
    ("イエロー", "FFF6D9", "FFEBAD"),
    ("パープル", "EEE6FF", "DAC8FF"),
    ("オレンジ", "FFEADB", "FFD3B0"),
]

struct ChildHomeView: View {
    @Environment(SessionStore.self) private var session
    @Bindable var child: ChildProfile

    @State private var missionPath = NavigationPath()
    @State private var gaugeAppeared = false
    @State private var showLevel5Celebration = false
    /// 目標達成のお祝い(プレゼントの箱が開く画面)
    @State private var showGoalAchieved = false
    @State private var goalAchievedShown = false
    @State private var showBackgroundPicker = false

    @Query(sort: \Goal.createdAt, order: .reverse) private var allGoals: [Goal]
    @Query(sort: \Mission.createdAt) private var allMissions: [Mission]

    private var currentGoal: Goal? {
        // まだ受け取っていない目標を優先。無ければ(過去の受け取り済みも含めて)直近のもの。
        allGoals.first { $0.childID == child.id && $0.redeemedAt == nil }
            ?? allGoals.first { $0.childID == child.id }
    }

    private var missions: [Mission] {
        allMissions.filter { $0.childID == child.id }
    }

    private var earnedAmount: Double {
        Goal.savedAmount(childID: child.id, goals: allGoals, missions: allMissions)
    }

    private var currencyCode: String {
        session.account?.currencyCode ?? AppCurrency.jpy.rawValue
    }

    private var progress: Double {
        guard let goal = currentGoal, goal.price > 0 else { return 0 }
        return min(earnedAmount / goal.price, 1)
    }

    private var isGoalAchieved: Bool {
        guard let goal = currentGoal, goal.price > 0 else { return false }
        return earnedAmount >= goal.price
    }

    /// 前のご褒美を受け取り済みで、保護者がまだ次のご褒美を設定していない状態かどうか
    private var isWaitingForNextGoal: Bool {
        currentGoal?.redeemedAt != nil
    }

    private var todaysMissions: [Mission] {
        missions.filter { $0.status != .approved }
    }

    private var completedMissions: [Mission] {
        missions.filter { $0.status == .approved }
    }

    private var streak: Int {
        StreakCalculator.streak(from: missions)
    }

    private var level: GameLevel {
        GameLevel.level(forStreak: streak)
    }

    /// 子どもが選んだ背景色から、明暗2色のグラデーションを作る
    private var childBackgroundGradient: LinearGradient {
        let topHex = child.backgroundColorHex
        let bottomHex = childBackgroundColorOptions.first { $0.top == topHex }?.bottom ?? topHex
        return LinearGradient(colors: [Color(hex: topHex), Color(hex: bottomHex)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        NavigationStack(path: $missionPath) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {
                    heroSection

                    missionRow(
                        title: "今日のミッション",
                        icon: "sparkles",
                        missions: todaysMissions,
                        emptyText: "今日のミッションはまだありません",
                        emptyIcon: child.emptyStateIconName
                    )

                    if !completedMissions.isEmpty {
                        missionRow(
                            title: "達成したミッション",
                            icon: "checkmark.seal.fill",
                            missions: completedMissions,
                            emptyText: nil
                        )
                    }
                }
                .padding(.bottom, 40)
            }
            .background(childBackgroundGradient.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ModeSwitchControl(
                        isGuardian: false,
                        onSwitchToGuardian: {
                            session.mode = nil
                            session.isEnteringGuardianMode = true
                        },
                        onSwitchToChild: {}
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBackgroundPicker = true
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel("背景色を選ぶ")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MissionHistoryView(child: child)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel("タスク履歴")
                    }
                }
            }
            .navigationDestination(for: Mission.self) { mission in
                MissionTimerView(mission: mission, childName: child.name, onFinished: { missionPath = NavigationPath() })
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            playCelebrationSoundIfNeeded()
            checkLevel5Achievement()
            showGoalAchievedIfNeeded()
        }
        .fullScreenCover(isPresented: $showLevel5Celebration) {
            Level5CelebrationView(child: child, streakDays: child.lastLevel5StreakTrigger, onFinished: { showLevel5Celebration = false })
        }
        .fullScreenCover(isPresented: $showGoalAchieved) {
            if let goal = currentGoal {
                GoalAchievedView(goal: goal)
            }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundColorPickerView(child: child)
        }
    }

    /// 保護者が承認した後、子どもが画面を開いたタイミングで「チャリーン」と鳴らす。1回鳴らしたら鳴らさない。
    private func playCelebrationSoundIfNeeded() {
        let newlyApproved = missions.filter { $0.status == .approved && !$0.celebrationPlayed }
        guard !newlyApproved.isEmpty else { return }
        SoundEffects.playCoinSound()
        for mission in newlyApproved {
            mission.celebrationPlayed = true
        }
    }

    /// 目標金額に届いていて、まだご褒美を受け取っていないとき、豚が満たされる様子を見せてから、
    /// プレゼントの箱が開くお祝い画面を自動で出す。(「目標達成をチェックする」ボタンからも、いつでも見られる)
    private func showGoalAchievedIfNeeded() {
        guard isGoalAchieved, !isWaitingForNextGoal, !goalAchievedShown, !showLevel5Celebration else { return }
        goalAchievedShown = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            showGoalAchieved = true
        }
    }

    /// LV.5・10・15・20…(5の倍数)に到達するたびに、お祝い画面と保護者の役割交代ゲームを発生させる。
    /// 同じ節目の期間中(例: LV.5の21〜27日目)に何度も発生しないよう、記録済みの到達日数で判定する。
    private func checkLevel5Achievement() {
        guard level.triggersSurprise, !child.parentTurnPending else { return }
        let milestoneStreak = GameLevel.requiredStreak(forLevel: level.value)
        guard child.lastLevel5StreakTrigger < milestoneStreak else { return }
        child.parentTurnPending = true
        child.lastLevel5StreakTrigger = streak
        showLevel5Celebration = true
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Label(level.title, systemImage: "star.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.ctaGradient)
                    .clipShape(Capsule())

                if streak > 0 {
                    Label("\(streak)日連続", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Palette.accent.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            Text("21日連続でお手伝いすると、レベルアップ&サプライズ!")
                .font(.caption2.bold())
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                // 豚の線画に、貯まった分だけ下からピンク色が満ちていく
                PiggyBankGaugeView(progress: gaugeAppeared ? progress : 0)
                    .frame(width: 300, height: 150)

                Text("\(Int(progress * 100))%")
                    .font(.system(.headline).bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Palette.ctaGradient)
                    .clipShape(Capsule())
                    .shadow(color: Palette.accent.opacity(0.5), radius: 8, x: 0, y: 3)
            }
            .padding(.top, 12)
            .onAppear {
                gaugeAppeared = true
            }

            VStack(spacing: 8) {
                Label("ごほうび", systemImage: "gift.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.accentSoft)

                Group {
                    if isWaitingForNextGoal {
                        Text("🎉 前のご褒美をゲットしたね!")
                    } else if let goalTitle = currentGoal?.title {
                        Text(goalTitle)
                    } else {
                        Text("目標がまだ設定されていません")
                    }
                }
                    .font(.system(.title2).bold())
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 24)

                if isWaitingForNextGoal {
                    Text("次のプレゼントをおうちの人といっしょにきめてね。")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else if let goal = currentGoal {
                    if !isGoalAchieved {
                        Label(
                            "残り\(moneyString(max(goal.price - earnedAmount, 0), currencyCode: currencyCode))!",
                            systemImage: "flame.fill"
                        )
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }

                    if isGoalAchieved {
                        NavigationLink {
                            GoalAchievedView(goal: goal)
                        } label: {
                            Text("🎉 目標達成をチェックする")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(Palette.ctaGradient)
                                .clipShape(Capsule())
                                .shadow(color: Palette.accent.opacity(0.5), radius: 10, x: 0, y: 4)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mission row

    private func missionRow(title: LocalizedStringKey, icon: String, missions: [Mission], emptyText: LocalizedStringKey?, emptyIcon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(.headline))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 20)

            if missions.isEmpty, let emptyText {
                VStack(spacing: 10) {
                    if let emptyIcon {
                        Image(systemName: emptyIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(Palette.accent.opacity(0.5))
                    }
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(missions) { mission in
                            if mission.status == .pending || mission.status == .rejected {
                                NavigationLink(value: mission) {
                                    MissionCard(mission: mission)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                MissionCard(mission: mission) { newMission in
                                    missionPath.append(newMission)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 豚の線画ゲージ

/// 豚の線画に、貯めた金額÷目標金額の割合だけ、下から上へピンク色がゆっくり満ちていくビュー。
/// - `PigMask`: 豚の輪郭の内側だけを示す形(色はこの形の中にしか出ない)
/// - `PigLine`: 輪郭線・耳・目・鼻・しっぽの線画(どの割合でも、常に一番上に見える)
private struct PiggyBankGaugeView: View {
    /// 0.0〜1.0の達成度
    var progress: Double

    private let fillPink = Color(red: 1.0, green: 0.42, blue: 0.62)
    private let waterlinePink = Color(red: 1.0, green: 0.62, blue: 0.76)

    var body: some View {
        ZStack {
            // からっぽの部分(白地)
            Color.white
                .mask(Image("PigMask").resizable())

            // 貯めた金額の割合だけ、下からピンク色で満ちていく
            GeometryReader { proxy in
                let filledHeight = max(0, proxy.size.height * progress)
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(fillPink)
                        .frame(height: filledHeight)
                    // 水面のライン
                    Rectangle()
                        .fill(waterlinePink)
                        .frame(height: 3)
                        .offset(y: -filledHeight + 3)
                        .opacity(progress > 0.02 ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .mask(Image("PigMask").resizable())

            // 輪郭線・陰影線(どの割合でも、常に上に見える)
            Image("PigLine")
                .resizable()
        }
        .aspectRatio(2, contentMode: .fit)
        // 金額が増えたときに、色がゆっくり上がるように
        .animation(.easeInOut(duration: 1.4), value: progress)
    }
}

// MARK: - Mission card

private struct MissionCard: View {
    let mission: Mission
    var onRepeat: ((Mission) -> Void)? = nil
    @Environment(SessionStore.self) private var session
    @Environment(\.modelContext) private var modelContext

    private var statusIcon: String {
        switch mission.status {
        case .pending: "play.circle.fill"
        case .inProgress: "clock.fill"
        case .submitted: "hourglass"
        case .approved: "checkmark.seal.fill"
        case .rejected: "arrow.counterclockwise.circle.fill"
        }
    }

    private var statusColor: Color {
        switch mission.status {
        case .pending: Palette.accent
        case .inProgress: Palette.accentSoft
        case .submitted: .yellow
        case .approved: .green
        case .rejected: Palette.warning
        }
    }

    private var amountText: String {
        let currencyCode = session.account?.currencyCode ?? AppCurrency.jpy.rawValue
        return mission.status == .approved
            ? "+\(moneyString(mission.payoutAmount, currencyCode: currencyCode))"
            : "+\(moneyString(mission.reward, currencyCode: currencyCode))\(mission.rewardUnit.suffix)"
    }

    private var isOverdue: Bool {
        guard let dueDate = mission.dueDate, mission.status != .approved else { return false }
        return dueDate < .now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.cardGradient)
                    .frame(width: 150, height: 92)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(statusColor.opacity(0.35), lineWidth: 1.5)
                    )

                Image(systemName: mission.displayIconName)
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.accent.opacity(0.55))
                    .frame(width: 150, height: 92)

                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .padding(8)
            }
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

            Text(LocalizedStringKey(mission.title))
                .font(.system(.subheadline).bold())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)

            Text(amountText)
                .font(.caption.bold())
                .foregroundStyle(Palette.accentSoft)

            if let dueDate = mission.dueDate, mission.status != .approved {
                Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(isOverdue ? Palette.warning : .gray)
            }

            if mission.status == .rejected || mission.status == .approved,
               let feedback = mission.parentFeedback, !feedback.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text(mission.status == .rejected ? "差し戻し: \(feedback)" : "おうちの人より: \(feedback)")
                        .font(.caption2)
                        .foregroundStyle(mission.status == .rejected ? Palette.accent : Palette.accentSoft)
                        .lineLimit(2)

                    Button {
                        VoiceReader.shared.speak(feedback)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundStyle(Palette.accentSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("メッセージを読み上げる")
                }
            }

            if mission.status == .approved {
                Button(action: repeatMission) {
                    Label("もう一度やる", systemImage: "arrow.clockwise")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Palette.ctaGradient)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 150)
    }

    /// 承認済みのタスクを、子どもがもう一度取り組めるように新しいミッションとして複製する
    private func repeatMission() {
        let newMission = Mission(
            title: mission.title,
            reward: mission.reward,
            rewardUnit: mission.rewardUnit,
            category: mission.category,
            dueDate: nil,
            presetIconName: mission.presetIconName,
            childID: mission.childID
        )
        modelContext.insert(newMission)
        onRepeat?(newMission)
    }
}

// MARK: - Background color picker

private struct BackgroundColorPickerView: View {
    @Bindable var child: ChildProfile
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(childBackgroundColorOptions, id: \.top) { option in
                        Button {
                            child.backgroundColorHex = option.top
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: option.top), Color(hex: option.bottom)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        Circle().stroke(Palette.accent, lineWidth: child.backgroundColorHex == option.top ? 3 : 0)
                                    )
                                    .overlay {
                                        if child.backgroundColorHex == option.top {
                                            Image(systemName: "checkmark")
                                                .font(.headline.bold())
                                                .foregroundStyle(Palette.accent)
                                        }
                                    }
                                Text(option.name)
                                    .font(.caption.bold())
                                    .foregroundStyle(Palette.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .background(Palette.background.ignoresSafeArea())
            .preferredColorScheme(.light)
            .navigationTitle("背景色を選ぼう")
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

#Preview {
    ChildHomeView(child: ChildProfile(accountID: UUID(), name: "子ども1"))
        .environment(SessionStore())
        .modelContainer(for: [Goal.self, Mission.self], inMemory: true)
}

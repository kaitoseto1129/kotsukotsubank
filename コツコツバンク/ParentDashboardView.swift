//
//  ParentDashboardView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import Charts

struct ParentDashboardView: View {
    @Environment(SessionStore.self) private var session
    @Query(sort: \ChildProfile.createdAt) private var allChildren: [ChildProfile]
    @Query private var allMissions: [Mission]
    @Query private var allGoals: [Goal]

    @State private var selectedChild: ChildProfile?
    @State private var showSettings = false
    @State private var editingChild: ChildProfile?

    private var children: [ChildProfile] {
        allChildren.filter { $0.accountID == session.account?.id }
    }

    private var pendingApprovalCount: Int {
        guard let selectedChild else { return 0 }
        return allMissions.filter { $0.childID == selectedChild.id && $0.status == .submitted }.count
    }

    /// 受け取り済みでない、進行中の目標があるかどうか(なければ次のご褒美設定を案内する)
    private func hasActiveGoal(for child: ChildProfile) -> Bool {
        allGoals.contains { $0.childID == child.id && $0.redeemedAt == nil }
    }

    private func weeklyData(for child: ChildProfile) -> [WeekdayAmount] {
        let calendar = Calendar.current
        let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
        var totals = [Int: Double](uniqueKeysWithValues: (1...7).map { ($0, 0) })

        let approvedMissions = allMissions.filter { $0.childID == child.id && $0.status == .approved }
        for mission in approvedMissions {
            let date = mission.completedAt ?? mission.createdAt
            guard calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            totals[weekday, default: 0] += mission.payoutAmount
        }

        return (1...7).map { WeekdayAmount(label: weekdaySymbols[$0 - 1], amount: totals[$0] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let selectedChild {
                        VStack(spacing: 6) {
                            Button {
                                editingChild = selectedChild
                            } label: {
                                ZStack {
                                    if let data = selectedChild.avatarImageData, let image = PlatformImage(data: data) {
                                        Circle()
                                            .fill(Color(hex: selectedChild.colorHex).opacity(0.18))
                                            .frame(width: 76, height: 76)
                                        image.resizableImage
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 58, height: 58)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color(hex: selectedChild.colorHex).opacity(0.18))
                                            .frame(width: 76, height: 76)
                                        Circle()
                                            .fill(Color(hex: selectedChild.colorHex))
                                            .frame(width: 58, height: 58)
                                        Image(systemName: selectedChild.avatarSystemImage)
                                            .font(.title2)
                                            .foregroundStyle(.white)
                                    }
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, ParentTheme.accent)
                                        .offset(x: 26, y: 26)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(selectedChild.name)の画像を変更")

                            Text("保護者モード")
                                .font(.system(.title3, design: .rounded).bold())
                            Text("\(selectedChild.name)のサポート中")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)

                        if children.count > 1 {
                            Picker("お子様", selection: $selectedChild) {
                                ForEach(children) { child in
                                    Text(child.name).tag(Optional(child))
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 24)
                        }

                        if selectedChild.parentTurnPending {
                            VStack(spacing: 10) {
                                Text("👑🎉 \(GameLevel.level(forStreak: selectedChild.lastLevel5StreakTrigger).title)達成!")
                                    .font(.system(.headline, design: .rounded).bold())
                                Text("\(selectedChild.name)が\(selectedChild.lastLevel5StreakTrigger)日連続でお手伝いを頑張りました。今日はあなたの番です!")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)

                                if let task = selectedChild.parentTurnTaskTitle {
                                    Label(task, systemImage: "gift.fill")
                                        .font(.system(.headline, design: .rounded).bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(ParentTheme.ctaGradient)
                                        .clipShape(Capsule())
                                } else {
                                    Text("お子様がお願い内容を選んでいます…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    selectedChild.parentTurnPending = false
                                    selectedChild.parentTurnTaskTitle = nil
                                } label: {
                                    Text("お手伝いした!")
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(ParentTheme.ctaGradient)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .padding(16)
                            .background(ParentTheme.accentSoft.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 24)
                        }

                        if !hasActiveGoal(for: selectedChild) {
                            NavigationLink {
                                GoalRewardSettingView(child: selectedChild)
                            } label: {
                                VStack(spacing: 8) {
                                    Label("次のご褒美を設定しよう!", systemImage: "arrow.right.circle.fill")
                                        .font(.system(.headline, design: .rounded).bold())
                                        .foregroundStyle(.white)
                                    Text("今の目標を達成したので、次の目標・ご褒美を決めてあげましょう。ここをタップすると設定画面が開きます。")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(ParentTheme.ctaGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableButtonStyle())
                            .padding(.horizontal, 24)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Label("今週のがんばり", systemImage: "chart.xyaxis.line")
                                .font(.subheadline.bold())

                            Chart(weeklyData(for: selectedChild)) { item in
                                LineMark(x: .value("曜日", item.label), y: .value("金額", item.amount))
                                    .foregroundStyle(ParentTheme.ctaGradient)
                                    .interpolationMethod(.catmullRom)
                                PointMark(x: .value("曜日", item.label), y: .value("金額", item.amount))
                                    .foregroundStyle(ParentTheme.accent)
                            }
                            .frame(height: 140)
                        }
                        .cardStyle()
                        .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            NavigationLink {
                                GoalRewardSettingView(child: selectedChild)
                            } label: {
                                IconMenuRow(icon: "gift.fill", iconColor: ParentTheme.accentSoft, title: "目標・ご褒美設定")
                            }

                            NavigationLink {
                                TaskManagementView(child: selectedChild)
                            } label: {
                                IconMenuRow(icon: "checklist", iconColor: .blue, title: "タスク管理・承認", badgeCount: pendingApprovalCount)
                            }

                            NavigationLink {
                                ProgressManagementView(child: selectedChild)
                            } label: {
                                IconMenuRow(icon: "chart.line.uptrend.xyaxis", iconColor: .green, title: "進捗管理")
                            }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        ContentUnavailableView("お子様が登録されていません", systemImage: "person.crop.circle.badge.questionmark")
                            .padding(.top, 60)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(ParentTheme.backgroundGradient.ignoresSafeArea())
            .preferredColorScheme(.light)
            .navigationTitle("コツコツバンク")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ModeSwitchControl(
                        isGuardian: true,
                        onSwitchToGuardian: {},
                        onSwitchToChild: {
                            if let selectedChild {
                                session.mode = .child(selectedChild)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $editingChild) { child in
                AddChildView(accountID: child.accountID, existingChild: child)
            }
        }
        .onAppear {
            if selectedChild == nil || !children.contains(where: { $0.id == selectedChild?.id }) {
                selectedChild = children.first
            }
        }
    }
}

private struct WeekdayAmount: Identifiable {
    let label: String
    let amount: Double
    var id: String { label }
}

#Preview {
    ParentDashboardView()
        .environment(SessionStore())
        .modelContainer(for: [ChildProfile.self, Goal.self, Mission.self], inMemory: true)
}

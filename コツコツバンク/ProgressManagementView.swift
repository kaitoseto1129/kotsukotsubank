//
//  ProgressManagementView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import Charts

struct ProgressManagementView: View {
    let child: ChildProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session

    @Query private var allGoals: [Goal]
    @Query private var allMissions: [Mission]

    private var currencyCode: String {
        session.account?.currencyCode ?? AppCurrency.jpy.rawValue
    }

    private var goal: Goal? {
        allGoals.filter { $0.childID == child.id }.sorted { $0.createdAt > $1.createdAt }.first
    }

    private var redeemedGoals: [Goal] {
        allGoals
            .filter { $0.childID == child.id && $0.redeemedAt != nil }
            .sorted { ($0.redeemedAt ?? $0.createdAt) > ($1.redeemedAt ?? $1.createdAt) }
    }

    private var approvedMissions: [Mission] {
        allMissions
            .filter { $0.childID == child.id && $0.status == .approved }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    private var achievedAmount: Double {
        guard let redeemedAt = goal?.redeemedAt else {
            return approvedMissions.reduce(0) { $0 + $1.payoutAmount }
        }
        return approvedMissions
            .filter { ($0.completedAt ?? $0.createdAt) > redeemedAt }
            .reduce(0) { $0 + $1.payoutAmount }
    }

    private var weeklyData: [WeekdayAmount] {
        let calendar = Calendar.current
        let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
        var totals = [Int: Double](uniqueKeysWithValues: (1...7).map { ($0, 0) })

        for mission in approvedMissions {
            let date = mission.completedAt ?? mission.createdAt
            guard calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            totals[weekday, default: 0] += mission.payoutAmount
        }

        return (1...7).map { WeekdayAmount(label: weekdaySymbols[$0 - 1], amount: totals[$0] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SectionHeader(icon: "target", title: "タスク達成状況", color: ParentTheme.accent)

                if let goal {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(goal.title)
                                .font(.system(.headline, design: .rounded))
                            Spacer()
                        }

                        if let data = goal.imageData, let image = PlatformImage(data: data) {
                            image.resizableImage
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .clipped()
                        }

                        Text("達成額: \(moneyString(achievedAmount, currencyCode: currencyCode)) / \(moneyString(goal.price, currencyCode: currencyCode))")
                            .font(.caption.bold())

                        ProgressView(value: min(achievedAmount / max(goal.price, 1), 1))
                            .tint(ParentTheme.accent)
                            .scaleEffect(x: 1, y: 1.6, anchor: .center)

                        Label(
                            "目標設定日: \(goal.createdAt.formatted(date: .long, time: .omitted))",
                            systemImage: "calendar"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                } else {
                    HStack {
                        Image(systemName: "gift")
                            .foregroundStyle(.secondary)
                        Text("目標がまだ設定されていません")
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("今週のがんばり", systemImage: "chart.xyaxis.line")
                        .font(.subheadline.bold())

                    Chart(weeklyData) { item in
                        LineMark(x: .value("曜日", item.label), y: .value("金額", item.amount))
                            .foregroundStyle(ParentTheme.ctaGradient)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("曜日", item.label), y: .value("金額", item.amount))
                            .foregroundStyle(ParentTheme.accent)
                    }
                    .frame(height: 140)

                    Label("今週のハイライト", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .padding(.top, 8)

                    if approvedMissions.isEmpty {
                        Text("まだ実績がありません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(approvedMissions.prefix(5)) { mission in
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("\(child.name)が「\(mission.title)」を達成しました +\(moneyString(mission.payoutAmount, currencyCode: currencyCode))")
                                    .font(.caption)
                                Spacer()
                                Text((mission.completedAt ?? mission.createdAt).formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .cardStyle()

                if !redeemedGoals.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("達成したご褒美", systemImage: "trophy.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        ForEach(redeemedGoals) { pastGoal in
                            HStack {
                                Image(systemName: "gift.fill")
                                    .foregroundStyle(ParentTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pastGoal.title)
                                        .font(.caption.bold())
                                    Text(moneyString(pastGoal.price, currencyCode: currencyCode))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let redeemedAt = pastGoal.redeemedAt {
                                    Text(redeemedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .cardStyle()
                }

                if approvedMissions.isEmpty {
                    Button {
                        DemoDataSeeder.seedGoalIfNeeded(for: child, context: modelContext, existingGoals: allGoals)
                        DemoDataSeeder.seedMissions(for: child, context: modelContext)
                    } label: {
                        Label("サンプルデータを追加(動作確認用)", systemImage: "wand.and.stars")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .navigationTitle("進捗管理")
    }
}

private struct WeekdayAmount: Identifiable {
    let label: String
    let amount: Double
    var id: String { label }
}

#Preview {
    NavigationStack {
        ProgressManagementView(child: ChildProfile(accountID: UUID(), name: "子ども1"))
    }
    .environment(SessionStore())
    .modelContainer(for: [Goal.self, Mission.self], inMemory: true)
}

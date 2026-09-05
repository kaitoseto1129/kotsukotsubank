//
//  MissionHistoryView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

struct MissionHistoryView: View {
    let child: ChildProfile

    @Query private var allMissions: [Mission]

    private var missions: [Mission] {
        allMissions
            .filter { $0.childID == child.id }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if missions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray)
                        Text("まだ履歴がありません")
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(missions) { mission in
                        HistoryRow(mission: mission)
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("タスク履歴")
        .toolbarColorScheme(.light, for: .navigationBar)
        .preferredColorScheme(.light)
    }
}

private struct HistoryRow: View {
    let mission: Mission
    @Environment(SessionStore.self) private var session

    private var currencyCode: String {
        session.account?.currencyCode ?? AppCurrency.jpy.rawValue
    }

    private var statusLabel: String {
        switch mission.status {
        case .pending: "未着手"
        case .inProgress: "進行中"
        case .submitted: "承認待ち"
        case .approved: "達成"
        case .rejected: "差し戻し"
        }
    }

    private var statusColor: Color {
        switch mission.status {
        case .pending: .gray
        case .inProgress: Palette.accentSoft
        case .submitted: .yellow
        case .approved: .green
        case .rejected: Palette.warning
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            if let data = mission.photoData, let image = PlatformImage(data: data) {
                image.resizableImage
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.cardGradient)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: mission.presetIconName ?? "photo")
                            .foregroundStyle(mission.presetIconName != nil ? Palette.accent : Palette.accent.opacity(0.3))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(mission.title))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(Palette.textPrimary)
                Text((mission.completedAt ?? mission.createdAt).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(LocalizedStringKey(statusLabel))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.85))
                    .clipShape(Capsule())
                Text(mission.status == .approved ? "+\(moneyString(mission.payoutAmount, currencyCode: currencyCode))" : "+\(moneyString(mission.reward, currencyCode: currencyCode))\(mission.rewardUnit.suffix)")
                    .font(.caption2.bold())
                    .foregroundStyle(Palette.accentSoft)
            }
        }
        .padding(12)
        .background(Palette.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        MissionHistoryView(child: ChildProfile(accountID: UUID(), name: "子ども1"))
    }
    .environment(SessionStore())
    .modelContainer(for: [Mission.self], inMemory: true)
}

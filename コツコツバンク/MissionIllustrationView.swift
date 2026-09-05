//
//  MissionIllustrationView.swift
//  コツコツバンク
//

import SwiftUI

/// 「よくあるタスクから選ぶ」で追加したタスクの完了報告画面。
/// 写真を撮る代わりに、そのお手伝いをイメージしたイラスト(SF Symbol)と好きな色を選んで完了とする。
struct MissionIllustrationView: View {
    let mission: Mission
    let childName: String
    let onFinished: () -> Void

    private let colorOptions: [(name: String, color: Color)] = [
        ("ピンク", Color(red: 0.95, green: 0.45, blue: 0.65)),
        ("ブルー", Palette.accent),
        ("イエロー", Color(red: 0.95, green: 0.75, blue: 0.15)),
        ("グリーン", Color(red: 0.35, green: 0.75, blue: 0.45)),
        ("パープル", Color(red: 0.60, green: 0.40, blue: 0.85)),
    ]

    @State private var selectedColorIndex: Int?
    @State private var didSubmit = false

    private var iconName: String {
        mission.presetIconName ?? "checkmark.seal.fill"
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("よくできました!")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ZStack {
                Circle()
                    .fill((selectedColorIndex.map { colorOptions[$0].color } ?? Palette.accent).opacity(0.15))
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(Palette.cardGradient)
                    .frame(width: 180, height: 180)
                    .overlay(
                        Circle()
                            .stroke(selectedColorIndex.map { colorOptions[$0].color } ?? Palette.accent.opacity(0.2), lineWidth: 4)
                    )

                Image(systemName: iconName)
                    .font(.system(size: 76))
                    .foregroundStyle(selectedColorIndex.map { colorOptions[$0].color } ?? Palette.accent)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedColorIndex)
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

            Text(LocalizedStringKey(mission.title))
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(Palette.textSecondary)

            HStack(spacing: 14) {
                ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        selectedColorIndex = index
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: selectedColorIndex == index ? 3 : 0)
                            )
                            .overlay(
                                Circle().stroke(Palette.accent.opacity(0.15), lineWidth: 1)
                            )
                            .scaleEffect(selectedColorIndex == index ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.name)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedColorIndex)

            if didSubmit {
                Label("今日もえらいね!", systemImage: "hands.sparkles.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.green)
            } else {
                Button(action: submit) {
                    Text("おくる")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Palette.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }

    private func submit() {
        mission.status = .submitted
        mission.completedAt = .now
        didSubmit = true

        NotificationManager.shared.notify(
            title: "確認をお願いします",
            body: "\(childName)が「\(mission.title)」を完了しました。承認してあげましょう!"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onFinished()
        }
    }
}

#Preview {
    NavigationStack {
        MissionIllustrationView(
            mission: Mission(title: "お皿洗い(10分)", reward: 50, presetIconName: "fork.knife", childID: UUID()),
            childName: "子ども1",
            onFinished: {}
        )
    }
    .preferredColorScheme(.light)
}

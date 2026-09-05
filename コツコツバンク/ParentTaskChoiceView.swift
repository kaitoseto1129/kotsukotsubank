//
//  ParentTaskChoiceView.swift
//  コツコツバンク
//

import SwiftUI

/// LV.5達成のごほうびゲームで、子どもが「おうちの人へのお願い」を選ぶ画面。
/// 自由入力にすると困った内容を書かれてしまう可能性があるため、選択式にしている。
struct ParentTaskChoiceView: View {
    @Bindable var child: ChildProfile
    let onFinished: () -> Void

    private let options = [
        "宿題の手伝い(30分)",
        "部屋の片付け(30分)",
        "おやつの買い物に行く",
        "靴をきれいに磨く",
        "「早くしなさい」を今日は言わない",
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🎁")
                .font(.system(size: 48))

            Text("おうちの人へのお願いを\n1つ選ぼう!")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                ForEach(options, id: \.self) { option in
                    Button {
                        child.parentTurnTaskTitle = option
                        NotificationManager.shared.notify(
                            title: "🎁 サプライズが決まったよ!",
                            body: "「\(child.name)」が「\(option)」を選びました!"
                        )
                        onFinished()
                    } label: {
                        Text(option)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Palette.cardGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Palette.accentSoft.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }
}

#Preview {
    ParentTaskChoiceView(child: ChildProfile(accountID: UUID(), name: "子ども1"), onFinished: {})
        .preferredColorScheme(.dark)
}

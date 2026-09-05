//
//  GoalAchievedView.swift
//  コツコツバンク
//

import SwiftUI

struct GoalAchievedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Bindable var goal: Goal

    @State private var didAppear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("🎉🎊🎉")
                .font(.system(size: 32))
                .opacity(didAppear ? 1 : 0)
                .scaleEffect(didAppear ? 1 : 0.5)

            Text("おめでとう!")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)

            Text("\(goal.title)が届くよ!")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Palette.ctaGradient)
                .clipShape(Capsule())
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .fill(Palette.ctaGradient.opacity(0.3))
                    .frame(width: 260, height: 260)
                    .blur(radius: 20)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.cardGradient)
                    .frame(width: 220, height: 220)

                if let data = goal.imageData, let image = PlatformImage(data: data) {
                    image.resizableImage
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .clipped()
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Palette.accent.opacity(0.35))
                }
            }
            .scaleEffect(didAppear ? 1 : 0.85)
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)

            Capsule()
                .fill(Palette.ctaGradient)
                .frame(width: 220, height: 16)
                .shadow(color: Palette.accentSoft.opacity(0.6), radius: 8)

            Text("\(moneyString(goal.price, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue)) / \(moneyString(goal.price, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))")
                .font(.caption.bold())
                .foregroundStyle(Palette.textSecondary)

            Button {
                goal.redeemedAt = .now
                dismiss()
            } label: {
                Text("OK!")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 180)
                    .padding(.vertical, 15)
                    .background(Palette.ctaGradient)
                    .clipShape(Capsule())
                    .shadow(color: Palette.accent.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                didAppear = true
            }
        }
    }
}

#Preview {
    GoalAchievedView(goal: Goal(title: "スイッチ2 本体", price: 49980, childID: UUID()))
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}

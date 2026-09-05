//
//  Level5CelebrationView.swift
//  コツコツバンク
//

import SwiftUI

/// LV.10・15・20・25…に到達した時のお祝い画面。今日はおうちの人が代わりにお手伝いする番、というミニゲームを知らせる。
struct Level5CelebrationView: View {
    @Bindable var child: ChildProfile
    let streakDays: Int
    let onFinished: () -> Void

    @State private var didAppear = false

    private var level: GameLevel {
        GameLevel.level(forStreak: streakDays)
    }

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("👑🎉👑")
                .font(.system(size: 40))
                .opacity(didAppear ? 1 : 0)
                .scaleEffect(didAppear ? 1 : 0.5)

            Text("\(level.title) 達成!")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)

            Text("\(streakDays)日連続でお手伝いできたね!")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ZStack {
                Circle()
                    .fill(Palette.ctaGradient.opacity(0.3))
                    .frame(width: 240, height: 240)
                    .blur(radius: 20)
                Circle()
                    .fill(Palette.cardGradient)
                    .frame(width: 200, height: 200)
                Text("🏆")
                    .font(.system(size: 90))
            }
            .scaleEffect(didAppear ? 1 : 0.85)
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)

            VStack(spacing: 6) {
                Text("今日のごほうびゲーム")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.accentSoft)
                Text("今日は「\(child.name)」の代わりに、\nおうちの人がお手伝いする番だよ!")
                    .font(.subheadline.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Palette.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 32)

            NavigationLink {
                ParentTaskChoiceView(child: child, onFinished: onFinished)
            } label: {
                Text("やった!サプライズ")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 220)
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
            SoundEffects.playFanfareSound()
        }
    }
}

#Preview {
    Level5CelebrationView(child: ChildProfile(accountID: UUID(), name: "子ども1"), streakDays: 21, onFinished: {})
        .preferredColorScheme(.dark)
}

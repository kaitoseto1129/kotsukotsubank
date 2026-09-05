//
//  MissionTimerView.swift
//  コツコツバンク
//

import SwiftUI

struct MissionTimerView: View {
    @Environment(SessionStore.self) private var session
    @Bindable var mission: Mission
    let childName: String
    let onFinished: () -> Void

    @State private var nowTick: Date = .now
    @State private var timer: Timer?
    @State private var previousFeedback: String?
    @State private var pulse = false
    @State private var didLoadFeedback = false

    private var isRunning: Bool { mission.timerStartedAt != nil }

    private var elapsedSeconds: Int {
        var total = mission.timerAccumulatedSeconds
        if let startedAt = mission.timerStartedAt {
            total += nowTick.timeIntervalSince(startedAt)
        }
        return Int(total)
    }

    private var timeText: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Label(
                mission.rewardUnit == .perTask ? "ミッション" : (isRunning ? "ミッション中!" : "ミッション準備中"),
                systemImage: "flame.fill"
            )
            .font(.headline)
            .foregroundStyle(Palette.accentSoft)

            Text(LocalizedStringKey(mission.title))
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("+\(moneyString(mission.reward, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))\(mission.rewardUnit.suffix)")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Palette.ctaGradient)
                .clipShape(Capsule())

            if let previousFeedback {
                Label("保護者より: \(previousFeedback)", systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(12)
                    .background(Palette.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 32)
            }

            if mission.rewardUnit == .perHour {
                ZStack {
                    Circle()
                        .stroke(Palette.accent.opacity(0.12), lineWidth: 12)
                    Circle()
                        .stroke(Palette.ctaGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(isRunning ? (pulse ? 1 : 0.55) : 0.35)
                        .animation(isRunning ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: pulse)
                    Text(timeText)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.textPrimary)
                }
                .frame(width: 220, height: 220)
                .onAppear { pulse = true }

                if isRunning {
                    Button(action: pauseTimer) {
                        Label("止める", systemImage: "pause.fill")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Palette.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 32)
                } else {
                    Button(action: startTimer) {
                        Label(mission.timerAccumulatedSeconds > 0 ? "再開する" : "スタート", systemImage: "play.fill")
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
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.accentSoft)
                    .padding(.vertical, 8)

                Text("おわったら下の「できた!」を押してね")
                    .font(.subheadline.bold())
                    .foregroundStyle(Palette.textSecondary)
            }

            NavigationLink {
                if mission.presetIconName != nil {
                    MissionIllustrationView(mission: mission, childName: childName, onFinished: onFinished)
                } else {
                    MissionCameraView(mission: mission, childName: childName, onFinished: onFinished)
                }
            } label: {
                Text("できた!")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Palette.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Palette.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .simultaneousGesture(TapGesture().onEnded { pauseTimer() })
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 32)

            Label("今日のヒント: 最後に見直しをしよう!", systemImage: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            if !didLoadFeedback {
                didLoadFeedback = true
                if mission.status == .pending || mission.status == .rejected {
                    previousFeedback = mission.parentFeedback
                    mission.parentFeedback = nil
                }
            }
            startTicking()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            nowTick = .now
        }
    }

    private func startTimer() {
        guard mission.timerStartedAt == nil else { return }
        mission.status = .inProgress
        mission.timerStartedAt = .now
        nowTick = .now
    }

    private func pauseTimer() {
        guard let startedAt = mission.timerStartedAt else { return }
        mission.timerAccumulatedSeconds += Date.now.timeIntervalSince(startedAt)
        mission.timerStartedAt = nil
    }
}

#Preview {
    NavigationStack {
        MissionTimerView(mission: Mission(title: "お皿洗い", reward: 100, childID: UUID()), childName: "子ども1", onFinished: {})
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}

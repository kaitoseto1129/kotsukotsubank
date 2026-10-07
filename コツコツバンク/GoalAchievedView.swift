//
//  GoalAchievedView.swift
//  コツコツバンク
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GoalAchievedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Bindable var goal: Goal

    @State private var didAppear = false
    @State private var shakeAngle: Double = 0
    @State private var boxSquash: CGFloat = 1
    @State private var boxOpened = false
    @State private var lidGone = false
    @State private var flashOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: Double = 0
    @State private var confettiA: CGFloat = 0
    @State private var confettiB: CGFloat = 0
    @State private var rayAngle: Double = 0
    @State private var bob = false
    @State private var openTask: Task<Void, Never>?

    private let boxWidth: CGFloat = 180
    private let boxHeight: CGFloat = 118
    private let lidHeight: CGFloat = 42
    private let ribbonYellow = Color(red: 1.0, green: 0.78, blue: 0.20)

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                Spacer(minLength: 8)

                Text("🎉🎊🎉")
                    .font(.system(size: 32))
                    .opacity(didAppear ? 1 : 0)
                    .scaleEffect(didAppear ? 1 : 0.5)

                Text("おめでとう!")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .scaleEffect(boxOpened ? 1.08 : 1)

                Text("\(goal.title)が届くよ!")
                    .font(.system(.title3).bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Palette.ctaGradient)
                    .clipShape(Capsule())
                    .multilineTextAlignment(.center)

                // プレゼントの箱: ゆれて、ふたが飛んで、ご褒美がくるくる回りながら飛び出す
                ZStack(alignment: .bottom) {
                    SunRays(radius: 260)
                        .rotationEffect(.degrees(rayAngle))
                        .scaleEffect(boxOpened ? 1 : 0.1)
                        .opacity(boxOpened ? 1 : 0)
                        .offset(y: -19)

                    Twinkles(active: boxOpened)
                        .offset(y: -267)

                    ConfettiBurst(progress: confettiA, count: 56, spread: 1.0, gravity: 150, sizeScale: 1.0)
                        .offset(y: -boxHeight)
                    ConfettiBurst(progress: confettiB, count: 40, spread: 1.35, gravity: 190, sizeScale: 1.25, phase: 7)
                        .offset(y: -boxHeight)

                    Circle()
                        .stroke(ribbonYellow, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .offset(y: -68)

                    giftBox
                }
                .frame(width: 340, height: 400, alignment: .bottom)

                Text("\(moneyString(goal.price, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue)) / \(moneyString(goal.price, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.textSecondary)

                Button {
                    goal.redeemedAt = .now
                    AnalyticsService.log(.goalRedeemed)
                    dismiss()
                } label: {
                    Text("OK!")
                        .font(.system(.headline))
                        .foregroundStyle(.white)
                        .frame(width: 180)
                        .padding(.vertical, 15)
                        .background(Palette.ctaGradient)
                        .clipShape(Capsule())
                        .shadow(color: Palette.accent.opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 箱が開いた瞬間の、画面全体のフラッシュ
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .background(Palette.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                didAppear = true
            }
            openTask = Task { @MainActor in
                await playOpening()
            }
        }
        .onDisappear { openTask?.cancel() }
    }

    // MARK: - 開く演出

    @MainActor
    private func playOpening() async {
        try? await Task.sleep(nanoseconds: 700_000_000)

        // 1) 箱がだんだん激しくゆれる
        for i in 0..<10 {
            guard !Task.isCancelled else { return }
            let amplitude = 4 + Double(i) * 1.3
            withAnimation(.easeInOut(duration: 0.06)) {
                shakeAngle = i % 2 == 0 ? amplitude : -amplitude
            }
            #if canImport(UIKit)
            if i % 3 == 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            #endif
            try? await Task.sleep(nanoseconds: 75_000_000)
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.06)) { shakeAngle = 0 }

        // 2) 一瞬ぎゅっと縮んで、ためをつくる
        withAnimation(.easeIn(duration: 0.14)) { boxSquash = 0.84 }
        try? await Task.sleep(nanoseconds: 170_000_000)
        guard !Task.isCancelled else { return }

        // 3) ドーン!
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        SoundEffects.playCelebrationCheer()

        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            flashOpacity = 0.9
            ringScale = 0.2
            ringOpacity = 0.95
        }
        withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0 }
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 4.2
            ringOpacity = 0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) { boxSquash = 1 }
        withAnimation(.spring(response: 1.0, dampingFraction: 0.48)) { boxOpened = true }
        withAnimation(.easeOut(duration: 2.8)) { confettiA = 1 }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { rayAngle = 360 }

        // 4) 少し遅れて、2回目の紙吹雪
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 2.6)) { confettiB = 1 }
        withAnimation(.easeIn(duration: 0.5)) { lidGone = true }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        // 5) ご褒美がふわふわ浮く
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bob = true }
    }

    // MARK: - プレゼントの箱

    private var giftBox: some View {
        ZStack(alignment: .bottom) {
            // ご褒美の後ろの光
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.95), ribbonYellow.opacity(0)],
                                      center: .center, startRadius: 4, endRadius: 150))
                .frame(width: 300, height: 300)
                .scaleEffect(boxOpened ? 1 : 0.1)
                .opacity(boxOpened ? 1 : 0)
                .offset(y: -129)

            // 飛び出してくるご褒美(くるくる回りながら、箱の中から上へ)
            reward
                .frame(width: 210, height: 210)
                .scaleEffect(boxOpened ? 1 : 0.1, anchor: .bottom)
                .rotationEffect(.degrees(boxOpened ? 0 : -540), anchor: .center)
                .offset(y: (boxOpened ? -(boxHeight + 56) : -boxHeight * 0.3) + (bob ? -8 : 4))
                .opacity(boxOpened ? 1 : 0)

            // 箱の本体
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.accent)
                Rectangle()
                    .fill(ribbonYellow)
                    .frame(width: 32)
            }
            .frame(width: boxWidth - 16, height: boxHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // ふた(開くと、高く回りながら飛んでいく)
            lid
                .offset(x: boxOpened ? 120 : 0,
                        y: -(boxHeight - 8) - (boxOpened ? 340 : 0))
                .rotationEffect(.degrees(boxOpened ? 420 : 0))
                .opacity(lidGone ? 0 : 1)
        }
        .frame(width: boxWidth + 20, height: boxHeight + 20, alignment: .bottom)
        .scaleEffect(x: 1 + (1 - boxSquash) * 0.6, y: boxSquash, anchor: .bottom)
        .rotationEffect(.degrees(shakeAngle), anchor: .bottom)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
        .scaleEffect(didAppear ? 1 : 0.8)
    }

    private var lid: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.accentSoft)
            Rectangle()
                .fill(ribbonYellow)
                .frame(width: 32)
            // リボンの蝶結び
            HStack(spacing: -4) {
                Circle().stroke(ribbonYellow, lineWidth: 8).frame(width: 30, height: 30)
                Circle().stroke(ribbonYellow, lineWidth: 8).frame(width: 30, height: 30)
            }
            .offset(y: -lidHeight * 0.65)
        }
        .frame(width: boxWidth, height: lidHeight)
    }

    @ViewBuilder
    private var reward: some View {
        if let data = goal.imageData, let image = PlatformImage(data: data) {
            image.resizableImage
                .aspectRatio(contentMode: .fit)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(ribbonYellow, lineWidth: 5)
                )
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        } else {
            // 写真が設定されていない時は、星のかがやきの中にプレゼントを出す
            ZStack {
                Circle().fill(ribbonYellow.opacity(0.4))
                Image(systemName: "sparkles")
                    .font(.system(size: 130))
                    .foregroundStyle(ribbonYellow)
                Image(systemName: "gift.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Palette.accent)
                    .offset(x: 6)
            }
        }
    }
}

// MARK: - 光の放射

/// ご褒美の後ろで、ゆっくり回る光のすじ
private struct SunRays: View {
    var radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rayCount = 14
            for i in 0..<rayCount {
                let start = Double(i) / Double(rayCount) * 2 * .pi
                let half = Double.pi / Double(rayCount) * 0.55
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + CGFloat(cos(start - half)) * radius,
                                         y: center.y + CGFloat(sin(start - half)) * radius))
                path.addLine(to: CGPoint(x: center.x + CGFloat(cos(start + half)) * radius,
                                         y: center.y + CGFloat(sin(start + half)) * radius))
                path.closeSubpath()
                context.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.75),
                                          Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0)]),
                        center: center, startRadius: 0, endRadius: radius
                    )
                )
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
    }
}

// MARK: - きらきら

/// ご褒美のまわりで、ちかちか光る星
private struct Twinkles: View {
    var active: Bool
    @State private var pulse = false

    private struct Spark {
        let angle: Double
        let radius: CGFloat
        let size: CGFloat
    }

    private static func makeSparks() -> [Spark] {
        var list: [Spark] = []
        for i in 0..<10 {
            let angle: Double = Double(i) / 10.0 * 2.0 * Double.pi + 0.3
            let radius: CGFloat = CGFloat(125 + (i * 29) % 55)
            let size: CGFloat = CGFloat(16 + (i * 7) % 14)
            list.append(Spark(angle: angle, radius: radius, size: size))
        }
        return list
    }

    private let positions: [Spark] = Twinkles.makeSparks()

    var body: some View {
        ZStack {
            ForEach(positions.indices, id: \.self) { i in
                spark(positions[i], index: i)
            }
        }
        .opacity(active ? 1 : 0)
        .animation(.easeIn(duration: 0.4).delay(0.3), value: active)
        .onChange(of: active) { _, isActive in
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { pulse = true }
        }
        .allowsHitTesting(false)
    }

    private func spark(_ p: Spark, index i: Int) -> some View {
        let big: CGFloat = i % 2 == 0 ? 1.25 : 0.7
        let small: CGFloat = i % 2 == 0 ? 0.7 : 1.25
        let scale: CGFloat = pulse ? big : small
        let x: CGFloat = CGFloat(cos(p.angle)) * p.radius
        let y: CGFloat = CGFloat(sin(p.angle)) * p.radius
        return Image(systemName: "sparkle")
            .font(.system(size: p.size, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.20))
            .scaleEffect(scale)
            .offset(x: x, y: y)
    }
}

// MARK: - 紙吹雪

/// 箱が開いた瞬間に、上へ向かって弾ける紙吹雪(細長いリボン状のものも混ぜる)
private struct ConfettiBurst: View, Animatable {
    /// 0.0(これから)〜1.0(出きった後)
    var progress: CGFloat
    var count: Int
    var spread: CGFloat
    var gravity: CGFloat
    var sizeScale: CGFloat
    var phase: Int = 0

    /// アニメーションの途中の値でも描き直されるようにする(これがないと、始まりと終わりの絵しか出ない)
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private struct Piece {
        let angle: Double
        let distance: CGFloat
        let width: CGFloat
        let aspect: CGFloat
        let color: Color
        let spin: Double
    }

    private static let palette: [Color] = [
        Color(red: 1.0, green: 0.78, blue: 0.20),
        Color(red: 1.0, green: 0.42, blue: 0.62),
        Color(red: 0.20, green: 0.78, blue: 0.55),
        Color(red: 0.25, green: 0.50, blue: 0.95),
        Color(red: 1.0, green: 0.55, blue: 0.15),
        Color(red: 0.65, green: 0.40, blue: 0.90),
    ]

    private var pieces: [Piece] {
        (0..<count).map { i in
            let j = i + phase
            let fraction = Double(i) / Double(max(count - 1, 1))
            // 真上を中心に、左右へ大きく広がる(画面の上方向がマイナス)
            let angle = -Double.pi * (0.05 + 0.90 * fraction)
            let distance = CGFloat(170 + (j * 53) % 230) * spread
            let isStreamer = j % 4 == 0
            return Piece(
                angle: angle,
                distance: distance,
                width: CGFloat(8 + (j * 5) % 8) * sizeScale * (isStreamer ? 0.6 : 1),
                aspect: isStreamer ? 4.2 : 1.6,
                color: Self.palette[j % Self.palette.count],
                spin: Double((j * 53) % 90) / 90.0 + 0.6
            )
        }
    }

    var body: some View {
        let list = pieces
        let t = Double(progress)
        let fade: Double = t <= 0 ? 0 : max(0, 1 - t * t * t)
        return ZStack {
            ForEach(list.indices, id: \.self) { index in
                piece(list[index], progress: progress, fade: fade)
            }
        }
        .allowsHitTesting(false)
    }

    private func piece(_ piece: Piece, progress: CGFloat, fade: Double) -> some View {
        let dx: CGFloat = CGFloat(cos(piece.angle)) * piece.distance * progress
        let rise: CGFloat = CGFloat(sin(piece.angle)) * piece.distance * progress
        let dy: CGFloat = rise + gravity * progress * progress
        let spinDegrees: Double = piece.spin * Double(progress) * 720
        return RoundedRectangle(cornerRadius: 2)
            .fill(piece.color)
            .frame(width: piece.width, height: piece.width * piece.aspect)
            .rotationEffect(.degrees(spinDegrees))
            .offset(x: dx, y: dy)
            .opacity(fade)
    }
}

#Preview {
    GoalAchievedView(goal: Goal(title: "スイッチ2 本体", price: 49980, childID: UUID()))
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}

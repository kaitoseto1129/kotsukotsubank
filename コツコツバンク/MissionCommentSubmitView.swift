//
//  MissionCommentSubmitView.swift
//  コツコツバンク
//

import SwiftUI

struct MissionCommentSubmitView: View {
    @Environment(SessionStore.self) private var session
    @Bindable var mission: Mission
    let photoData: Data?
    let childName: String
    let onFinished: () -> Void

    @State private var comment = ""
    @State private var didSubmit = false

    private var previewAmount: Double { mission.payoutAmount }

    var body: some View {
        VStack(spacing: 20) {
            Text("ミッション: \(Text(LocalizedStringKey(mission.title)))")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("タスク代: +\(moneyString(previewAmount, currencyCode: session.account?.currencyCode ?? AppCurrency.jpy.rawValue))")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Palette.ctaGradient)
                .clipShape(Capsule())

            if let photoData, let image = PlatformImage(data: photoData) {
                image.resizableImage
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .clipped()
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("コメント", systemImage: "text.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                TextField("コメントを入力", text: $comment, axis: .vertical)
                    .padding(12)
                    .background(Palette.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.horizontal, 32)

            if didSubmit {
                Label("今日もえらいね!", systemImage: "hands.sparkles.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.green)
            } else {
                Button(action: submit) {
                    Text("送信する")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }

    private func submit() {
        mission.photoData = photoData
        mission.comment = comment
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
        MissionCommentSubmitView(mission: Mission(title: "お皿洗い", reward: 100, childID: UUID()), photoData: nil, childName: "子ども1", onFinished: {})
    }
    .environment(SessionStore())
    .preferredColorScheme(.dark)
}

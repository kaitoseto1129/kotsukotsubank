//
//  AboutAppView.swift
//  コツコツバンク
//

import SwiftUI

struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss

    private let slides: [(icon: String, title: String, body: String)] = [
        ("checklist", "ミッションをこなそう", "おうちのお手伝いなど、親が決めたミッションに挑戦しよう。"),
        ("camera.fill", "証拠を残そう", "タイマーで作業して、終わったら写真とコメントを送ろう。"),
        ("checkmark.seal.fill", "保護者が承認", "保護者が確認すると、ミッションの金額がチャージされるよ。"),
        ("gift.fill", "ご褒美をゲット", "貯まった金額が目標に届いたら、ご褒美がもらえる!")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("🏦")
                        .font(.system(size: 48))
                        .padding(.top, 20)

                    Text("コツコツバンクとは?")
                        .font(.title2.bold())

                    Text("子どもの日々の努力を記録し、親が承認し、ご褒美を受け取るまでの一連の流れをデジタル化するアプリです。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        ForEach(Array(slides.enumerated()), id: \.element.title) { index, slide in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(ParentTheme.ctaGradient.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: slide.icon)
                                        .font(.title3)
                                        .foregroundStyle(ParentTheme.accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(index + 1). \(slide.title)")
                                        .font(.system(.headline, design: .rounded))
                                    Text(slide.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("複数の端末で使う場合", systemImage: "iphone.and.arrow.forward")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(ParentTheme.accent)

                        Text("このアプリのデータは、それぞれの端末の中だけに保存されます。iPhoneとiPadの間で自動的に同期される仕組みはありません。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("例えば、お子さんにiPadを、保護者の方がiPhoneをお使いの場合は、それぞれの端末で個別に会員登録をしてください(同じメールアドレスでも登録できます)。お子さんがiPadでミッションを完了したら、保護者の方がそのiPadを受け取って「保護者」モードに切り替えて承認する、という流れになります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
            .background(ParentTheme.backgroundGradient.ignoresSafeArea())
            .preferredColorScheme(.light)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            #endif
        }
    }
}

#Preview {
    AboutAppView()
}

//
//  SignUpCompleteView.swift
//  コツコツバンク
//

import SwiftUI

struct SignUpCompleteView: View {
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didAppear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(ParentTheme.ctaGradient.opacity(0.18))
                            .frame(width: 132, height: 132)
                            .blur(radius: 6)
                        Circle()
                            .fill(ParentTheme.card)
                            .frame(width: 100, height: 100)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                    }
                    .scaleEffect(didAppear ? 1 : 0.6)
                    .opacity(didAppear ? 1 : 0)

                    Text("🎉 登録が完了しました!")
                        .font(.system(.title2, design: .rounded).bold())
                        .multilineTextAlignment(.center)
                    Text("さっそく使ってみましょう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ParentTheme.accent.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.fill")
                                .foregroundStyle(ParentTheme.accent)
                        }
                        Text("保護者モードについて")
                            .font(.system(.headline, design: .rounded))
                    }

                    Text("次の画面で「保護者」を選ぶと、保護者専用のパスワードをその場で設定できます。2回目からはそのパスワードで入ります。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                ParentPrimaryButton(title: "はじめる") {
                    dismiss()
                    onContinue()
                }
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                didAppear = true
            }
        }
    }
}

#Preview {
    SignUpCompleteView(onContinue: {})
}

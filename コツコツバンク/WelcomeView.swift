//
//  WelcomeView.swift
//  コツコツバンク
//

import SwiftUI

struct WelcomeView: View {
    @Environment(SessionStore.self) private var session
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ParentTheme.ctaGradient.opacity(0.18))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(ParentTheme.card)
                        .frame(width: 108, height: 108)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                    Text("🏦")
                        .font(.system(size: 56))
                }

                Text("コツコツバンク")
                    .font(.system(.largeTitle, design: .rounded).bold())

                Text("お手伝いをがんばって、\nコツコツ貯めよう!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("コツコツバンクとは?") { showAbout = true }
                    .font(.subheadline.bold())
                    .foregroundStyle(ParentTheme.accent)
                    .padding(.top, 4)

                Label("21日つづけるとサプライズが起きる!", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ParentTheme.ctaGradient)
                    .clipShape(Capsule())
                    .shadow(color: ParentTheme.accent.opacity(0.35), radius: 10, x: 0, y: 5)
                    .padding(.top, 10)
            }

            Spacer()

            VStack(spacing: 14) {
                ParentPrimaryButton(title: "ログイン") {
                    session.authRoute = .login
                }

                Button {
                    session.authRoute = .signUp
                } label: {
                    Text("新規会員登録")
                        .font(.headline)
                        .foregroundStyle(ParentTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(ParentTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ParentTheme.accent, lineWidth: 1.5)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showAbout) {
            AboutAppView()
        }
    }
}

#Preview {
    WelcomeView()
        .environment(SessionStore())
}

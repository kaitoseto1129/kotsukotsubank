//
//  PasswordGateView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

/// 保護者モードに入るためのパスワード入力画面。保護者パスワードが未設定の場合は
/// ContentView が代わりに GuardianPasswordSetupView を表示するため、ここに来る時点で
/// 既にパスワードが設定済みであることが保証されている。
struct PasswordGateView: View {
    @Environment(SessionStore.self) private var session

    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showResetSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(ParentTheme.ctaGradient.opacity(0.16))
                    .frame(width: 116, height: 116)
                Circle()
                    .fill(ParentTheme.card)
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(ParentTheme.accent)
            }

            Text("保護者の暗証番号を入力")
                .font(.system(.title3, design: .rounded).bold())

            if BiometricAuth.isAvailable {
                Button(action: authenticateWithFaceID) {
                    Label("Face IDではいる", systemImage: "faceid")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                        .background(ParentTheme.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: ParentTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                }

                HStack {
                    Rectangle().fill(Color(white: 0.85)).frame(height: 1)
                    Text("または").font(.caption).foregroundStyle(.secondary)
                    Rectangle().fill(Color(white: 0.85)).frame(height: 1)
                }
                .frame(maxWidth: 280)
            }

            ParentTextField(title: "4桁の暗証番号", text: $password, isSecure: true, isPIN: true, icon: "key.fill")
                .frame(maxWidth: 280)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(ParentTheme.accent)
            }

            ParentPrimaryButton(title: "はいる", isEnabled: password.count == 4, action: verify)
                .frame(maxWidth: 280)

            Button("パスワードを忘れた方") { showResetSheet = true }
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("戻る") {
                session.isEnteringGuardianMode = false
            }
            .font(.footnote.bold())
            .foregroundStyle(ParentTheme.accent)

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showResetSheet) {
            GuardianPasswordResetView()
        }
        .onAppear {
            if BiometricAuth.isAvailable {
                authenticateWithFaceID()
            }
        }
    }

    private func verify() {
        let hash = PasswordHashing.hash(password)
        guard hash == session.account?.guardianPasswordHash else {
            errorMessage = "暗証番号が違います"
            return
        }
        errorMessage = nil
        session.mode = .guardian
        session.isEnteringGuardianMode = false
    }

    private func authenticateWithFaceID() {
        BiometricAuth.authenticate { success in
            if success {
                errorMessage = nil
                session.mode = .guardian
                session.isEnteringGuardianMode = false
            }
        }
    }
}

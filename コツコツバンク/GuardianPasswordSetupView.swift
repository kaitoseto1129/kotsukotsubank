//
//  GuardianPasswordSetupView.swift
//  コツコツバンク
//

import SwiftUI

struct GuardianPasswordSetupView: View {
    @Environment(SessionStore.self) private var session

    @State private var password = ""
    @State private var passwordConfirmation = ""

    private var isValid: Bool {
        password.count == 4 && password == passwordConfirmation
    }

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
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(ParentTheme.accent)
            }

            VStack(spacing: 6) {
                Text("保護者パスワードを設定")
                    .font(.system(.title3, design: .rounded).bold())
                Text("はじめて保護者モードに入ります。\nこれから使う4桁の暗証番号を決めてください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ParentTextField(title: "4桁の暗証番号", text: $password, isSecure: true, isPIN: true, icon: "lock.fill")
                ParentTextField(title: "暗証番号(確認)", text: $passwordConfirmation, isSecure: true, isPIN: true, icon: "lock.rotation")
            }
            .cardStyle()
            .frame(maxWidth: 320)

            if passwordConfirmation.count == 4 && password != passwordConfirmation {
                Label("暗証番号が一致しません", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(ParentTheme.accent)
            }

            ParentPrimaryButton(title: "設定してはじめる", isEnabled: isValid, action: save)
                .frame(maxWidth: 320)

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
    }

    private func save() {
        session.account?.guardianPasswordHash = PasswordHashing.hash(password)
        session.mode = .guardian
        session.isEnteringGuardianMode = false
    }
}

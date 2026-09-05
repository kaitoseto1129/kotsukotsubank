//
//  GuardianPasswordResetView.swift
//  コツコツバンク
//

import SwiftUI

struct GuardianPasswordResetView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var loginPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var errorMessage: String?

    private var isValid: Bool {
        !loginPassword.isEmpty && newPassword.count == 4 && newPassword == newPasswordConfirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("ログインパスワードで本人確認をしたうえで、保護者パスワードを再設定します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    VStack(spacing: 12) {
                        ParentTextField(title: "ログインパスワード", text: $loginPassword, isSecure: true, icon: "envelope.badge.shield.half.filled")
                        ParentTextField(title: "新しい4桁の暗証番号", text: $newPassword, isSecure: true, isPIN: true, icon: "lock.fill")
                        ParentTextField(title: "暗証番号(確認)", text: $newPasswordConfirmation, isSecure: true, isPIN: true, icon: "lock.rotation")
                    }
                    .cardStyle()

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(ParentTheme.accent)
                    }

                    ParentPrimaryButton(title: "再設定する", isEnabled: isValid, action: reset)
                }
                .padding(24)
            }
            .background(ParentTheme.backgroundGradient.ignoresSafeArea())
            .preferredColorScheme(.light)
            .navigationTitle("保護者パスワード再設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            #endif
        }
    }

    private func reset() {
        guard PasswordHashing.hash(loginPassword) == session.account?.passwordHash else {
            errorMessage = "ログインパスワードが違います"
            return
        }
        session.account?.guardianPasswordHash = PasswordHashing.hash(newPassword)
        dismiss()
    }
}

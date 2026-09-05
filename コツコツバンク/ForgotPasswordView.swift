//
//  ForgotPasswordView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

/// パスワードを忘れた場合の再設定フロー。
/// このアプリはサーバーを持たないため、メールでの再設定リンク送信はできない。
/// 代わりに、会員登録時に設定した「秘密の質問」で本人確認してから再設定する。
struct ForgotPasswordView: View {
    @Environment(SessionStore.self) private var session
    @Query private var accounts: [FamilyAccount]

    private enum Step {
        case email
        case question(FamilyAccount)
        case newPassword(FamilyAccount)
        case done
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var answer = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button {
                        session.authRoute = .login
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(ParentTheme.card)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    Spacer()
                }

                VStack(spacing: 6) {
                    Text("🔑")
                        .font(.system(size: 48))
                    Text("パスワード再設定")
                        .font(.system(.title2, design: .rounded).bold())
                }
                .padding(.top, 4)

                content

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .email:
            VStack(spacing: 16) {
                Text("登録したメールアドレスを入力してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ParentTextField(title: "メールアドレス", text: $email, isEmail: true, icon: "envelope.fill")
                    .cardStyle()

                ParentPrimaryButton(title: "次へ", isEnabled: !email.isEmpty, action: findAccount)
            }

        case .question(let account):
            VStack(spacing: 16) {
                if let raw = account.securityQuestionRaw, let question = SecurityQuestion(rawValue: raw) {
                    Text(question.text)
                        .font(.system(.headline, design: .rounded))
                        .multilineTextAlignment(.center)

                    ParentTextField(title: "答え", text: $answer, icon: "pencil")
                        .cardStyle()

                    ParentPrimaryButton(title: "確認する", isEnabled: !answer.isEmpty, action: { checkAnswer(account: account) })
                } else {
                    Text("このアカウントには秘密の質問が設定されていません。お手数ですが、新しくアカウントを作り直してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ParentPrimaryButton(title: "新規会員登録へ") {
                        session.authRoute = .signUp
                    }
                }
            }

        case .newPassword:
            VStack(spacing: 16) {
                Text("新しいパスワードを設定してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ParentTextField(title: "新しいパスワード(4文字以上)", text: $newPassword, isSecure: true, icon: "lock.fill")
                    ParentTextField(title: "パスワード(確認)", text: $newPasswordConfirmation, isSecure: true, icon: "lock.rotation")
                }
                .cardStyle()

                if !newPasswordConfirmation.isEmpty && newPassword != newPasswordConfirmation {
                    Label("パスワードが一致しません", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                ParentPrimaryButton(
                    title: "再設定する",
                    isEnabled: newPassword.count >= 4 && newPassword == newPasswordConfirmation,
                    action: resetPassword
                )
            }

        case .done:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("パスワードを再設定しました。新しいパスワードでログインしてください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ParentPrimaryButton(title: "ログイン画面へ") {
                    session.authRoute = .login
                }
            }
        }
    }

    private func findAccount() {
        guard let account = accounts.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else {
            errorMessage = "アカウントが見つかりません"
            return
        }
        errorMessage = nil
        step = .question(account)
    }

    private func checkAnswer(account: FamilyAccount) {
        guard PasswordHashing.hashAnswer(answer) == account.securityAnswerHash else {
            errorMessage = "答えが正しくありません"
            return
        }
        errorMessage = nil
        step = .newPassword(account)
    }

    private func resetPassword() {
        guard case .newPassword(let account) = step else { return }
        account.passwordHash = PasswordHashing.hash(newPassword)
        errorMessage = nil
        step = .done
    }
}

#Preview {
    ForgotPasswordView()
        .environment(SessionStore())
        .modelContainer(for: [FamilyAccount.self], inMemory: true)
}

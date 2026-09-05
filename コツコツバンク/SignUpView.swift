//
//  SignUpView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import Supabase

struct SignUpView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query private var accounts: [FamilyAccount]

    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var securityQuestion: SecurityQuestion = .petName
    @State private var securityAnswer = ""
    @State private var errorMessage: String?
    @State private var completedAccount: FamilyAccount?
    @State private var isSigningUp = false

    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button {
                        session.authRoute = .welcome
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
                    Text("🎉")
                        .font(.system(size: 48))
                    Text("新規会員登録")
                        .font(.system(.title2, design: .rounded).bold())
                    Text("家族みんなでコツコツ貯めよう")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                VStack(spacing: 12) {
                    ParentTextField(title: "メールアドレス", text: $email, isEmail: true, icon: "envelope.fill")
                    ParentTextField(title: "パスワード(4文字以上)", text: $password, isSecure: true, icon: "lock.fill")
                    ParentTextField(title: "パスワード(確認)", text: $passwordConfirmation, isSecure: true, icon: "lock.rotation")
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Label("パスワードを忘れた時のための質問", systemImage: "questionmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("質問", selection: $securityQuestion) {
                        ForEach(SecurityQuestion.allCases) { question in
                            Text(question.text).tag(question)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(ParentTheme.accent)

                    ParentTextField(title: "答え", text: $securityAnswer, icon: "pencil")
                }
                .cardStyle()

                if !passwordConfirmation.isEmpty && password != passwordConfirmation {
                    Label("パスワードが一致しません", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                ParentPrimaryButton(
                    title: isSigningUp ? "登録中…" : "会員登録",
                    isEnabled: !isSigningUp && isEmailValid && password.count >= 4 && password == passwordConfirmation && !securityAnswer.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: signUp
                )

                Button("既にアカウントをお持ちの方はこちら") {
                    session.authRoute = .login
                }
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .fullScreenCover(item: Binding(
            get: { completedAccount },
            set: { newValue in
                if newValue == nil { completedAccount = nil }
            }
        )) { account in
            SignUpCompleteView {
                completedAccount = nil
                session.account = account
                BiometricAuth.rememberAccount(account.id)
            }
        }
    }

    private func signUp() {
        guard !accounts.contains(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else {
            errorMessage = "このメールアドレスは既に登録されています"
            return
        }

        errorMessage = nil
        isSigningUp = true

        Task {
            // Supabase側にもアカウントを作っておく(将来の複数端末同期・メールでのパスワード再設定のため)。
            // オフライン等で失敗しても、端末内では引き続き会員登録できるようにする(ローカルファースト)。
            var accountID = UUID()
            do {
                let response = try await supabase.auth.signUp(email: email, password: password)
                accountID = response.user.id
            } catch {
                // 失敗してもローカルの会員登録は続行する
            }

            await MainActor.run {
                finishSignUp(accountID: accountID)
            }
        }
    }

    @MainActor
    private func finishSignUp(accountID: UUID) {
        let account = FamilyAccount(
            id: accountID,
            email: email,
            passwordHash: PasswordHashing.hash(password),
            securityQuestionRaw: securityQuestion.rawValue,
            securityAnswerHash: PasswordHashing.hashAnswer(securityAnswer)
        )
        modelContext.insert(account)

        let child1 = ChildProfile(accountID: account.id, name: "子ども1", avatarSystemImage: "face.smiling.fill", colorHex: "3478F6")
        let child2 = ChildProfile(accountID: account.id, name: "子ども2", avatarSystemImage: "star.fill", colorHex: "FF6B00")
        modelContext.insert(child1)
        modelContext.insert(child2)

        isSigningUp = false
        completedAccount = account
    }
}

#Preview {
    SignUpView()
        .environment(SessionStore())
        .modelContainer(for: [FamilyAccount.self, ChildProfile.self], inMemory: true)
}

//
//  LoginView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @Query private var accounts: [FamilyAccount]

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var showAbout = false

    private var biometricAccount: FamilyAccount? {
        guard let lastAccountID = BiometricAuth.lastAccountID else { return nil }
        return accounts.first { $0.id == lastAccountID }
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
                    Text("🏦")
                        .font(.system(size: 48))
                    Text("おかえりなさい")
                        .font(.system(.title2, design: .rounded).bold())
                    Button("コツコツバンクとは?") { showAbout = true }
                        .font(.footnote.bold())
                        .foregroundStyle(ParentTheme.accent)
                }
                .padding(.top, 4)

                if let biometricAccount, BiometricAuth.isAvailable {
                    Button {
                        logInWithBiometrics(account: biometricAccount)
                    } label: {
                        Label("Face IDでログイン", systemImage: "faceid")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
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
                }

                VStack(spacing: 12) {
                    ParentTextField(title: "メールアドレス", text: $email, isEmail: true, icon: "envelope.fill")
                    ParentTextField(title: "パスワード", text: $password, isSecure: true, icon: "lock.fill")
                }
                .cardStyle()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                ParentPrimaryButton(
                    title: "ログイン",
                    isEnabled: !email.isEmpty && !password.isEmpty,
                    action: logIn
                )

                Button("パスワードをお忘れですか?") {
                    session.authRoute = .forgotPassword
                }
                .font(.footnote.bold())
                .foregroundStyle(ParentTheme.accent)

                Button("アカウントをお持ちでない方はこちら") {
                    session.authRoute = .signUp
                }
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showAbout) {
            AboutAppView()
        }
        .onAppear {
            if email.isEmpty, let biometricAccount {
                email = biometricAccount.email
            }
        }
    }

    private func logIn() {
        let hash = PasswordHashing.hash(password)
        guard let account = accounts.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) else {
            errorMessage = "アカウントが見つかりません"
            return
        }
        guard account.passwordHash == hash else {
            errorMessage = "パスワードが違います"
            return
        }
        errorMessage = nil
        session.account = account
        BiometricAuth.rememberAccount(account.id)
    }

    private func logInWithBiometrics(account: FamilyAccount) {
        BiometricAuth.authenticate { success in
            if success {
                errorMessage = nil
                session.account = account
            } else {
                errorMessage = "認証できませんでした"
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
        .modelContainer(for: [FamilyAccount.self], inMemory: true)
}

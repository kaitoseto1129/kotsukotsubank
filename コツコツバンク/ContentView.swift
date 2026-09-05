//
//  ContentView.swift
//  コツコツバンク
//
//  Created by Kaito Seto on 2026/08/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if !session.isAuthenticated {
                switch session.authRoute {
                case .welcome:
                    WelcomeView()
                case .login:
                    LoginView()
                case .signUp:
                    SignUpView()
                case .forgotPassword:
                    ForgotPasswordView()
                }
            } else if let mode = session.mode {
                switch mode {
                case .guardian:
                    ParentDashboardView()
                case .child(let child):
                    ChildHomeView(child: child)
                }
            } else if session.isEnteringGuardianMode {
                if session.account?.guardianPasswordHash == nil {
                    GuardianPasswordSetupView()
                } else {
                    PasswordGateView()
                }
            } else {
                ModeSelectionView()
            }
        }
        .onChange(of: session.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                NotificationManager.shared.requestAuthorizationIfNeeded()
            }
        }
        .environment(\.locale, (AppLanguage(rawValue: session.account?.languageCode ?? AppLanguage.ja.rawValue) ?? .ja).locale)
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
        .modelContainer(for: [FamilyAccount.self, ChildProfile.self, Goal.self, Mission.self], inMemory: true)
}

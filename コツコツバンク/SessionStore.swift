//
//  SessionStore.swift
//  コツコツバンク
//

import Foundation
import Observation
import SwiftData

enum AppMode: Equatable {
    case guardian
    case child(ChildProfile)

    static func == (lhs: AppMode, rhs: AppMode) -> Bool {
        switch (lhs, rhs) {
        case (.guardian, .guardian):
            return true
        case let (.child(a), .child(b)):
            return a.persistentModelID == b.persistentModelID
        default:
            return false
        }
    }
}

enum AuthRoute: Equatable {
    case welcome
    case login
    case signUp
    case forgotPassword
}

@Observable
final class SessionStore {
    var account: FamilyAccount?
    var authRoute: AuthRoute = .welcome
    /// 「保護者」を選んでからパスワード入力/設定が終わるまでの待機状態
    var isEnteringGuardianMode = false
    var mode: AppMode?

    var isAuthenticated: Bool { account != nil }

    func logOut() {
        account = nil
        mode = nil
        isEnteringGuardianMode = false
        authRoute = .welcome
    }
}

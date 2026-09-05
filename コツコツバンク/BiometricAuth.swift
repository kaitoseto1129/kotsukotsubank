//
//  BiometricAuth.swift
//  コツコツバンク
//

import Foundation
import LocalAuthentication

/// Face ID/Touch IDでのログインを扱う。前回ログインしたアカウントのIDを覚えておき、
/// 生体認証が成功したらメールアドレス入力なしでそのアカウントに入れるようにする。
enum BiometricAuth {
    private static let lastAccountIDKey = "lastLoggedInAccountID"

    static var lastAccountID: UUID? {
        guard let string = UserDefaults.standard.string(forKey: lastAccountIDKey) else { return nil }
        return UUID(uuidString: string)
    }

    static func rememberAccount(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: lastAccountIDKey)
    }

    static func forgetAccount() {
        UserDefaults.standard.removeObject(forKey: lastAccountIDKey)
    }

    /// この端末でFace ID/Touch IDが使えるかどうか
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "コツコツバンクにログインします"
        ) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}

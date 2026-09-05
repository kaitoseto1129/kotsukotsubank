//
//  FamilyAccount.swift
//  コツコツバンク
//

import Foundation
import SwiftData

@Model
final class FamilyAccount {
    var id: UUID
    var email: String
    var passwordHash: String
    /// 保護者モード専用のパスワード。初めて「保護者」を選んだときに設定される(未設定ならnil)。
    var guardianPasswordHash: String?
    /// ログインパスワードを忘れた時の本人確認用。SecurityQuestion.rawValueを保存する。
    var securityQuestionRaw: String?
    var securityAnswerHash: String?
    var avatarImageData: Data?
    var createdAt: Date
    /// 家族全体で使う通貨(円/ドル)。AppCurrency.rawValueを保存する。
    var currencyCode: String = AppCurrency.jpy.rawValue
    /// アプリの表示言語。AppLanguage.rawValueを保存する。iPhone本体の言語設定とは独立。
    var languageCode: String = AppLanguage.ja.rawValue

    init(
        id: UUID = UUID(),
        email: String,
        passwordHash: String,
        securityQuestionRaw: String? = nil,
        securityAnswerHash: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.guardianPasswordHash = nil
        self.securityQuestionRaw = securityQuestionRaw
        self.securityAnswerHash = securityAnswerHash
        self.createdAt = createdAt
        self.currencyCode = AppCurrency.jpy.rawValue
        self.languageCode = AppLanguage.ja.rawValue
    }
}

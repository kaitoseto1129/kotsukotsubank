//
//  SecurityQuestion.swift
//  コツコツバンク
//

import Foundation
import SwiftUI

/// パスワードを忘れた時の本人確認に使う秘密の質問。サーバーを持たないため、
/// メールでのリンク送信の代わりにこの方式で本人確認を行う。
enum SecurityQuestion: String, CaseIterable, Codable, Identifiable {
    case petName
    case birthCity
    case favoriteFood
    case childNickname

    var id: String { rawValue }

    var text: LocalizedStringKey {
        switch self {
        case .petName: return "初めて飼ったペットの名前は?"
        case .birthCity: return "生まれた街の名前は?"
        case .favoriteFood: return "好きな食べ物は?"
        case .childNickname: return "子どもの頃のあだ名は?"
        }
    }
}

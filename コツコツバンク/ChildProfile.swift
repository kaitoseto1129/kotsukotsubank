//
//  ChildProfile.swift
//  コツコツバンク
//

import Foundation
import SwiftData

@Model
final class ChildProfile {
    var id: UUID
    var accountID: UUID
    var name: String
    var avatarSystemImage: String
    var colorHex: String
    var avatarImageData: Data?
    var createdAt: Date
    /// LV.10・15・20・25…に到達し、保護者と役割交代するミニゲームの順番待ちかどうか
    var parentTurnPending: Bool = false
    /// 直近でサプライズを出した時の連続日数。同じ連続記録の間に何度もお祝いを出さないようにする
    var lastLevel5StreakTrigger: Int = 0
    /// サプライズのごほうびゲームで、子どもが選んだ「おうちの人へのお願い」
    var parentTurnTaskTitle: String?
    /// 子どもモードの背景色(子ども自身が選ぶ)
    var backgroundColorHex: String = "DCE9FF"
    /// 今日のミッションが空の時に表示する、保護者が選んだイラスト(SF Symbol名)
    var emptyStateIconName: String = "sparkles"

    init(
        id: UUID = UUID(),
        accountID: UUID,
        name: String,
        avatarSystemImage: String = "face.smiling.fill",
        colorHex: String = "FF6B00",
        createdAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.avatarSystemImage = avatarSystemImage
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.parentTurnPending = false
        self.lastLevel5StreakTrigger = 0
    }
}

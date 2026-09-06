//
//  Goal.swift
//  コツコツバンク
//

import Foundation
import SwiftData

@Model
final class Goal {
    /// 端末間同期用の固有ID
    var id: UUID = UUID()
    /// 端末間同期用。この目標が属するアカウント(FamilyAccount.id / Supabaseのユーザーid)
    var accountID: UUID = UUID()
    var title: String
    var price: Double
    var productURL: String?
    var imageData: Data?
    var createdAt: Date
    var childID: UUID
    var redeemedAt: Date?
    /// 端末間同期用。最後に内容が変わった時刻
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        accountID: UUID = UUID(),
        title: String,
        price: Double,
        productURL: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = .now,
        childID: UUID
    ) {
        self.id = id
        self.accountID = accountID
        self.title = title
        self.price = price
        self.productURL = productURL
        self.imageData = imageData
        self.createdAt = createdAt
        self.childID = childID
        self.redeemedAt = nil
    }
}

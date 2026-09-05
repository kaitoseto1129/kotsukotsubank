//
//  Goal.swift
//  コツコツバンク
//

import Foundation
import SwiftData

@Model
final class Goal {
    var title: String
    var price: Double
    var productURL: String?
    var imageData: Data?
    var createdAt: Date
    var childID: UUID
    var redeemedAt: Date?

    init(
        title: String,
        price: Double,
        productURL: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = .now,
        childID: UUID
    ) {
        self.title = title
        self.price = price
        self.productURL = productURL
        self.imageData = imageData
        self.createdAt = createdAt
        self.childID = childID
        self.redeemedAt = nil
    }
}

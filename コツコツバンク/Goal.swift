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

extension Goal {
    /// 子どもの、いま目標に向けて貯まっている金額。
    /// 直近にご褒美を受け取った時点より後に承認されたタスクの金額だけを数える
    /// (受け取りがまだ1度も無ければ、承認済みのすべて)。新しい目標を選んだら、そこから貯め直しになる。
    static func savedAmount(childID: UUID, goals: [Goal], missions: [Mission]) -> Double {
        var baseline: Date?
        for goal in goals where goal.childID == childID {
            if let redeemedAt = goal.redeemedAt, redeemedAt > (baseline ?? .distantPast) {
                baseline = redeemedAt
            }
        }
        var total: Double = 0
        for mission in missions where mission.childID == childID && mission.status == .approved {
            let date: Date = mission.completedAt ?? mission.createdAt
            if let baseline, date <= baseline { continue }
            total += mission.payoutAmount
        }
        return total
    }
}

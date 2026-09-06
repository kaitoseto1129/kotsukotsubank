//
//  DemoDataSeeder.swift
//  コツコツバンク
//

import Foundation
import SwiftData

/// 動作確認用のサンプルデータをまとめて追加するヘルパー。
enum DemoDataSeeder {
    @discardableResult
    static func seedMissions(for child: ChildProfile, context: ModelContext) -> [Mission] {
        let calendar = Calendar.current
        var missions: [Mission] = []

        missions.append(Mission(accountID: child.accountID, title: "お皿洗い", reward: 50, rewardUnit: .perTask, status: .pending, childID: child.id))

        let dueSoon = calendar.date(byAdding: .day, value: 3, to: .now)
        missions.append(Mission(accountID: child.accountID, title: "宿題をおわらせる", reward: 100, rewardUnit: .perTask, status: .pending, dueDate: dueSoon, childID: child.id))

        let submitted = Mission(accountID: child.accountID, title: "お部屋の片付け", reward: 300, rewardUnit: .perHour, status: .submitted, childID: child.id)
        submitted.completedAt = .now
        submitted.timerAccumulatedSeconds = 1800
        submitted.comment = "机の上と床をきれいにしたよ!"
        missions.append(submitted)

        for offset in [1, 2, 4, 6] {
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let approved = Mission(accountID: child.accountID, title: "お手伝い(サンプル)", reward: 80, rewardUnit: .perTask, status: .approved, createdAt: day, childID: child.id)
            approved.completedAt = day
            missions.append(approved)
        }

        for mission in missions {
            context.insert(mission)
        }
        return missions
    }

    static func seedGoalIfNeeded(for child: ChildProfile, context: ModelContext, existingGoals: [Goal]) {
        guard !existingGoals.contains(where: { $0.childID == child.id && $0.redeemedAt == nil }) else { return }
        let goal = Goal(accountID: child.accountID, title: "サンプル: ニンテンドースイッチ", price: 30000, childID: child.id)
        context.insert(goal)
    }

    /// LV.5のサプライズ演出を動作確認できるよう、今日から過去分、必要な日数だけ連続で承認済みのミッションを追加する
    @discardableResult
    static func seedLevel5Streak(for child: ChildProfile, context: ModelContext) -> [Mission] {
        let calendar = Calendar.current
        let daysNeeded = GameLevel.requiredStreak(forLevel: 5)
        var missions: [Mission] = []
        for offset in 0..<daysNeeded {
            let day = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
            let mission = Mission(accountID: child.accountID, title: "お手伝い(連続サンプル)", reward: 50, rewardUnit: .perTask, status: .approved, createdAt: day, childID: child.id)
            mission.completedAt = day
            missions.append(mission)
        }
        for mission in missions {
            context.insert(mission)
        }
        return missions
    }
}

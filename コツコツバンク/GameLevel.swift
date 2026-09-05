//
//  GameLevel.swift
//  コツコツバンク
//

import Foundation

/// お手伝いを連続で続けた日数に応じたレベル。LV.1〜5は初期の目安、LV.6以降は1週間ごとに1レベルずつ上がり続ける。
/// LV.5・10・15・20・25…(5の倍数)に到達するたびに、保護者と役割交代するサプライズが発生する。
struct GameLevel {
    let value: Int

    var title: String { "LV.\(value)" }

    /// サプライズ(役割交代ミニゲーム)が発生するレベルかどうか
    var triggersSurprise: Bool { value > 0 && value.isMultiple(of: 5) }

    /// LV.1〜5の連続日数の目安(3日・7日・14日・21日)。LV.6以降は21日を起点に1週間(7日)ごとに1レベル上がる。
    private static let earlyThresholds = [0, 3, 7, 14, 21]

    static func level(forStreak streak: Int) -> GameLevel {
        GameLevel(value: levelNumber(forStreak: streak))
    }

    private static func levelNumber(forStreak streak: Int) -> Int {
        if streak < earlyThresholds.last! {
            var lv = 1
            for (index, threshold) in earlyThresholds.enumerated() where streak >= threshold {
                lv = index + 1
            }
            return lv
        }
        let extraWeeks = (streak - earlyThresholds.last!) / 7
        return 5 + extraWeeks
    }

    /// このレベルに到達するのに必要な連続日数
    static func requiredStreak(forLevel level: Int) -> Int {
        if level <= 5 {
            return earlyThresholds[max(level - 1, 0)]
        }
        return earlyThresholds.last! + (level - 5) * 7
    }

    /// 次のレベルまでに必要な、残りの連続日数
    static func daysToNextLevel(forStreak streak: Int) -> Int? {
        let current = levelNumber(forStreak: streak)
        return max(requiredStreak(forLevel: current + 1) - streak, 0)
    }
}

enum StreakCalculator {
    /// 承認済みミッションの完了日から、今日(または昨日)まで連続でお手伝いした日数を数える
    static func streak(from missions: [Mission], now: Date = .now) -> Int {
        let calendar = Calendar.current
        let approvedDays = Set(
            missions
                .filter { $0.status == .approved }
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
        )
        guard !approvedDays.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: now)
        if !approvedDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            guard approvedDays.contains(cursor) else { return 0 }
        }

        var streak = 0
        while approvedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }
}

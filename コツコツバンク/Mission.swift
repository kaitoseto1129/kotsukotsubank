//
//  Mission.swift
//  コツコツバンク
//

import Foundation
import SwiftData

enum MissionStatus: String, Codable {
    case pending
    case inProgress
    case submitted
    case approved
    case rejected
}

/// タスクの金額の数え方。固定額(回数)か、作業時間(10分単位)に応じた分給か。
enum RewardUnit: String, Codable, CaseIterable {
    case perTask
    case perHour

    var label: String {
        switch self {
        case .perTask: "固定額"
        case .perHour: "分給"
        }
    }

    var suffix: String {
        switch self {
        case .perTask: ""
        case .perHour: "/10分"
        }
    }
}

/// タスクの分類。「タスクを追加」でこれを選んでおくと、一覧をカテゴリ別に振り分けられる。
enum TaskCategory: String, Codable, CaseIterable {
    case chores
    case study
    case exercise

    var label: String {
        switch self {
        case .chores: "お手伝い"
        case .study: "勉強"
        case .exercise: "運動"
        }
    }

    var icon: String {
        switch self {
        case .chores: "house.fill"
        case .study: "book.fill"
        case .exercise: "figure.run"
        }
    }
}

@Model
final class Mission {
    var title: String
    var reward: Double
    var rewardUnitRaw: String = RewardUnit.perTask.rawValue
    var categoryRaw: String = TaskCategory.chores.rawValue
    var statusRaw: String
    var createdAt: Date
    var dueDate: Date?
    var completedAt: Date?
    /// 時給タスクで、実際に作業した時間(秒)。スタート/ストップのたびに積み上げられる。
    var timerAccumulatedSeconds: Double = 0
    /// タイマーが現在実行中の場合の開始時刻。停止中はnil。
    var timerStartedAt: Date?
    var photoData: Data?
    var comment: String?
    var parentFeedback: String?
    /// 承認された時に、子ども側でお祝いの音を鳴らしたかどうか(2回目以降は鳴らさない)
    var celebrationPlayed: Bool = false
    /// 「よくあるタスクから選ぶ」で追加された場合のSF Symbol名。設定されている場合、完了報告は写真の代わりにこのイラストを使う。
    var presetIconName: String?
    var childID: UUID

    var status: MissionStatus {
        get { MissionStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var rewardUnit: RewardUnit {
        get { RewardUnit(rawValue: rewardUnitRaw) ?? .perTask }
        set { rewardUnitRaw = newValue.rawValue }
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .chores }
        set { categoryRaw = newValue.rawValue }
    }

    /// 子ども画面などに出すイラスト。保護者が選んだ絵があればそれを、なければタスク名から近い絵を選ぶ。
    var displayIconName: String {
        if let presetIconName { return presetIconName }
        let keywordIcons: [(keywords: [String], icon: String)] = [
            (["宿題", "勉強", "ドリル", "テスト", "算数", "国語", "計算", "漢字", "英語", "homework", "study"], "pencil.and.ruler.fill"),
            (["読書", "本を", "音読", "read"], "book.fill"),
            (["皿", "食器", "ごはん", "ご飯", "食事", "料理", "dish", "meal"], "fork.knife"),
            (["ゴミ", "ごみ", "trash", "garbage"], "trash.fill"),
            (["洗濯", "服", "たたみ", "laundry"], "tshirt.fill"),
            (["お風呂", "風呂", "bath"], "bathtub.fill"),
            (["掃除", "そうじ", "片づけ", "片付け", "clean"], "sparkles"),
            (["寝", "布団", "ベッド", "bed"], "bed.double.fill"),
            (["散歩", "犬", "ペット", "えさ", "walk", "pet"], "pawprint.fill"),
            (["水やり", "植物", "花", "plant"], "leaf.fill"),
            (["買い物", "買物", "shopping"], "cart.fill"),
        ]
        for entry in keywordIcons where entry.keywords.contains(where: { title.localizedCaseInsensitiveContains($0) }) {
            return entry.icon
        }
        return category.icon
    }

    /// 実際に支払われる金額。分給タスクは作業時間(10分単位) × 分給、固定額タスクはそのままの金額。
    var payoutAmount: Double {
        guard rewardUnit == .perHour else { return reward }
        return reward * (timerAccumulatedSeconds / 600)
    }

    init(
        title: String,
        reward: Double,
        rewardUnit: RewardUnit = .perTask,
        category: TaskCategory = .chores,
        status: MissionStatus = .pending,
        createdAt: Date = .now,
        dueDate: Date? = nil,
        presetIconName: String? = nil,
        childID: UUID
    ) {
        self.title = title
        self.reward = reward
        self.rewardUnitRaw = rewardUnit.rawValue
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.presetIconName = presetIconName
        self.childID = childID
    }
}

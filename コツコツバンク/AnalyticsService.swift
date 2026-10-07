//
//  AnalyticsService.swift
//  コツコツバンク
//

import Foundation
import Supabase

/// 個人を特定しない、匿名の利用状況イベントを記録するための仕組み。
/// メールアドレスや氏名などの個人情報は一切送信しない。
enum AnalyticsEvent: String {
    case appOpen = "app_open"
    case signUp = "sign_up"
    case childAdded = "child_added"
    case missionCreated = "mission_created"
    case missionSubmitted = "mission_submitted"
    case missionApproved = "mission_approved"
    case goalCreated = "goal_created"
    case goalRedeemed = "goal_redeemed"
}

enum AnalyticsService {
    private static let deviceIDKey = "kotsukotsu_anonymous_device_id"

    /// 端末ごとに一度だけ生成される、個人に紐づかないランダムなID。
    private static var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIDKey) {
            return saved
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }

    private struct EventPayload: Encodable {
        let event_type: String
        let device_id: String
        let metadata: [String: String]
    }

    /// 記録を送信する。オフライン等で失敗しても、アプリの動作には一切影響させない(ベストエフォート)。
    static func log(_ event: AnalyticsEvent, metadata: [String: String] = [:]) {
        Task {
            let payload = EventPayload(
                event_type: event.rawValue,
                device_id: deviceID,
                metadata: metadata
            )
            try? await supabase.from("analytics_events").insert(payload).execute()
        }
    }
}

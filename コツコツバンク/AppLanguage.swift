//
//  AppLanguage.swift
//  コツコツバンク
//

import Foundation

enum AppLanguage: String, CaseIterable, Codable {
    case ja
    case en
    case zh
    case ko

    var label: String {
        switch self {
        case .ja: "日本語"
        case .en: "English"
        case .zh: "中文"
        case .ko: "한국어"
        }
    }

    var locale: Locale {
        switch self {
        case .zh: Locale(identifier: "zh-Hans")
        default: Locale(identifier: rawValue)
        }
    }

    private var lprojName: String {
        switch self {
        case .zh: "zh-Hans"
        default: rawValue
        }
    }

    /// アプリの表示言語設定(端末本体の言語設定とは独立)に沿って、Localizable.xcstringsから直接文字列を引く。
    /// String(localized:locale:)はビルド環境によって稀に端末の実機で反映されないことがあるため、
    /// 該当言語の.lprojバンドルを直接読み込む、より確実な方式を使う。
    func localizedString(forKey key: String) -> String {
        guard let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

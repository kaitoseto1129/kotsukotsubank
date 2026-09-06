//
//  Formatting.swift
//  コツコツバンク
//

import Foundation

enum AppCurrency: String, CaseIterable, Codable {
    case jpy = "JPY"
    case usd = "USD"

    var symbol: String {
        switch self {
        case .jpy: "¥"
        case .usd: "$"
        }
    }

    var label: String {
        switch self {
        case .jpy: "円(¥)"
        case .usd: "ドル($)"
        }
    }

    var systemImage: String {
        switch self {
        case .jpy: "yensign.circle.fill"
        case .usd: "dollarsign.circle.fill"
        }
    }

    var maximumFractionDigits: Int {
        switch self {
        case .jpy: 0
        case .usd: 2
        }
    }
}

/// テキストフィールドの初期値などに使う、小数点以下を落とした整数文字列。
/// `String(Int(x))` は x が NaN・無限大・Int の範囲外だとクラッシュするため、安全に丸めてから変換する。
func wholeNumberString(_ value: Double) -> String {
    guard value.isFinite else { return "0" }
    let clamped = value.rounded().clamped(to: -1e15...1e15)
    return String(Int(clamped))
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

func moneyString(_ amount: Double, currencyCode: String) -> String {
    let currency = AppCurrency(rawValue: currencyCode) ?? .jpy
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = currency.maximumFractionDigits
    let number = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    return "\(currency.symbol)\(number)"
}

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

func moneyString(_ amount: Double, currencyCode: String) -> String {
    let currency = AppCurrency(rawValue: currencyCode) ?? .jpy
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = currency.maximumFractionDigits
    let number = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    return "\(currency.symbol)\(number)"
}

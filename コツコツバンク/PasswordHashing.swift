//
//  PasswordHashing.swift
//  コツコツバンク
//

import Foundation
import CryptoKit

enum PasswordHashing {
    static func hash(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 秘密の質問の答え用。大文字小文字や前後の空白の違いで一致しなくなるのを防ぐ。
    static func hashAnswer(_ raw: String) -> String {
        hash(raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

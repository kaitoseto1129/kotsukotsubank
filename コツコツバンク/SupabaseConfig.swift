//
//  SupabaseConfig.swift
//  コツコツバンク
//

import Foundation
import Supabase

/// Supabaseへの接続設定。
/// ここで使うキーは「publishable key」(旧: anon key)で、クライアントアプリに埋め込んでも問題ない公開キー。
/// データの保護は、Supabase側のRow Level Security(RLS)ポリシーで行う。
enum SupabaseConfig {
    static let projectURL = URL(string: "https://jcradcyjolyklmdsawph.supabase.co")!
    static let publishableKey = "sb_publishable_ERKwwrkojrLV1o9F65X4KA__ycZP48l"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.projectURL,
    supabaseKey: SupabaseConfig.publishableKey
)

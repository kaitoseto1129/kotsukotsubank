//
//  VoiceReader.swift
//  コツコツバンク
//

import Foundation
import AVFoundation

/// おうちの人からのメッセージを、子ども向けの高めの声で読み上げる。
final class VoiceReader: NSObject {
    static let shared = VoiceReader()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        // 高めのピッチ・少しゆっくりめの速度で、子ども向けの可愛らしい声にする
        utterance.pitchMultiplier = 1.4
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

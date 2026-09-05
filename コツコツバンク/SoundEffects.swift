//
//  SoundEffects.swift
//  コツコツバンク
//

import Foundation
import AVFoundation

/// アプリ内の効果音。子どもがタスク承認を確認した時や、LV.5達成のお祝いなどに使う。
/// iOS標準のシステムサウンドIDは端末やOSバージョンによって音が変わったり鳴らなかったりするため、
/// 効果音は自前で合成して確実に鳴らす。
enum SoundEffects {
    private static var engine: AVAudioEngine?
    private static var player: AVAudioPlayerNode?

    /// タスク承認時の「チャリーン」というコインのような音(ユーザー提供の音源を、自然な余韻が残るよう約2秒に伸ばして再生)
    static func playCoinSound() {
        playFile(named: "coin_ding", extension: "mp3", targetDuration: 2.0)
    }

    /// LV.5達成時の、ラッパのファンファーレのような音
    static func playFanfareSound() {
        play(makeFanfareBuffer)
    }

    /// バンドル内の音声ファイルを、ピッチを保ったまま指定の長さに伸縮して再生する
    private static func playFile(named name: String, extension ext: String, targetDuration: Double?) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let file = try? AVAudioFile(forReading: url) else { return }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        do {
            try file.read(into: buffer)
        } catch {
            return
        }

        let originalDuration = Double(frameCount) / format.sampleRate
        let rate: Float
        if let targetDuration, targetDuration > 0 {
            rate = Float(max(0.25, min(4.0, originalDuration / targetDuration)))
        } else {
            rate = 1.0
        }

        let newEngine = AVAudioEngine()
        let newPlayer = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = rate

        newEngine.attach(newPlayer)
        newEngine.attach(timePitch)
        newEngine.connect(newPlayer, to: timePitch, format: format)
        newEngine.connect(timePitch, to: newEngine.mainMixerNode, format: format)

        do {
            try newEngine.start()
        } catch {
            return
        }

        engine = newEngine
        player = newPlayer

        newPlayer.scheduleBuffer(buffer)
        newPlayer.play()

        // rate変更後の実際の再生時間はタイムピッチ後段で決まるため、完了コールバックではなく
        // 実時間ベースで少し余裕を持って止める(途中で音が切れるのを防ぐ)
        let stopDelay = (targetDuration ?? Double(rate == 0 ? originalDuration : originalDuration / Double(rate))) + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDelay) {
            newEngine.stop()
            if engine === newEngine {
                engine = nil
                player = nil
            }
        }
    }

    private static func play(_ makeBuffer: (Double, AVAudioFormat) -> AVAudioPCMBuffer?) {
        // マナーモード中でも効果音は聞こえてほしいので、サイレントスイッチの影響を受けないカテゴリにする
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            return
        }

        let sampleRate = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = makeBuffer(sampleRate, format) else { return }

        let newEngine = AVAudioEngine()
        let newPlayer = AVAudioPlayerNode()
        newEngine.attach(newPlayer)
        newEngine.connect(newPlayer, to: newEngine.mainMixerNode, format: format)

        do {
            try newEngine.start()
        } catch {
            return
        }

        engine = newEngine
        player = newPlayer

        newPlayer.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
            DispatchQueue.main.async {
                newEngine.stop()
                if engine === newEngine {
                    engine = nil
                    player = nil
                }
            }
        }
        newPlayer.play()
    }

    /// ラッパのファンファーレ(ド・ミ・ソ・ド、と駆け上がる4音)を、金管らしい明るい倍音を重ねて合成する
    private nonisolated static func makeFanfareBuffer(sampleRate: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let hits: [(frequency: Double, start: Double, decay: Double)] = [
            (523.25, 0.00, 5.5),   // ド
            (659.25, 0.16, 5.5),   // ミ
            (783.99, 0.32, 5.5),   // ソ
            (1046.50, 0.48, 2.2),  // ド(高い、長めに伸ばす)
        ]
        // 金管らしい明るさを出すための倍音比率と音量(ベルより倍音を多めに)
        let partials: [(ratio: Double, amplitude: Double)] = [
            (1.0, 1.0),
            (2.0, 0.7),
            (3.0, 0.55),
            (4.0, 0.35),
            (5.0, 0.2),
        ]
        return renderHits(hits, partials: partials, attackDuration: 0.012, totalDuration: 1.1, sampleRate: sampleRate, format: format, gain: 0.16)
    }

    private nonisolated static func renderHits(
        _ hits: [(frequency: Double, start: Double, decay: Double)],
        partials: [(ratio: Double, amplitude: Double)],
        attackDuration: Double,
        totalDuration: Double,
        sampleRate: Double,
        format: AVAudioFormat,
        gain: Double
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for hit in hits {
                let localT = t - hit.start
                guard localT >= 0 else { continue }
                let attack = min(localT / attackDuration, 1.0)
                let decayEnvelope = exp(-localT * hit.decay)
                let envelope = attack * decayEnvelope
                guard envelope > 0.0005 else { continue }
                var hitSample = 0.0
                for partial in partials {
                    hitSample += sin(2.0 * .pi * hit.frequency * partial.ratio * localT) * partial.amplitude
                }
                sample += hitSample * envelope
            }
            channelData[frame] = Float(sample * gain)
        }
        return buffer
    }
}

import AVFoundation
import SwiftUI

#if os(iOS)
import UIKit
#endif

final class GameFeedbackPlayer {
    private let audioPlayer = GameAudioPlayer()

    #if os(iOS)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    #endif

    init() {
        Task.detached { [audioPlayer] in
            await audioPlayer.prepare()
        }
    }

    func prepare() {
        Task.detached { [audioPlayer] in
            await audioPlayer.prepare()
        }

        #if os(iOS)
        selectionFeedback.prepare()
        lightImpact.prepare()
        softImpact.prepare()
        notificationFeedback.prepare()
        #endif
    }

    func playSelection() {
        playAudio(.select, volume: 0.28, minimumInterval: 0.04)

        #if os(iOS)
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
        #endif
    }

    func playNavigation() {
        playAudio(.navigate, volume: 0.24, minimumInterval: 0.05)

        #if os(iOS)
        lightImpact.impactOccurred(intensity: 0.36)
        lightImpact.prepare()
        #endif
    }

    func playCupReady() {
        playAudio(.cup, volume: 0.30, minimumInterval: 0.08)

        #if os(iOS)
        softImpact.impactOccurred(intensity: 0.50)
        softImpact.prepare()
        #endif
    }

    func playPour(fluid: Fluid) {
        let volume: Float = fluid.material.kind == .dense ? 0.32 : 0.26
        playAudio(.pour, volume: volume, minimumInterval: 0.08)

        #if os(iOS)
        lightImpact.impactOccurred(intensity: fluid.material.kind == .dense ? 0.54 : 0.38)
        lightImpact.prepare()
        #endif
    }

    func playInvalidMove() {
        playAudio(.invalid, volume: 0.32, minimumInterval: 0.12)

        #if os(iOS)
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
        #endif
    }

    func playLevelComplete() {
        playAudio(.complete, volume: 0.36, minimumInterval: 0.20)

        #if os(iOS)
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
        #endif
    }

    private func playAudio(_ sound: GameAudioPlayer.Sound, volume: Float, minimumInterval: TimeInterval) {
        Task.detached { [audioPlayer] in
            await audioPlayer.play(sound, volume: volume, minimumInterval: minimumInterval)
        }
    }
}

private actor GameAudioPlayer {
    enum Sound: CaseIterable, Sendable {
        case select
        case pour
        case invalid
        case complete
        case cup
        case navigate
    }

    private var players: [Sound: AVAudioPlayer] = [:]
    private var lastPlayTimes: [Sound: TimeInterval] = [:]
    private var isPrepared = false

    func prepare() {
        guard !isPrepared else { return }
        configureAudio()
        loadSounds()
        players.values.forEach { $0.prepareToPlay() }
        isPrepared = true
    }

    func play(_ sound: Sound, volume: Float, minimumInterval: TimeInterval) {
        prepare()

        let now = Date.timeIntervalSinceReferenceDate
        if let lastPlayTime = lastPlayTimes[sound], now - lastPlayTime < minimumInterval {
            return
        }

        guard let player = players[sound] else { return }
        lastPlayTimes[sound] = now
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    private func configureAudio() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        #endif
    }

    private func loadSounds() {
        for sound in Sound.allCases {
            guard let player = try? AVAudioPlayer(data: Self.data(for: sound)) else { continue }
            players[sound] = player
        }
    }

    private static func data(for sound: Sound) -> Data {
        switch sound {
        case .select:
            waveData(duration: 0.055) { t, duration in
                let envelope = shortEnvelope(t: t, duration: duration, attack: 0.006, release: 0.038)
                return envelope * sine(760, t: t) * 0.42
            }

        case .navigate:
            waveData(duration: 0.075) { t, duration in
                let envelope = shortEnvelope(t: t, duration: duration, attack: 0.006, release: 0.045)
                return envelope * (sine(520, t: t) * 0.34 + sine(780, t: t) * 0.10)
            }

        case .cup:
            waveData(duration: 0.14) { t, duration in
                let progress = t / duration
                let envelope = shortEnvelope(t: t, duration: duration, attack: 0.012, release: 0.07)
                return envelope * (sine(470 + 180 * progress, t: t) * 0.28 + sine(940, t: t) * 0.08)
            }

        case .pour:
            waveData(duration: 0.24) { t, duration in
                let progress = t / duration
                let envelope = shortEnvelope(t: t, duration: duration, attack: 0.018, release: 0.10)
                let slide = 520 - 150 * progress
                let ripple = 0.70 + 0.30 * sine(18, t: t)
                return envelope * ripple * (
                    sine(slide, t: t) * 0.20 +
                    sine(slide * 1.48, t: t) * 0.07 +
                    sine(1_650, t: t) * 0.025
                )
            }

        case .invalid:
            waveData(duration: 0.13) { t, duration in
                let progress = t / duration
                let envelope = shortEnvelope(t: t, duration: duration, attack: 0.004, release: 0.08)
                return envelope * (sine(170 - 42 * progress, t: t) * 0.36 + sine(92, t: t) * 0.12)
            }

        case .complete:
            waveData(duration: 0.58) { t, duration in
                let notes: [(start: Double, frequency: Double)] = [
                    (0.00, 523.25),
                    (0.16, 659.25),
                    (0.32, 783.99)
                ]

                return notes.reduce(0.0) { result, note in
                    guard t >= note.start else { return result }
                    let localTime = t - note.start
                    let envelope = shortEnvelope(t: localTime, duration: duration - note.start, attack: 0.014, release: 0.18)
                    return result + envelope * (
                        sine(note.frequency, t: localTime) * 0.22 +
                        sine(note.frequency * 2, t: localTime) * 0.05
                    )
                }
            }
        }
    }

    private static func waveData(
        duration: Double,
        sampleRate: Int = 44_100,
        sample: (_ time: Double, _ duration: Double) -> Double
    ) -> Data {
        let sampleCount = max(1, Int(duration * Double(sampleRate)))
        let dataByteCount = sampleCount * MemoryLayout<Int16>.size

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + dataByteCount))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(MemoryLayout<Int16>.size))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(dataByteCount))

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let value = max(-1, min(1, sample(time, duration)))
            data.appendLittleEndian(Int16(value * Double(Int16.max)))
        }

        return data
    }

    private static func shortEnvelope(t: Double, duration: Double, attack: Double, release: Double) -> Double {
        guard duration > 0 else { return 0 }
        let attackValue = min(1, max(0, t / max(attack, 0.001)))
        let releaseValue = min(1, max(0, (duration - t) / max(release, 0.001)))
        return attackValue * releaseValue
    }

    private static func sine(_ frequency: Double, t: Double) -> Double {
        sin(2 * .pi * frequency * t)
    }
}

private extension Data {
    nonisolated mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}

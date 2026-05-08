//
//  AudioPlayerService.swift
//  Harakat Lens
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioPlayerService: NSObject {
    enum State: Equatable {
        case idle
        case loadingAyah(surah: Int, ayah: Int)
        case playingAyah(surah: Int, ayah: Int)
        case speakingTTS
    }

    private(set) var state: State = .idle

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    private let reciter = "Alafasy_128kbps"

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speakArabic(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        configureSession()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "ar")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        state = .speakingTTS
        synthesizer.speak(utterance)
    }

    func playAyah(surah: Int, ayah: Int) {
        stop()
        guard let url = ayahURL(surah: surah, ayah: ayah) else { return }
        configureSession()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        state = .loadingAyah(surah: surah, ayah: ayah)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            Task { @MainActor in
                guard let self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    if case .loadingAyah = self.state {
                        self.state = .playingAyah(surah: surah, ayah: ayah)
                        self.player?.play()
                    }
                case .failed:
                    self.stop()
                default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.pause()
        player = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        state = .idle
    }

    func isPlayingAyah(surah: Int, ayah: Int) -> Bool {
        switch state {
        case let .loadingAyah(s, a), let .playingAyah(s, a):
            return s == surah && a == ayah
        default:
            return false
        }
    }

    func isLoadingAyah(surah: Int, ayah: Int) -> Bool {
        if case let .loadingAyah(s, a) = state {
            return s == surah && a == ayah
        }
        return false
    }

    var isSpeakingTTS: Bool {
        if case .speakingTTS = state { return true }
        return false
    }

    private func configureSession() {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [])
            try? session.setActive(true, options: [])
        #endif
    }

    private func ayahURL(surah: Int, ayah: Int) -> URL? {
        let s = String(format: "%03d", surah)
        let a = String(format: "%03d", ayah)
        return URL(string: "https://everyayah.com/data/\(reciter)/\(s)\(a).mp3")
    }
}

extension AudioPlayerService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in
            if case .speakingTTS = state { state = .idle }
        }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in
            if case .speakingTTS = state { state = .idle }
        }
    }
}

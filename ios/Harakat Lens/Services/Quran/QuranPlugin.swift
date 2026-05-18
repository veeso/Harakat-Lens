//
//  QuranPlugin.swift
//  Harakat Lens
//
//  The Quran feature in the library's `FeaturePlugin` slot.
//
//  The library calls `inlineResultView(for:)` synchronously and never
//  observes the plugin, so plugin state changes alone cannot re-render a
//  library screen. The returned view therefore observes an `@Observable`
//  `QuranMatchModel` owned by the plugin — mutating the model (e.g. on
//  dismiss) re-renders the view that is on screen.
//
//  Behaviour ported from the pre-migration app:
//   - Sticky: once a verse is shown it stays; the model is not recomputed
//     until the user dismisses it. "Not updated unless dismissed."
//   - Cooldown: dismissing a verse suppresses that same verse for 5s so it
//     cannot immediately respawn.
//   - Source-aware: `.text` always returns the (non-sheet) output view so
//     it can host the sticky card; `.camera` returns `nil` when there is no
//     hit so the library does not pop a sheet for every recognised box.
//
//  Gated on the `quranMode` extra setting (read from the same UserDefaults
//  key the library's `SettingsStore` persists).
//

import BiangBiangUI
import Foundation
import SwiftUI

@MainActor
@Observable
final class QuranMatchModel {
    var match: QuranMatch?
    var surahName: SurahName?
}

@MainActor
final class QuranPlugin: FeaturePlugin {
    private let everyAyah = EveryAyahAudioProvider()
    private let model = QuranMatchModel()

    // Snapshot of the dataset, loaded once. Touched only on the main actor.
    private var ayat: [QuranAyah] = []
    private var tokenIndex: [String: [Int]] = [:]
    private var surahNames: [Int: SurahName] = [:]
    private var snapshotLoaded = false

    // Respawn suppression after a user dismissal.
    private var dismissedMatchId: String?
    private var dismissedUntil: Date = .distantPast
    private static let dismissCooldown: TimeInterval = 5

    /// Camera only: the verse id currently presented in the library sheet.
    /// Used to return the card exactly once so the library does not re-mint
    /// (and thus re-present) the sheet on every OCR tick.
    private var presentedMatchId: String?

    init() {
        preloadSnapshot()
    }

    // MARK: - inlineResultView

    func inlineResultView(for result: ProcessedText) -> AnyView? {
        guard Self.quranModeEnabled else {
            model.match = nil
            model.surahName = nil
            return nil
        }

        // Sticky: do not recompute while a verse is on screen. Only look for
        // a new match when nothing is currently shown.
        if model.match == nil, snapshotLoaded {
            if let found = QuranMatcher.bestMatch(
                result.original,
                all: ayat,
                tokenIndex: tokenIndex
            ), !isSuppressed(found) {
                model.match = found
                model.surahName = surahNames[found.ayah.surah]
            }
        } else if !snapshotLoaded {
            preloadSnapshot()
        }

        switch result.source {
        case .camera:
            // Sheet contract: nil unless there is a hit to show. Return the
            // card only on the transition to a new verse; while the same
            // verse is already on screen return nil so the library leaves
            // the sheet untouched (no per-tick re-present).
            guard let match = model.match else {
                presentedMatchId = nil
                return nil
            }
            guard match.id != presentedMatchId else { return nil }
            presentedMatchId = match.id
            return AnyView(
                QuranInlineView(
                    model: model,
                    audio: everyAyah,
                    transliteration: result.transliteration,
                    source: .camera,
                    onDismiss: { [weak self] in self?.dismissActiveMatch() }
                )
            )
        case .text:
            // Always non-nil so the sticky card has a stable host; the view
            // shows the plain transliteration when there is no match.
            return AnyView(
                QuranInlineView(
                    model: model,
                    audio: everyAyah,
                    transliteration: result.transliteration,
                    source: .text,
                    onDismiss: { [weak self] in self?.dismissActiveMatch() }
                )
            )
        }
    }

    // MARK: - audioProvider

    var audioProvider: (any AudioProvider)? {
        everyAyah
    }

    // MARK: - Dismissal / cooldown

    private func dismissActiveMatch() {
        if let match = model.match {
            dismissedMatchId = match.id
            dismissedUntil = Date().addingTimeInterval(Self.dismissCooldown)
        }
        model.match = nil
        model.surahName = nil
        presentedMatchId = nil
    }

    private func isSuppressed(_ match: QuranMatch) -> Bool {
        dismissedMatchId == match.id && Date() < dismissedUntil
    }

    // MARK: - Snapshot

    private func preloadSnapshot() {
        guard !snapshotLoaded else { return }
        Task {
            let dataset = QuranDataset.shared
            await dataset.loadIfNeeded()
            let all = await dataset.all
            let index = await dataset.tokenIndex
            let names = await dataset.surahNames
            self.ayat = all
            self.tokenIndex = index
            self.surahNames = names
            self.snapshotLoaded = !all.isEmpty
        }
    }

    /// Reads the `quranMode` toggle straight from the same `UserDefaults`
    /// key the library's `SettingsStore` persists (`descriptor.<key>`).
    private static var quranModeEnabled: Bool {
        UserDefaults.standard.string(forKey: "descriptor.quranMode") == "true"
    }
}

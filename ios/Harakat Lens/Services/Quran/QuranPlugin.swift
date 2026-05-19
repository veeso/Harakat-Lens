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

    /// Single in-flight matching job. `bestMatch` is O(dataset) and must
    /// never run on the main actor (it froze the camera/UI). At most one
    /// runs at a time; the library keeps ticking, so a skipped tick is
    /// retried with newer text on the next call.
    private var matchTask: Task<Void, Never>?

    /// The last text handed to a match job. The camera yields near-identical
    /// normalized text every frame; re-scanning the same text is the work
    /// that starved the OCR pipeline, so identical input is skipped.
    private var lastScheduledQuery: String?

    init() {
        preloadSnapshot()
    }

    /// Injects a preloaded snapshot (callers that already hold one / tests).
    init(
        ayat: [QuranAyah],
        tokenIndex: [String: [Int]],
        surahNames: [Int: SurahName]
    ) {
        self.ayat = ayat
        self.tokenIndex = tokenIndex
        self.surahNames = surahNames
        snapshotLoaded = !ayat.isEmpty
    }

    /// The match currently held by the observed model, if any.
    var currentMatch: QuranMatch? {
        model.match
    }

    /// Whether a background match job is currently in flight.
    var isMatching: Bool {
        matchTask != nil
    }

    // MARK: - inlineResultView

    func inlineResultView(for result: ProcessedText) -> AnyView? {
        guard Self.quranModeEnabled else {
            model.match = nil
            model.surahName = nil
            return nil
        }

        // Sticky: do not recompute while a verse is on screen. Only look for
        // a new match when nothing is currently shown. The match itself runs
        // off the main actor (see `scheduleMatch`) so this call returns at
        // once and never blocks the camera/UI.
        if model.match == nil, snapshotLoaded {
            scheduleMatch(for: result.original)
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
        // Allow the same frame text to be re-scanned once the cooldown ends.
        lastScheduledQuery = nil
    }

    private func isSuppressed(_ match: QuranMatch) -> Bool {
        dismissedMatchId == match.id && Date() < dismissedUntil
    }

    // MARK: - Matching (off the main actor)

    /// Runs `QuranMatcher.bestMatch` on a background executor and delivers
    /// the result back on the main actor via the observed model. At most one
    /// job runs at a time; while one is in flight new ticks are dropped (the
    /// library re-ticks, so the next free slot uses fresher text).
    private func scheduleMatch(for rawArabic: String) {
        guard matchTask == nil else { return }
        // Same frame text as the last scan → nothing new to find. Skipping
        // this is what keeps the background scans off the OCR pipeline.
        guard rawArabic != lastScheduledQuery else { return }
        lastScheduledQuery = rawArabic
        let snapshotAyat = ayat
        let snapshotIndex = tokenIndex
        matchTask = Task { [weak self] in
            // `.utility`: must yield CPU to the Vision OCR pipeline so text
            // detection is not starved.
            let found = await Task.detached(priority: .utility) {
                QuranMatcher.bestMatch(
                    rawArabic,
                    all: snapshotAyat,
                    tokenIndex: snapshotIndex
                )
            }.value
            guard let self else { return }
            defer { self.matchTask = nil }
            // Verse may have appeared (or been dismissed) while we computed.
            guard self.model.match == nil else { return }
            if let found, !self.isSuppressed(found) {
                self.model.match = found
                self.model.surahName = self.surahNames[found.ayah.surah]
            }
        }
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

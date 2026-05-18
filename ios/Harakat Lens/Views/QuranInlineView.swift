//
//  QuranInlineView.swift
//  Harakat Lens
//
//  The view the Quran plugin returns. It observes the plugin's
//  `@Observable` QuranMatchModel, so dismissing the card (which clears the
//  model) re-renders this view even though the library never observes the
//  plugin itself.
//
//  - `.text`: hosts the sticky card inline; shows the plain transliteration
//    when there is no match (the library's own output box is suppressed
//    because this view is non-nil).
//  - `.camera`: the card is shown in a library half-sheet. `.onDisappear`
//    reports the close (swipe or button) so the plugin starts its cooldown.
//

import BiangBiangUI
import SwiftUI

struct QuranInlineView: View {
    @Bindable var model: QuranMatchModel
    @Bindable var audio: EveryAyahAudioProvider
    let transliteration: String
    let source: ProcessedText.Source
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if let match = model.match {
                let card = QuranMatchView(
                    match: match,
                    surahName: model.surahName,
                    audio: audio,
                    showsDismissButton: source == .text,
                    onDismiss: onDismiss
                )
                if source == .camera {
                    // Fill the library half-sheet instead of floating as a
                    // small card in the centre.
                    ScrollView {
                        card.padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    card
                }
            } else if source == .text {
                ReadOnlyTextBox(text: transliteration)
            }
        }
        .onDisappear {
            // Camera: the half-sheet was closed (swipe or button). Report it
            // so the same verse is suppressed for the cooldown window.
            if source == .camera {
                onDismiss()
            }
        }
    }
}

/// Local copy of the library's read-only output box (its own is `private`
/// to `TextScreen`) so the no-match text path looks identical to the plain
/// transliteration output it replaces.
private struct ReadOnlyTextBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(8)
            .textSelection(.enabled)
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(.secondary)
            }
    }
}

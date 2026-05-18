//
//  QuranMatchView.swift
//  Harakat Lens
//
//  Adapted for the library plugin slot: the audio service is injected as an
//  `EveryAyahAudioProvider` reference (instead of `@Environment` from the
//  app), and the brand-green colour is a local constant (the library's
//  `AppDesign` doesn't vend it). Layout and behaviour are unchanged.
//

import BiangBiangUI
import SwiftUI

struct QuranMatchView: View {
    let match: QuranMatch
    let surahName: SurahName?
    @Bindable var audio: EveryAyahAudioProvider
    /// Shows the ✕ button. Only the inline (text) card needs it; the camera
    /// half-sheet is dismissed by swiping down, so the ✕ would be redundant.
    var showsDismissButton: Bool
    /// User dismissal. The plugin clears the sticky match and starts the
    /// respawn cooldown so the same verse does not immediately reappear.
    var onDismiss: () -> Void

    private let brandGreen = Color(red: 0x00 / 255.0, green: 0x6C / 255.0, blue: 0x35 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.stackSpacing) {
            HStack(alignment: .firstTextBaseline) {
                QuranMatchHeaderView(headerLine: headerLine, brandGreen: brandGreen)
                if showsDismissButton {
                    Spacer()
                    Button {
                        audio.stop()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss Quran match")
                }
            }
            Text(match.ayah.text)
                .font(.title2)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(match.ayah.transliteration)
                .font(.body.italic())
                .foregroundStyle(.secondary)
            Text(match.ayah.translationEn)
                .font(.body)
            HStack {
                listenButton
                Button("Copy", systemImage: "doc.on.doc", action: copyToClipboard)
                    .buttonStyle(.bordered)
                ShareLink(item: formattedForCopy) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .fill(brandGreen.opacity(0.08))
        )
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .stroke(brandGreen.opacity(0.6), lineWidth: 1)
        }
    }

    private var headerLine: String {
        let nameLabel: String = {
            if let s = surahName {
                return "\(s.transliteration) (\(s.english))"
            }
            return "Surah \(match.ayah.surah)"
        }()
        return "Surah \(match.ayah.surah) · \(nameLabel) · Ayah \(match.ayah.ayah)"
    }

    private var formattedForCopy: String {
        """
        \(headerLine)

        \(match.ayah.text)

        \(match.ayah.transliteration)

        \(match.ayah.translationEn)
        """
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = formattedForCopy
    }

    @ViewBuilder
    private var listenButton: some View {
        let surah = match.ayah.surah
        let ayah = match.ayah.ayah
        let isLoading = audio.isLoadingAyah(surah: surah, ayah: ayah)
        let isPlaying = audio.isPlayingAyah(surah: surah, ayah: ayah)
        Button {
            if isPlaying || isLoading {
                audio.stop()
            } else {
                audio.playAyah(surah: surah, ayah: ayah)
            }
        } label: {
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading")
                }
            } else if isPlaying {
                Label("Stop", systemImage: "stop.circle.fill")
            } else {
                Label("Listen", systemImage: "play.circle.fill")
            }
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Stream the recitation of this ayah")
    }
}

private struct QuranMatchHeaderView: View {
    let headerLine: String
    let brandGreen: Color

    var body: some View {
        Label(headerLine, systemImage: "book.closed.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(brandGreen)
    }
}

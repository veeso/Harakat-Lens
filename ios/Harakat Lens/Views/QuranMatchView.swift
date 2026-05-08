//
//  QuranMatchView.swift
//  Harakat Lens
//

import SwiftUI

struct QuranMatchView: View {
    let match: QuranMatch
    let surahName: SurahName?

    @Environment(AudioPlayerService.self) private var audio

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.stackSpacing) {
            QuranMatchHeaderView(headerLine: headerLine)
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
                .fill(AppDesign.brandGreen.opacity(0.08))
        )
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                .stroke(AppDesign.brandGreen.opacity(0.6), lineWidth: 1)
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

    var body: some View {
        Label(headerLine, systemImage: "book.closed.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppDesign.brandGreen)
    }
}

#Preview {
    QuranMatchView(
        match: QuranMatch(
            ayah: QuranAyah(
                surah: 1,
                ayah: 2,
                text: "الرَّحْمَٰنِ الرَّحِيمِ",
                normalized: "الرحمن الرحيم",
                transliteration: "ar-raḥmāni r-raḥīmi",
                translationEn: "The Most Compassionate, The Most Merciful"
            ),
            score: 1.0,
            kind: .exact
        ),
        surahName: SurahName(
            number: 1,
            english: "The Opening",
            transliteration: "Al-Fatihah",
            arabic: "الفاتحة"
        )
    )
    .padding()
    .environment(AudioPlayerService())
}

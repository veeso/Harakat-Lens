//
//  TextModeView.swift
//  Harakat Lens
//

import SwiftUI
import Translation

struct TextModeView: View {
    @Environment(AppSettings.self) private var settings

    @State private var inputText: String = ""
    @State private var transliteratedText: String = ""
    @State private var translatedText: String = ""
    @State private var quranMatch: QuranMatch?
    @State private var matcher: QuranMatcher?
    @State private var surahNames: [Int: SurahName] = [:]
    @State private var debounceTask: Task<Void, Never>?
    @State private var translateConfig: TranslationSession.Configuration?

    private let textProcessor = TextProcessor()

    var body: some View {
        ScrollView {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(.rect(cornerRadius: AppDesign.cornerRadius))
                    .accessibilityHidden(true)
                Text("Harakat Lens")
                    .font(.title)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            Text("Transliterate Arabic")
                .font(.title2)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: AppDesign.sectionSpacing) {
                arabicInputSection
                transliterationOutputSection
                if let match = quranMatch {
                    QuranMatchView(
                        match: match,
                        surahName: surahName(for: match.ayah.surah)
                    )
                    .padding(.horizontal, AppDesign.horizontalPadding)
                }
                translationSection
            }
        }
    }

    private var arabicInputSection: some View {
        SectionView(
            title: "Arabic",
            actionLabel: "Paste",
            actionIcon: "doc.on.clipboard",
            action: pasteFromClipboard
        ) {
            TextField("Type or paste Arabic", text: $inputText, axis: .vertical)
                .font(.title2)
                .lineLimit(5 ... 10)
                .padding(8)
                .multilineTextAlignment(.trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                        .stroke(.secondary)
                }
                .onChange(of: inputText) { _, _ in
                    scheduleDebouncedProcessing()
                }
        }
        .padding(.horizontal, AppDesign.horizontalPadding)
    }

    private var transliterationOutputSection: some View {
        SectionView(
            title: "Transliteration",
            actionLabel: "Copy",
            actionIcon: "doc.on.doc",
            action: { copyToClipboard(transliteratedText) }
        ) {
            ReadOnlyTextBox(text: transliteratedText, font: .title3)
        }
        .padding(.horizontal, AppDesign.horizontalPadding)
    }

    private var translationSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.stackSpacing) {
            SectionView(
                title: "Translation",
                actionLabel: "Copy",
                actionIcon: "doc.on.doc",
                action: { copyToClipboard(translatedText) }
            ) {
                ReadOnlyTextBox(text: translatedText, font: .title3)
            }

            HStack {
                Spacer()
                Button("Translate", systemImage: "globe", action: triggerTranslation)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .font(.headline)
                    .translationTask(translateConfig) { session in
                        await runTranslation(using: session)
                    }
                    .accessibilityHint("Translate the Arabic text to your selected language")
            }
        }
        .padding(.horizontal, AppDesign.horizontalPadding)
    }

    private func triggerTranslation() {
        if translateConfig != nil {
            translateConfig?.invalidate()
            translateConfig = nil
            return
        }
        translateConfig = .init(
            source: .init(identifier: "ar"),
            target: .init(identifier: settings.userLanguage)
        )
    }

    private func runTranslation(using session: TranslationSession) async {
        do {
            let response = try await session.translate(inputText)
            translatedText = response.targetText
        } catch {
            translatedText = "❌ Translation failed: \(error.localizedDescription)"
        }
    }

    private func scheduleDebouncedProcessing() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            processInput()
        }
    }

    private func processInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            transliteratedText = ""
            translatedText = ""
            quranMatch = nil
            return
        }
        transliteratedText = textProcessor.process(text: inputText) ?? ""

        if settings.quranMode {
            Task { await runQuranMatch(for: inputText) }
        } else {
            quranMatch = nil
        }
    }

    @MainActor
    private func runQuranMatch(for text: String) async {
        let dataset = QuranDataset.shared
        await dataset.loadIfNeeded()
        if matcher == nil {
            matcher = QuranMatcher(dataset: dataset)
            surahNames = await dataset.surahNames
        }
        let match = await matcher?.match(text)
        quranMatch = match
    }

    private func surahName(for surah: Int) -> SurahName? {
        surahNames[surah]
    }

    private func pasteFromClipboard() {
        if let pasteboard = UIPasteboard.general.string {
            inputText = pasteboard
        }
    }

    private func copyToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
    }
}

private struct ReadOnlyTextBox: View {
    let text: String
    let font: Font

    var body: some View {
        Text(text)
            .font(font)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(8)
            .textSelection(.enabled)
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.cornerRadius)
                    .stroke(.secondary)
            }
    }
}

#Preview {
    TextModeView().environment(AppSettings())
}

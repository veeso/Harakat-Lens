//
//  SettingsView.swift
//  Harakat Lens
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    private static let availableLanguages: [(id: String, name: String)] =
        Locale.availableIdentifiers.map { id in
            (
                id: id,
                name: Locale.current.localizedString(forIdentifier: id) ?? id
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    Picker("Language", selection: $settings.userLanguage) {
                        ForEach(Self.availableLanguages, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Label("Translation language", systemImage: "globe")
                }

                Section {
                    Toggle("Quran mode", isOn: $settings.quranMode)
                } header: {
                    Label("Quran mode", systemImage: "book.closed")
                } footer: {
                    Text(
                        "Identifies Quran verses in scanned or typed Arabic and shows the surah name, ayah number, and translation."
                    )
                }

                Section {
                    Button(
                        "Open a new issue on GitHub",
                        systemImage: "link",
                        action: openGitHubIssues
                    )
                    Button(
                        "Send an email",
                        systemImage: "envelope",
                        action: sendBugEmail
                    )
                } header: {
                    Label("Report a bug", systemImage: "ladybug")
                }

                Section {
                    Text(
                        "Quran text: Tanzil Project (Uthmani). English translation: Sahih International."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    Text(
                        "Vocalized Arabic dictionary derived from the Tashkeela corpus (Taha Zerrouki et al., GPL)."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Label("Attributions", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func openGitHubIssues() {
        guard let url = URL(string: "https://github.com/veeso/Harakat-Lens/issues/new") else {
            return
        }
        openURL(url)
    }

    private func sendBugEmail() {
        let subject = "[iOS] Bug report – Harakat Lens"
        let body = """
        Description:

        Step to reproduce:

        Device:
        iOS version:
        """
        .replacingOccurrences(of: "\n", with: "\r\n")

        guard
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "mailto:info@veeso.dev?subject=\(encodedSubject)&body=\(encodedBody)")
        else { return }
        openURL(url)
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings())
}

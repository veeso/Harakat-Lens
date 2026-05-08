//
//  Harakat_LensApp.swift
//  Harakat Lens
//
//  Created by christian visintin on 31/10/25.
//

import SwiftUI

@main
struct Harakat_LensApp: App {
    @State private var settings = AppSettings()

    init() {
        Task.detached(priority: .utility) {
            await QuranDataset.shared.loadIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}

//
//  VocalizationDictionary.swift
//  Harakat Lens
//

import Foundation

final class VocalizationDictionary: @unchecked Sendable {
    static let shared = VocalizationDictionary()

    private let map: [String: String]

    /// Test-friendly initializer. Production code uses `shared`.
    init(map: [String: String]) {
        self.map = map
    }

    private convenience init() {
        self.init(map: Self.loadFromBundle())
    }

    func lookup(_ bare: String) -> String? {
        map[bare]
    }

    private static func loadFromBundle() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "plist") else {
            print("⚠️ VocalizationDictionary: vocab.plist missing from bundle")
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            guard let dict = decoded as? [String: String] else {
                print("⚠️ VocalizationDictionary: vocab.plist root is not [String: String]")
                return [:]
            }
            return dict
        } catch {
            print("⚠️ VocalizationDictionary: failed to load vocab.plist: \(error)")
            return [:]
        }
    }
}

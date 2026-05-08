//
//  QuranDataset.swift
//  Harakat Lens

import Foundation

actor QuranDataset {
    static let shared = QuranDataset()

    private(set) var all: [QuranAyah] = []
    private(set) var surahNames: [Int: SurahName] = [:]
    private(set) var tokenIndex: [String: [Int]] = [:]
    private var loaded = false

    init() {}

    func loadIfNeeded() async {
        if loaded { return }
        loaded = true

        let bundle = Bundle.main
        let ayat = Self.decodeArray(QuranAyah.self, named: "quran", in: bundle)
        let names = Self.decodeArray(SurahName.self, named: "surah-names", in: bundle)
        all = ayat
        surahNames = Dictionary(uniqueKeysWithValues: names.map { ($0.number, $0) })

        var index: [String: [Int]] = [:]
        for (i, ayah) in ayat.enumerated() {
            for token in ayah.normalized.split(separator: " ") {
                let key = String(token)
                index[key, default: []].append(i)
            }
        }
        tokenIndex = index
    }

    private static func decodeArray<T: Decodable>(
        _: T.Type,
        named: String,
        in bundle: Bundle
    ) -> [T] {
        guard let url = bundle.url(forResource: named, withExtension: "json") else {
            print("⚠️ QuranDataset: \(named).json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            print("⚠️ QuranDataset: failed to decode \(named).json: \(error)")
            return []
        }
    }
}

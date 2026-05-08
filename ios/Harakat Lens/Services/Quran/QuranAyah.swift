//
//  QuranAyah.swift
//  Harakat Lens

import Foundation

struct QuranAyah: Decodable, Identifiable, Hashable {
    let surah: Int
    let ayah: Int
    let text: String
    let normalized: String
    let transliteration: String
    let translationEn: String

    var id: String {
        "\(surah):\(ayah)"
    }

    enum CodingKeys: String, CodingKey {
        case surah
        case ayah
        case text
        case normalized
        case transliteration
        case translationEn = "translation_en"
    }
}

struct SurahName: Decodable, Identifiable, Hashable {
    let number: Int
    let english: String
    let transliteration: String
    let arabic: String

    var id: Int {
        number
    }
}

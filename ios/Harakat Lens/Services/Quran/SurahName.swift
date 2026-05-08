//
//  SurahName.swift
//  Harakat Lens

import Foundation

struct SurahName: Decodable, Identifiable, Hashable {
    let number: Int
    let english: String
    let transliteration: String
    let arabic: String

    var id: Int {
        number
    }
}

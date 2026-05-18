//
//  ArabicTransliterator.swift
//  Harakat Lens
//
//  Arabic romanisation conforming to the library `Transliterator` protocol.
//  Pipeline (the former `TextProcessor.arabicToLatin`): vocalize each word
//  from the vocab dictionary → `ArabicNormalizer(.transliteration)` cleanup
//  → `CFStringTransform(kCFStringTransformToLatin)`. Pure and `Sendable`;
//  the library's `TextProcessingEngine` owns span detection and spacing.
//

import BiangBiangUI
import Foundation

struct ArabicTransliterator: Transliterator {
    func transliterate(_ scriptSpan: String) -> String {
        let vocalizer = Vocalizer()
        // Vocalize word-by-word: the dictionary is keyed on bare words.
        let vocalized = scriptSpan
            .split(separator: " ", omittingEmptySubsequences: false)
            .map { vocalizer.vocalize(String($0)) }
            .joined(separator: " ")

        let normalized = ArabicNormalizer(mode: .transliteration).normalize(vocalized)

        let mutString = NSMutableString(string: normalized) as CFMutableString
        CFStringTransform(mutString, nil, kCFStringTransformToLatin, false)
        return mutString as String
    }
}

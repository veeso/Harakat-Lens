//
//  ArabicNormalizer.swift
//  Harakat Lens
//

import Foundation

struct ArabicNormalizer {
    let unifyTaMarbuta: Bool

    init(unifyTaMarbuta: Bool = false) {
        self.unifyTaMarbuta = unifyTaMarbuta
    }

    func normalize(_ input: String) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(input.unicodeScalars.count)

        for scalar in input.unicodeScalars {
            let v = scalar.value

            // Tatweel
            if v == 0x0640 { continue }

            // Harakat + superscript alef
            if (0x064B ... 0x0652).contains(v) || v == 0x0670 { continue }

            // Alef variants
            if v == 0x0623 || v == 0x0625 || v == 0x0622 || v == 0x0671 {
                scalars.append(Unicode.Scalar(0x0627)!) // ا
                continue
            }

            // Alef maqsura
            if v == 0x0649 {
                scalars.append(Unicode.Scalar(0x064A)!) // ي
                continue
            }

            // Optional ta marbuta
            if unifyTaMarbuta, v == 0x0629 {
                scalars.append(Unicode.Scalar(0x0647)!) // ه
                continue
            }

            scalars.append(scalar)
        }

        return String(scalars)
            .replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespaces)
    }
}

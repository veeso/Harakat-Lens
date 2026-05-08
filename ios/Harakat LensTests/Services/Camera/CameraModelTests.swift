//
//  CameraModelTests.swift
//  Harakat Lens
//

@testable import Harakat_Lens
import Testing

@MainActor
struct CameraModelTests {
    @Test func defaultsAreSafe() {
        let m = CameraModel()
        #expect(m.recognizedTexts.isEmpty)
        #expect(m.transliterationMap.isEmpty)
        #expect(m.showTransliteration == true)
        #expect(m.quranModeEnabled == false)
        #expect(m.quranMatch == nil)
        #expect(m.capturedImage == nil)
    }
}

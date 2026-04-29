import Testing
import Foundation
@testable import DOSBTSApp

@Suite("QuickTimeChips")
struct QuickTimeChipsTests {
    @Test("applying −15m preset subtracts 15 minutes from now")
    func minus15() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        let result = QuickTimeChips.applyPreset(.minus(15), anchor: anchor)
        #expect(result.timeIntervalSince(anchor) == -900)
    }

    @Test(".now resets to anchor")
    func now() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        let result = QuickTimeChips.applyPreset(.now, anchor: anchor)
        #expect(result == anchor)
    }
}

import Testing
import SwiftUI
@testable import DOSBTSApp

@Suite("AmberChip")
struct AmberChipTests {
    @Test("init stores selection state")
    func selectionStored() {
        let chip = AmberChip(label: "MEAL", isSelected: true) {}
        #expect(chip.isSelected == true)
    }
}

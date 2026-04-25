import Testing
@testable import DOSBTSApp

@Suite("StagingPlateRow")
struct StagingPlateRowTests {
    @Test("amount change auto-scales carbs when ratio is set")
    func autoScale() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 22.5, baseServingG: 60, currentAmountG: 60, carbsPerG: 0.375)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 120)
        #expect(item.currentAmountG == 120)
        #expect(item.carbsG == 45.0)
    }

    @Test("manual carb edit breaks the ratio link")
    func manualOverride() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 45, baseServingG: 60, currentAmountG: 120, carbsPerG: 0.375)
        StagingPlateRowLogic.applyCarbsChange(item: &item, newCarbs: 50)
        #expect(item.carbsG == 50)
        #expect(item.carbsPerG == nil)
    }

    @Test("amount over 10000 clamps")
    func clampsLargeAmount() {
        var item = EditableFoodItem(name: "Test", carbsG: 0, baseServingG: 100, currentAmountG: 100, carbsPerG: 0.5)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 50000)
        #expect(item.currentAmountG == 10000)
    }

    @Test("summary text differs by amount presence")
    func summary() {
        let withAmount = EditableFoodItem(name: "Pasta", carbsG: 38, baseServingG: 120, currentAmountG: 120, carbsPerG: nil)
        let withoutAmount = EditableFoodItem(name: "Bacon", carbsG: 2, baseServingG: nil, currentAmountG: nil, carbsPerG: nil)
        #expect(StagingPlateRowLogic.summary(for: withAmount) == "120g · 38g C")
        #expect(StagingPlateRowLogic.summary(for: withoutAmount) == "2g C")
    }
}

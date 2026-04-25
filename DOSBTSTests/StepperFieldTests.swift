import Testing
@testable import DOSBTSApp

@Suite("StepperField")
struct StepperFieldTests {
    @Test("incrementing past upper bound clamps")
    func clampsUp() {
        var v: Double? = 49.5
        StepperField.increment(&v, step: 0.5, range: 0...50)
        #expect(v == 50.0)
        StepperField.increment(&v, step: 0.5, range: 0...50)
        #expect(v == 50.0)
    }

    @Test("decrementing nil treats it as 0 and clamps to lower bound")
    func clampsDown() {
        var v: Double? = nil
        StepperField.decrement(&v, step: 0.5, range: 0...50)
        #expect(v == 0.0)
    }
}

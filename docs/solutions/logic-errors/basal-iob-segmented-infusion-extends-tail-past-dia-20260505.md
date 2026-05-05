---
title: "Segmented basal IOB integration extends observable IOB to ~2× DIA — use point-dose decay instead"
date: 2026-05-05
category: logic-errors
module: IOB
problem_type: logic_error
component: tooling
severity: medium
symptoms:
  - "Basal insulin still showing IOB > 0 well past the configured DIA (e.g., a 24h basal logged at 22:00 yesterday still showing IOB at 09:00 today)"
  - "User-reported intuition mismatch: 'I set my basal DIA to 24 hours, why is it still active 30+ hours later?'"
  - "Hero-row IOB display under-reporting carb correction needs because basal contribution is artificially elevated"
root_cause: logic_error
resolution_type: code_fix
tags: [iob, basal, dia, pharmacokinetics, dmnc-692]
---

# Segmented basal IOB integration extends observable IOB to ~2× DIA — use point-dose decay instead

## Problem

DOSBTS modeled basal insulin IOB by segmenting the entry's `(starts, ends)` duration into 5-min chunks and decaying each chunk independently from its midpoint over the basal model's DIA. For a once-a-day Tresiba/Lantus injection logged with `ends = starts + 24h` and a 24h DIA:

- The first segment (delivered at `starts + 0`) decays to zero at `starts + 24h`
- The last segment (delivered at `starts + 24h`) doesn't start decaying until `starts + 24h`, then decays to zero at `starts + 48h`

So observable IOB extended to `starts + 2 × DIA` — a 24h basal still showed IOB at hour 36-47, contradicting the user's mental model that "24h DIA = fade in 24h."

## Symptoms

- Hero-row IOB display showing basal contribution well past the user's configured DIA
- Old basal entries persisting in `correctionBasalIOB` past the expected window
- Cross-day stacking concerns when in reality the prior day's basal had already fully absorbed

## What Didn't Work

- **Capping the segmentation window** at `starts + DIA` (excluding segments past that point) doesn't fix the underlying issue — segments delivered late in the infusion still need their own DIA's worth of decay, and capping it creates a discontinuity at the cap boundary.
- **Per-segment custom DIA** (each segment uses `effective_DIA = DIA - segment_offset`) requires reconstructing the exponential model per segment, which is expensive and produces an awkward curve shape because the Maksimovic model's peak/DIA constants are coupled.
- **Documenting the behavior as "correct pharmacokinetics"** misses the point — Tresiba/Lantus/Levemir are absorbed gradually from a subcutaneous depot, but the user-facing DIA is supposed to mean "time until effect is zero," not "time until each microsegment is zero."

## Solution

Treat basal as a **point dose at `delivery.starts`**, decaying over the basal model's DIA. Same shape as bolus computation but with the long-acting model's curve.

**Before** (`Library/Content/IOBCalculator.swift`):

```swift
if delivery.type == .basal {
    iob = computeBasalIOB(delivery: delivery, model: basalModel, at: date)
} else {
    let elapsed = date.timeIntervalSince(delivery.starts)
    iob = delivery.units * bolusModel.percentEffectRemaining(at: elapsed)
}

// ...

private func computeBasalIOB(delivery: InsulinDelivery, model: ExponentialInsulinModel, at date: Date) -> Double {
    let totalDuration = delivery.ends.timeIntervalSince(delivery.starts)
    guard totalDuration > 0 else { /* fallback */ }
    var iob: Double = 0
    var segmentStart: TimeInterval = 0
    while segmentStart < totalDuration {
        let segmentEnd = min(segmentStart + basalSegmentDelta, totalDuration)
        let segmentDose = delivery.units * (segmentEnd - segmentStart) / totalDuration
        let segmentMidpoint = delivery.starts.addingTimeInterval(segmentStart + (segmentEnd - segmentStart) / 2)
        let elapsed = date.timeIntervalSince(segmentMidpoint)
        if elapsed > 0 {
            iob += segmentDose * model.percentEffectRemaining(at: elapsed)
        }
        segmentStart = segmentEnd
    }
    return iob
}
```

**After:**

```swift
let elapsed = date.timeIntervalSince(delivery.starts)
let model = delivery.type == .basal ? basalModel : bolusModel
let iob = delivery.units * model.percentEffectRemaining(at: elapsed)
```

The `computeBasalIOB` function and its `basalSegmentDelta` constant were deleted entirely. The `delivery.ends` field is preserved on the model for charting but no longer participates in IOB math.

## Why This Works

The Maksimovic exponential model parameterized via `ExponentialInsulinModel.basal(diaMinutes:)` produces a curve that:
- Peaks at `DIA × 0.4` post-injection (≈9.6h for 24h DIA)
- Reaches zero at `t = DIA`

Treating the entire basal dose as deposited at `starts` and decaying through this curve gives users the "24h DIA = fade in 24h" behavior they expect. The user-facing model becomes "long-acting basal is a slow-release depot at the injection time," which matches how Tresiba/Lantus/Levemir are perceived clinically even though pharmacologically the depot releases gradually.

The lost detail — the gradual ramp-up shape of continuous-pump basal — is real but doesn't apply to DOSBTS's audience (CGM-display app users on injection therapy). Pump users logging continuous basal as separate entries (e.g., 0.5U every 15 min) get correct behavior because each tiny entry decays from its own `starts`.

## Prevention

- **Regression test** — `IOBCalculatorTests.basalFadesAtDIA` pins the new behavior: a 12U basal logged 24h ago with a 24h-DIA basal model returns IOB < 0.05U (below the zero threshold). A future change reintroducing segmentation will fail this test.
- **Mental model check for IOB modeling**: when a user enters a single dose with a configured DIA, the only IOB shape that matches user intuition is "decay from `starts` to zero at `starts + DIA`." Continuous-infusion segmentation is correct for pump-style logs but incorrect for once-a-day injections — and the audience determines the default.
- **Pump support** if it's added later: the right way to model pump basal is many short separate entries (one per pump tick), not one long entry. Each short entry decays as a point dose, and the sum approximates continuous infusion with correct DIA tail.

## Related

- `Library/Content/IOBCalculator.swift` — `computeIOB` after the simplification
- `DOSBTSTests/IOBCalculatorTests.swift` — `basalDecay`, `basalFadesAtDIA`, `zeroDurationBasal`
- `App/Views/AddViews/AddInsulinView.swift` — correction-bolus stacking warning that informed scoping (was using `result.total`, switched to `result.mealSnackIOB` so basal doesn't pad the warning)

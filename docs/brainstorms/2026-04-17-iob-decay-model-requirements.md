---
date: 2026-04-17
topic: iob-decay-model
---

# Insulin-on-Board (IOB) Decay Model

## Problem Frame

DOSBTS tracks insulin deliveries (bolus + basal) but has no concept of *active* insulin over time. Without IOB:
- Correction boluses get stacked on top of still-active insulin, risking hypoglycemia
- Dosing decisions lack critical context — glucose may be high but falling fast because prior insulin is still working
- The treatment workflow and AI suggestions can't factor in active insulin

IOB is the single highest-leverage addition: it makes the hero display, chart, stacking decisions, and future features (meal impact, dose suggestions) all smarter.

## Requirements

**Decay Model**
- R1. Calculate IOB using an exponential decay curve (physiologically accurate insulin action profile peaking at ~60-90 min, then trailing off)
- R2. Configurable Duration of Insulin Action (DIA) with separate settings for bolus DIA (default 4 hours) and basal DIA (default 4 hours). Settings UI with range 2.0-8.0 hours each, step granularity 30 minutes, stored as Double (hours). Bolus DIA applies to meal, snack, and correction boluses. Basal DIA applies to basal entries
- R3. Include ALL insulin types in IOB calculation: meal bolus, snack bolus, correction bolus, and basal
- R4. IOB is a computed-on-read value: calculate from delivery timestamps + current time on every access. Always fresh, no cached state to manage. IOB also recalculates on `.addSensorGlucose` to update the hero display
- R4a. IOB calculation requires a separate query for deliveries within the DIA window relative to *now* — the existing `insulinDeliveryValues` is day-scoped and cannot be reused for IOB

**Hero Display**
- R5. Show IOB on the hero glucose screen, on the same line as the unit label (e.g., `mg/dL · IOB 2.4U`). When a connection/sensor warning is active and the unit label is suppressed, IOB appears on a separate row below the warning banner. When `latestSensorGlucose` is nil ("No Data" state), IOB still appears below "No Data" if IOB > 0
- R6. Settings toggle to switch between total IOB (`IOB 2.4U`) and split display (`IOB 1.8U meal · 0.6U basal+corr`). Split separates meal+snack from correction+basal
- R7. When IOB is 0 (no active insulin), hide the IOB label entirely — don't show "IOB 0.0U"

**Chart Visualization**
- R8. Show IOB decay as a filled area on a secondary Y-axis below the glucose line. iOS 16+ only — iOS 15 does not show IOB on the chart (hero IOB display is sufficient)
- R9. When split display is enabled (R6 toggle), chart shows two colored areas for meal/snack IOB vs correction/basal IOB
- R10. IOB chart area uses the same time window as the glucose chart (scrolls together)

**Stacking Warning**
- R11. When `insulinType == .correctionBolus` (whether selected at open or changed via the picker) and IOB > 0, display a warning showing the current IOB amount. The warning appears and disappears reactively as the picker changes
- R12. Warning is informational only — the user can still proceed with the bolus. No blocking confirmation
- R13. Warning appears inline in AddInsulinView, not as a modal or alert. IOB value is passed into AddInsulinView as a parameter (e.g., `currentIOB: Double?`) to keep the view's existing callback-only contract

**Treatment Integration**
- R14. Show current IOB on TreatmentBannerView during an active treatment cycle. Knowing active insulin during a hypo is safety-critical context

## Success Criteria

- IOB value on hero screen is always fresh (computed on read) and decays over DIA window
- Stacking warning appears reliably when selecting correction bolus type with active insulin
- Chart decay curve visually matches the exponential model (peak, then long tail) on iOS 16+
- Split toggle correctly separates meal/snack from correction/basal in both hero and chart
- IOB reaches 0 and disappears from hero within DIA hours after last bolus
- IOB is visible on treatment banner during active hypo treatment cycle
- Deleting an insulin delivery immediately updates IOB (recomputed on next access)

## Scope Boundaries

- No dose calculator or dose suggestions (IOB is informational, not prescriptive)
- No deep treatment workflow integration beyond IOB display on banner (no IOB-aware alarm logic or treatment decisions)
- No integration with AI food analysis in V1
- No IOB notifications or alarms
- No pump integration — all insulin is manually logged
- iOS 15: no IOB chart visualization (hero display only)
- Stacking warning is for correction bolus only in V1 (meal bolus stacking is acknowledged but deferred)

## Key Decisions

- **Exponential decay over linear**: More physiologically accurate, matches Loop/OpenAPS models. Implementation effort difference is minimal (different formula, same infrastructure)
- **All insulin types included**: Insulin is insulin regardless of why it was taken. Including basal gives a complete picture even though manual basal logging is imprecise
- **Separate bolus/basal DIA**: Rapid-acting and longer-acting insulin have materially different profiles. Two DIA settings prevent systematic over/under-estimation
- **Computed on read, not cached**: IOB decays continuously — a cached value would be stale between sensor readings. Computing from timestamps on each access is always accurate
- **Split display as toggle, not default**: Total IOB is the simpler mental model. Split is opt-in for users who want more granularity
- **Warn on any IOB > 0**: Conservative approach for stacking. No threshold — even small residual IOB is worth surfacing when adding a correction
- **Hero placement beside unit label**: Subtle and always-visible without adding vertical space or cluttering the hero area. Falls back to separate row when warning banner is active
- **IOB on treatment banner**: Low-effort, high safety value — active insulin context during a hypo is critical for decision-making

## Dependencies / Assumptions

- Insulin delivery timestamps are accurate enough for decay calculation (user enters time manually)
- Basal entries have meaningful start/end times for decay calculation
- DIA is split into two settings: bolus DIA and basal DIA (not per individual insulin type beyond this)
- IOB is recomputed from stored deliveries on app launch (no persisted IOB value needed)

## Outstanding Questions

### Deferred to Planning
- [Affects R1][Needs research] Which specific exponential decay formula to use — Walsh curves, Fiasp-adjusted, or OpenAPS oref0 model?
- [Affects R3][Technical] How to handle basal decay — continuous infusion model vs treating each basal entry as a bolus at its midpoint
- [Affects R8][Technical] How to implement a secondary Y-axis in Swift Charts (iOS 16+)
- [Affects R9][Technical] Which AmberTheme color tokens to use for the two IOB chart areas (meal/snack vs correction/basal)
- [Affects R2][Technical] DIA settings control type (Stepper vs Slider vs Picker) — follow existing settings patterns

## Next Steps

-> `/ce:plan` for structured implementation planning

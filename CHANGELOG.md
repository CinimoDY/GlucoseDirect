# Changelog

All notable changes to DOSBTS since forking from [GlucoseDirect](https://github.com/creepymonster/GlucoseDirectApp) on 2026-02-28.

Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions below correspond to `CURRENT_PROJECT_VERSION` (TestFlight build numbers), since DOSBTS has not cut a semver release yet.

## [Unreleased]

## [Build 75] — 2026-04-25

### Changed
- TIME IN RANGE tab on the Overview chart redesigned. Hero `TIR%` number large + colour-coded by clinical thresholds (≥70% green, ≥50% amber, otherwise red). Single horizontal stacked TBR/TIR/TAR distribution bar replaces the three separate bars. Three-up numeric breakdown below ("BELOW · IN RANGE · ABOVE"). Target range and days-covered footer.
- STATISTICS tab on the Overview chart redesigned. Hero AVG glucose with unit. 2×2 grid of stat cards: GMI (with "≈ A1C" hint), TIR (with on-target / close / off-target hint, colour-coded), SD (with unit), CV (with "Stable" / "Variable" hint, colour-coded against the 33% clinical threshold). Footer shows readings count + days covered.

## [Build 74] — 2026-04-25

### Changed
- Custom `AppleIcon` now used everywhere previously rendered Apple Inc.'s `apple.logo` SF Symbol: sticky [MEAL] action button, Lists tab → Meals header, Food photo analysis section header, Meal-from-photo result-edit section header, and the home-screen widget's last-meal row. `QuickActionButton` was generalised to accept a `@ViewBuilder icon` closure so callers can pass any icon view (SF Symbol, custom shape, composite). No more Apple Inc. logo anywhere user-facing.

## [Build 73] — 2026-04-25

### Added
- Custom `AppleIcon` (Path-based fruit silhouette with leaf) replaces Apple Inc.'s `apple.logo` SF Symbol for chart markers, the read-overlay row icon, and the combined-edit modal's FOOD section header. Distinct visual, no App Store identity-guidelines risk. Sticky [MEAL] action button + iOS Form `Label`s still use `apple.logo` for now (less prominent surfaces; harder to swap without a Label refactor).
- `CombinedFoodInsulinIcon` — a single statically-composed visual (apple bottom-left + syringe top-right) used for chart-marker batches that mix food + insulin entries.

### Changed
- Chart marker batches now show **one icon per batch type** with a circular border indicating multi-entry, instead of stacked icons + count badge:
  - 1 meal → bare apple icon
  - 2+ meals → apple icon + green circle border
  - 1 insulin → bare syringe icon
  - 2+ insulin → syringe icon + amber circle border
  - Mixed food + insulin (any count) → CombinedFoodInsulinIcon + amber border (or bare if both counts are 1)
  88×48pt touch target preserved.
- Bolus IOB area mark opacity bumped from 0.45 → 0.7. The warm-green bottom layer is now clearly readable underneath the cool-green basal+correction layer.
- Read overlay opens as a half-screen sheet (`.presentationDetents([.medium, .large])` with a visible drag indicator) instead of a full-screen modal. Combined edit modal is also half-screen by default, can be dragged up to full.
- Read overlay's "Edit" affordance is now lowercase text-only ("edit") — drops the pencil glyph.

## [Build 72] — 2026-04-25

### Changed
- Split-IOB colors changed: bolus (meal/snack) is now warm green (#8CBF40, yellow-leaning), basal+correction is cool green (#40B38C, blue-leaning). Both clearly green so they read as "two flavours of IOB" but distinguishable at a glance. Replaces the previous brown amber-dark for basal which was nearly invisible against the dark chart background.
- Removed the IOB legend chips from the chart header — the warm/cool green split is self-explanatory and the labels added clutter for nothing. HR legend chip kept since magenta-on-amber-chart isn't obvious without it.

## [Build 71] — 2026-04-25

### Changed
- Split IOB area marks now stack instead of overlapping. Meal/snack IOB (cyan) sits at the bottom, basal/correction IOB (amber-dark) stacks above it, so total area at any point equals the running total IOB and you can read both components at a glance.
- Chart legend chips for IOB and HR overlay components — small swatch + label pairs in the chart header row (e.g. `MEAL/SNACK` cyan + `BASAL/CORR` amber when split IOB is on). Color-to-component mapping is now visible without remembering which is which.
- Chart toolbar split into two consistent strips with matching font + underline treatment: report-type tabs (GLUCOSE / TIME IN RANGE / STATISTICS) above the chart, time-range / day-window tabs (3h…24h or 7d…ALL) **below** the chart. Both rows are now the same visual size — previously the zoom row was a notch smaller than the report-type row.
- Marker-lane position picker in Settings → Additional gets a label and a one-line description ("Where the meal/insulin/exercise icons sit relative to the glucose chart") so it's clear what the segmented control does.

## [Build 70] — 2026-04-25

### Changed
- `AddInsulinView` rebuilt to match the original brainstorm mockup. Drops iOS `Form`/`Section` (which was rendering gray rounded card backgrounds that broke the CGA aesthetic). New layout: flat black background, custom nav bar (Cancel · ADD INSULIN · Add), all-caps amber-dim form labels, full-width chips, big 56pt-tall stepper with separated value/unit display, IOB warning gets its own bordered amber-tint card.
- `AmberChip` selected state is now solid amber background + black semibold text (was: barely-visible 8%-opacity tint that disappeared against the dark background). Type chips are 44pt tall, preset chips 40pt; both fill available width.
- `StepperField` redesigned: 56pt tall body, 60pt-wide tinted +/- buttons, 24pt amber value with separate dimmed unit suffix (e.g. `4.5` + `U`). Optional caption underneath ("tap value to type · ±0.5U steps"). Tap-to-type still works.
- Meal/carbs icon swapped from `fork.knife` to `apple.logo` everywhere: chart markers, sticky [MEAL] action button, food-photo / meal-entry section headers, meals list tab, home-screen widget last-meal row.

## [Build 69] — 2026-04-25

### Added
- Unified marker → read overlay → edit flow (DMNC-848). Tapping any chart marker opens a Libre-style list overlay with chronological rows showing IN PROGRESS state, post-meal delta (mg/dL or mmol/L per user setting), confounder icons, PersonalFood glycemic average + observation count, and IOB-at-dose-time. Edit opens a single combined modal with shared time and edit-only semantics; both meal and insulin updates use id-preserving constructors and route through GRDB load-after-write so the chart re-renders cleanly.
- `AmberChip`, `StepperField`, `QuickTimeChips` design-system primitives for chip rows, numeric steppers, and quick-time selectors used in the redesigned insulin entry surface and combined edit modal.
- `StagingPlateRowView` extraction shared between `FoodPhotoAnalysisView` and the new `CombinedEntryEditView` — single ratio-link auto-scale + manual override implementation.
- End-of-line numeric BPM readout on the heart-rate chart overlay (when enabled and HR data is fresh within the last 10 minutes). DMNC-848 D6.
- Chart customisation: marker lane position toggle in Settings → Additional settings (above or below the glucose chart). Default is "above" — no change for existing users unless they opt into below. DMNC-848 D7.

### Changed
- `AddInsulinView` replaces the type `Picker` with an `AmberChip` row, the units `TextField` with a `StepperField`, and the time `DatePicker` with `QuickTimeChips` (NOW / −15m / −30m / −1h plus a `⋯` chip opening a custom DatePicker popover). Basal entries still show an `Ends` `DatePicker`. The IOB stacking warning for correction boluses is preserved.
- Chart marker visual: bare type-coloured icons (22pt) replace the bordered chips with text labels. Cross-type clusters consolidate with stacked icons (max 3) and a count badge in the dominant type's colour. Marker lane height bumped from 32pt to 48pt to honour the larger touch target.
- Insulin marker tap no longer shows a bare `confirmationDialog` with a Delete option. Delete now requires opening Edit; the read-overlay surface keeps the action gesture light.
- Heart-rate overlay on the glucose chart is now toggleable (Settings → Apple Health import → "HR overlay on chart"). Default is **off** to give users explicit control. Builds ≤ 62 rendered the magenta HR line whenever HealthKit import was active; users who want that back must enable the toggle. DMNC-848 D6.

## [Build 68] — 2026-04-24

### Changed
- App icon is now a CGM-sensor take on the eiDotter yolk: concentric amber disc / active-scan ring / central filament dome mirroring the brand's three-stop amber palette, with cardinal tick marks and symmetric transmission arcs reading as wireless emissions. Replaces the insulin-pen-and-drop placeholder. Source in `scripts/app-icon.svg` and `scripts/render-app-icon.py`; derived sizes via `scripts/resize-icon.sh`.

## [Build 67] — 2026-04-24

### Fixed
- Home-screen glucose widget stayed stale when the app was backgrounded. `WidgetCenter.reloadAllTimelines()` was only wired into `.setAppState(.active)` (scene-becomes-foreground) and `ContentView.onChange(of: latestSensorGlucose)` (which doesn't fire while the scene is backgrounded). New sensor readings arriving via the background BLE path never refreshed the widget until the widget's own 15-minute scheduled tick or the user reopened the app. Widget now reloads on every `.addSensorGlucose` from the middleware so it refreshes regardless of scene state.

## [Build 66] — 2026-04-24

### Added
- Thin 4px horizontal progress bar under the M:SS countdown text on the hypo-treatment banner, filling left-to-right over the configured wait duration. Gives a continuous visual cue of remaining recheck time without making you read the timer — DMNC-771, PR #39.

### Changed
- Settings → About gains a **Disclaimer** section clarifying DOSBTS is a community reader app, not a medical device, and that treatment decisions must be verified with the CGM manufacturer's reader and a clinician. Adds a **Build date** row (read from the binary's modification time) and a **Forked from** row linking to upstream GlucoseDirect — PR #38.

## [Build 65] — 2026-04-24

### Added
- Settings → **Connections** screen consolidates Nightscout, Apple Health & Calendar export, AI Features, and Health Import Sources into one indexed view with per-integration status dots (green = active / grey = inactive / red = needs configuration). Each row drills into the existing settings surface for that integration. Individual rows remain available in the main Settings list — DMNC-810, PR #35.
- **Usage** section on the Statistics screen (Lists tab) — views-per-day average, total views since tracking began, and sensor uptime % over the currently-selected window. Lets you spot over/undercheck patterns and data-quality gaps at a glance — DMNC-811, PR #36.

## [Build 64] — 2026-04-24

### Changed
- Red "Disconnected" warning chip under the hero glucose value and the sensor-line CONNECT chip now open a confirmation dialog with two reconnect options — Connect (BLE) for a fast reconnect to the paired session, or Scan Sensor (NFC) for a full re-scan (new sensor, expired session, transmitter reset) — DMNC-808, PR #27.
- Overview chart zoom picker is now tab-aware. GLUCOSE tab keeps `3h / 6h / 12h / 24h`; TIME IN RANGE and STATISTICS tabs show `7d / 30d / 90d / ALL`. The stats aggregation window updates on selection so TIR / AVG / SD / GMI reflect the picked range. Persisted per-tab via the existing state — DMNC-806, PR #28.
- Favourite chips in the `> QUICK` row now have a bounded width (~120pt) so a long barcode-scanned name can't dominate the row and short labels no longer get clipped by horizontal scroll. Long text truncates with `…`. Favourites gain an optional **Short label** field (editable from the favourite edit sheet) that renders on the chip in place of the full description when set. Existing favourites without a short label keep rendering as today — DMNC-804, PR #29.

## [Build 63] — 2026-04-24

### Changed
- Overview screen is now a fixed no-scroll layout. Chart toolbar (GLUCOSE / TIME IN RANGE / STATISTICS and 3h / 6h / 12h / 24h) pinned above the chart with an underline-on-selected treatment; sensor connection status moved inline under the hero with tap-to-reveal disconnect; sticky actions trimmed to INSULIN + MEAL (BG entry moved to the Log tab with a one-shot relocation alert on first launch). Full sensor / transmitter detail surface moved into Settings → Sensor details — DMNC-793, PR #26.

## [Build 62] — 2026-04-22

### Fixed
- Chart rendered blank on scene-restoration cold launches. `UIScreen` extension now walks `UIApplication.connectedScenes` (iOS 26 replacement for deprecated `UIScreen.main`), and `ChartView.screenWidth` clamps to `max(0, …)` so a pre-scene 0 width can't cache a negative value into the chart's `@State` — DMNC-780, PR #25.

## [Build 61] — 2026-04-22

### Added
- Changelog, README rewrite, and LICENSE fork attribution — PR #22
- GitHub Sponsors link for DOSBTS-specific support, alongside the upstream donate link — PR #22

### Changed
- Xcode project migrated to `fileSystemSynchronized` groups — new Swift files under `App/`, `Library/`, `Widgets/` are auto-picked up (`pbxproj` went from 2,055 → 750 lines) — DMNC-768, PR #21
- iOS deployment target bumped from 15.0/16.0 → 26.0 across all targets — DMNC-769, PR #19
- SettingsView: inter-group breathing room between setting groups — DMNC-770, PR #20

### Removed
- Facebook group and Crowdin rows from Settings → About — PR #22

## [Build 60] — 2026-04-20

### Added
- Widget phosphor display rework (expanded data: sparkline, IOB, TIR, last meal) — PR #18

## [Build 59] — 2026-04-20

### Added
- **Daily Digest tab** (4th tab) with per-day stats grid, AI-generated insight (Claude Haiku), and chronological event timeline. Requires separate `aiConsentDailyDigest` toggle. — DMNC-579, PR #17

### Fixed
- GRDB deadlock: moved write outside `asyncRead` to prevent queue starvation
- Double-resume crash in Combine Future → async bridge

## [Build 55] — 2026-04-21

### Added
- **Meal impact overlay** — tap a meal marker to see 2-hour post-meal glucose delta, confounder detection (correction bolus / exercise / stacked meal), and PersonalFood rolling glycemic score. Dual-trigger computation (retroactive on app activation + real-time on new readings). — DMNC-688, PR #14
- **Libre-style event marker lane** above the glucose chart with SF Symbol icons (fork.knife, syringe.fill, figure.run) and zoom-dependent consolidation. — DMNC-635, PR #16
- Refactoring UI polish: warm greys, marker lane depth, stats hierarchy

### Fixed
- Backport cleanup from DOOMBTS: Y-axis trailing, HR legend header, haptic feedback — DMNC-714

## [Build 54] — 2026-04-18 ("IOB release")

### Added
- **Insulin-on-Board (IOB)** — OpenAPS oref0 Maksimovic exponential decay model with `InsulinPreset` enum (rapid-acting peak 75m / DIA 6h, ultra-rapid peak 55m / DIA 6h). Hero display with 60s refresh, split display toggle, chart AreaMark overlay (iOS 16+), stacking warning in AddInsulinView, InsulinSettingsView. — PR #13

## [Build 53] — 2026-04-17

### Added
- **Stale data indicator** on hero glucose — "X MIN AGO" warning (amber 5–14 min, red 15+) to prevent dosing decisions on silently stale data

## [Build 52] — 2026-04-17

### Added
- **XCTest target** with initial reducer snapshot tests (later expanded to 137 tests)

## [Build 51] — 2026-04-17

### Added
- **Predictive low alarm** — 20-min forward extrapolation of glucose trajectory using smoothed minuteChange. Fires "Trending Low" notification with "EAT NOW" UNNotificationAction. Chart shows dashed projection line (iOS 16+) with red cross marker at predicted threshold crossing. Toggle: `showPredictiveLowAlarm`.

## [Build 50] — 2026-04-17

### Added
- Chart markers: bigger markers, delete buttons on meal/insulin markers, grouped entries (15-min timegroup → circle with count + total carbs)

## [Build 49] — 2026-04-17

### Added
- **Guided hypo treatment workflow** ("Rule of 15") — alarm → `.showTreatmentPrompt` → user logs 15g carbs → 15-min countdown → recheck → stabilised or treat again. Background-safe via UNNotificationAction buttons + foreground TreatmentModalView. Alarm suppression during countdown with critical-low safety floor (`alarmLow - 15 mg/dL` breaks through). Configurable wait time (`hypoTreatmentWaitMinutes`, default 15). TreatmentEvent persisted to GRDB.

## [Build 35–48] — 2026-04-08 → 2026-04-15

### Changed
- **Libre-inspired layout overhaul** — hero glucose → treatment banner (if active) → chart → action buttons → connection → sensor. Matches standard CGM app flow.
- **Sticky action buttons** + compact hero/chart layout
- **Sensor disc app icon**
- **Gradient glucose color** — green in range, amber high, red danger
- **ActiveSheet enum** — all sheets consolidated into a single `.sheet(item:)` with discriminator (fixes iOS sibling sheet collisions)

## [Build 29–34] — 2026-04-03 → 2026-04-08

### Added
- **Staging plate UX** — amount editing + inline barcode — DMNC-567
- **Portion presets & smart quantities** — DMNC-562
- **Conversational follow-up** for food clarification — DMNC-560
- **Barcode scanning** via Open Food Facts (free, no AI consent required) — DMNC-561
- **Natural-language food parsing** via Claude — DMNC-558

## [Build 24–28] — 2026-03-22 → 2026-04-03

### Added
- **Editable AI results** with staging plate + learning from corrections (PersonalFood glycemic database)
- **Log again swipe** + add to favorites context menu
- **Favorites management** — reorder, edit, delete

## [Build 21–23] — 2026-03-15 → 2026-03-22

### Added
- **Unified food entry view** with favorites, recents, and search — PR #1
- **FavoriteFood model**, middleware, Redux wiring
- Quick re-logging workflow

## [Build 16–20] — 2026-03-10 → 2026-03-15

### Added
- **Thumb calibration** for portion sizing, sensor button layout — DMNC-527, DMNC-456
- Combined MANUAL/PHOTO buttons aligned with INSULIN
- Grouped meal buttons under LOG FOOD label

### Fixed
- Middleware race condition, automatic signing (build 15)

## [Build 2–15] — 2026-02-28 → 2026-03-09

### Added
- **DOSBTS rebrand** — bundle identity, signing, app name
- **eiDotter CGA amber design system** — Phase 1 (tokens moved to Library, components added), Phase 2 (all views migrated to AmberTheme + DOSTypography), Phase 3 (legacy Color.swift removed)
- **Phosphor glow** matched to glucose alarm state
- **CRT scanline overlay** (optional)
- **UI overhaul** — restructured navigation, quick actions, CRT effects
- **AI food analysis** — photo analysis via Claude with full nutrition breakdown, HealthKit export
- **Insulin** — initial insulin stores, HealthKit export, Nightscout upload
- **Food logging MVP** — meal entries, chart markers, manual logging
- **HealthKit import** — nutrition, exercise, heart rate

---

## Pre-fork

Everything before 2026-02-28 is upstream [GlucoseDirect](https://github.com/creepymonster/GlucoseDirectApp) by Reimar Metzen — the foundational work on Libre 1/2/3 sensor connections, LibreLinkUp integration, Bubble transmitter support, calibration math, Nightscout upload, Apple Watch calendar export, HealthKit export, and the Redux-like architecture. DOSBTS inherits all of it under MIT.

See the [upstream repository](https://github.com/creepymonster/GlucoseDirectApp) for the pre-fork history.

# Changelog

All notable changes to DOSBTS since forking from [GlucoseDirect](https://github.com/creepymonster/GlucoseDirectApp) on 2026-02-28.

Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions below correspond to `CURRENT_PROJECT_VERSION` (TestFlight build numbers), since DOSBTS has not cut a semver release yet.

## [Unreleased]

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

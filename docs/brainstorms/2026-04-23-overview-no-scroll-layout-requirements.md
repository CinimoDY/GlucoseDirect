# Overview no-scroll layout — chart toolbar, sensor line, sticky actions

**Issue:** [DMNC-793](https://linear.app/lizomorf/issue/DMNC-793)
**Scope:** One cohesive change to the main Overview screen — layout conversion (`List` → `VStack`), new chart toolbar treatment, new sensor status line under the hero with progressive-disclosure disconnect, sticky actions trimmed to two, BG entry rehomed to the Log tab.
**Related:** DMNC-796 (marker-lane unified interactions) will adopt the chip vocabulary DMNC-798 (AmberChip) ships. This spec uses AmberChip where it can, an inline underline treatment where it can't, and documents the identity trade-off honestly below.
**Codesign source:** `.devjournal/sessions/dmnc-793-codesign-2026-04-23/L2-thematic/screens/` — nine screens walking through the decision journey; `screens/README.md` captions each.

**Revision note:** Drafted + committed, then revised in response to a six-persona document-review pass that surfaced structural implementability gaps (Section-wrapping in ChartView, missing NavigationStack in SettingsView/ListsView, transmitter-detail routing, sensor-line transient states) plus premise corrections (widgets likely outrank the Overview in daily-view volume; "chart controls disappear" is author-observed structural coherence, not a reported UX complaint; underline selection is a departure from CGA aesthetic, not a match for it). The revision also collapses the two-PR split into one PR because the split's stated mitigation ("temporary hidden sensor route") was vaporware.

---

## Context

DOSBTS entry surfaces have grown feature-by-feature. The OverviewView today (build 62) wraps everything in a scrolling `List`: chart controls scroll away with the chart, sensor status + lifetime sits below the chart in two separate views (`ConnectionView` 167 LOC + `SensorView` 203 LOC), and the sticky action row has three buttons (INSULIN / MEAL / BG).

Two pressures drive this spec — both internal-facing and honestly named:

1. **Structural coherence.** The current `List` wrapper forces region-by-region state management through `Section` containers; pulling any region out for independent pinning or restyling fights the List API. Converting to a fixed-region `VStack` is a precondition for upcoming chip-vocabulary work (DMNC-796 marker-lane expansion) and for any attempt to pin chart controls above a scrolling chart.
2. **Forward-looking code reuse.** DMNC-796 and DMNC-798 (AmberChip primitive) will both need the Overview to compose chip-shaped and non-chip-shaped primitives side by side. Establishing the structural seams now avoids re-doing this layer after AmberChip lands.

**What this spec is not motivated by:** a user-reported complaint that toolbar controls vanish on chart scroll. There is no TestFlight thread, PostHog signal, or direct user report cited. The disappearance is a structural symptom; pinning the toolbar is a side-effect of converting to fixed regions, not the primary goal. The spec-level "most-viewed screen" claim in earlier drafts was qualified after review: the Overview is the most-viewed *in-app* surface, but lock-screen widgets + Live Activity + home-screen widgets likely account for the majority of user glucose-glance events.

## Target composition

Seven fixed regions, top to bottom, no vertical scroll on iPhone 17 Pro steady-state. The chart's horizontal history scroll remains. iPhone SE + Dynamic Type behaviour is explicitly verified before PR ship (see Success criteria #8).

```
┌─────────────────────────────────────┐
│ ①  GlucoseView (hero)               │
├─────────────────────────────────────┤
│ ②  Sensor line (state-aware)        │
├─────────────────────────────────────┤
│ ③  Treatment banner (conditional)   │
├─────────────────────────────────────┤
│ ④  Chart toolbar                    │
│      report-type row + zoom row     │
├─────────────────────────────────────┤
│ ⑤  Chart (fills remaining space,    │
│    horizontal scroll only; empty    │
│    state rendered when no data)     │
├─────────────────────────────────────┤
│ ⑥  StickyQuickActions (2 buttons)   │
│    [ INSULIN ]   [ MEAL ]           │
├─────────────────────────────────────┤
│ ⑦  iOS TabBar (ContentView.swift)   │
└─────────────────────────────────────┘
```

## Decisions

### Chart toolbar — underline-on-selected

Replaces the current `ReportTypeSelectorView` (`ChartView.swift:356-378`) with a two-row underline tab bar. **Honest identity note:** underline selection is a web/iOS convention, not a CGA-era DOS-TUI pattern. Classic DOS TUIs used bright-background inverse fills or bracket marks; DOOMBTS's sibling `WeaponSelectorBar` uses amber-dark background fill at 40% opacity. The underline treatment here is a deliberate departure that optimises for ambient/metadata recession (letting the chart + future chip rows carry visual prominence) rather than for aesthetic fidelity. The trade-off is acknowledged; reconsidered options are in § Open questions below.

**Visual states:**

| | Unselected | Selected |
|---|---|---|
| Text colour | `AmberTheme.amberDark` | `AmberTheme.amber` |
| Decoration | none | 2pt bottom overlay in `AmberTheme.amber`, width = text width |
| Background | transparent | transparent |
| Font | `DOSTypography.bodySmall` (15pt) | same, bold weight |
| Vertical padding | `DOSSpacing.md` (16pt) top + bottom — hits 47pt total, above HIG 44pt minimum tap target | same |

**State hoist for the toolbar to work at Overview scope:**

- `ReportType` enum (currently private at `ChartView.swift:13-17`) is lifted to a file-level enum in a new `App/Views/Overview/ChartToolbar.swift`.
- `selectedReportType` moves from `@State private var` inside `ChartView` to `@State` at `OverviewView` scope, passed into both the extracted `ChartToolbarView` (via `@Binding`) and the existing `ChartView` body (via value parameter so `ChartView` can render the right sub-view).
- Zoom level already lives in Redux (`store.state.chartZoomLevel`, `ChartView.swift:487`); `ChartToolbarView` dispatches `.setChartZoomLevel` directly via `@EnvironmentObject var store: DirectStore`.

**Section-wrapping structural note:** `ChartView.body` is currently `Section { VStack { ReportTypeSelectorView; switch ... } }` at `ChartView.swift:26-42`. `Section` only renders inside `List` or `Form` — converting to `VStack(spacing: 0)` at the Overview level requires unwrapping the `Section` in `ChartView` first. Same applies to `ConnectionView.swift:17` and `SensorView.swift:16,96,133`; those two files are being replaced entirely so the wrappers go with them.

**Animation for DMNC-797.** The "slide the underline from tab to tab" animation implied by DMNC-797 micro-interactions requires either `matchedGeometryEffect` across tabs or a single parent-level overlay driven by a `PreferenceKey` tab-frame measurement. The per-button `.overlay` treatment specified for PR 1 gives fade-on-selection, not slide. Noted so DMNC-797 plans the refactor.

### Sensor line — state-aware compact status row

Sits directly under the hero. Matches the existing DOOMBTS `SensorInfoBar` semantic (dot colour + uppercase label + lifetime-or-state suffix) but with DOSBTS's tap-to-reveal disconnect pattern layered on top for destructive safety.

**Complete state table** — resolves the transient-state gap the design-lens review surfaced:

| Source condition | Dot | Label | Trailing element |
|---|---|---|---|
| `connectionState == .connected` AND `sensor.state == .ready` | `cgaGreen` | `CONNECTED` | `· Nd LEFT` (via `sensor.remainingLifetime.inTime`) — last 24h formats as `· Xh LEFT` in `amberLight`; last 1h as red |
| `connectionState == .connected` AND `sensor.state == .starting` | `amberLight` | `WARMUP` | `· Mm LEFT` (via `sensor.remainingWarmupTime.inTime`) — mirrors DOOMBTS `SensorInfoBar:258-262` |
| `connectionState == .connecting` | `amberLight` (pulsing opacity 0.4→1.0, 1s) | `CONNECTING…` | none |
| `connectionState == .scanning` | `amberLight` (pulsing) | `SCANNING…` | none |
| `connectionState == .pairing` | `amberLight` (pulsing) | `PAIRING…` | none |
| `connectionState == .disconnected` AND `hasSelectedConnection == true` | `amberDark` | `DISCONNECTED` | `[ CONNECT ]` chip always visible — 1-tap dispatches `.connectConnection` |
| `hasSelectedConnection == false` (no connection type ever chosen) | `amberDark` | `NO SENSOR` | `[ SET UP ]` chip → routes to the Settings tab → Sensor section (open pairing flow) |
| `connectionError != nil` | `cgaRed` | `CONNECTION ERROR` | tap line → routes to Settings tab → Sensor section for the error detail + troubleshooting link |
| `connectionState == .powerOff` | `cgaRed` | `BLUETOOTH OFF` | tap line → opens iOS Settings via `UIApplication.openURL` to the Bluetooth pane |
| `connectionState == .unknown` (fallback) | `amberDark` | `—` | none |

**Interaction for the `connected` state (the safety-proofed path):**

- Tap on the status line → reveals a `DISCONNECT` chip in the trailing element position. The chip uses plain text + amber border (will adopt `AmberChip` when DMNC-798 ships; sweep commit noted).
- Tap on the `DISCONNECT` chip → existing destructive alert (pattern lifted from the current `ConnectionView`; migrate to iOS 15+ `.alert(_:isPresented:actions:message:)` form at the same time).
- **Dismiss via elsewhere-tap, not via timer.** Tap anywhere outside the sensor-line view clears the revealed chip. No auto-hide timer. This change from the first-draft 5-second timer removes a new `Task.sleep` surface, eliminates the VoiceOver-race concern, and avoids the "wait, where did it go?" UX. Simpler. If usage shows users want an auto-timer, DMNC-797 can add one with accessibility considerations properly in scope.
- **Auto-cancel on view teardown** via `.onDisappear` resetting the reveal bool. State machine: `@State private var disconnectChipRevealed: Bool = false` at the SensorLineView root.

### Sticky actions — two buttons (INSULIN + MEAL)

`StickyQuickActions` in `OverviewView.swift:156-189` is trimmed from three buttons to two. `DirectConfig.showInsulinInput` gate on INSULIN is preserved. `DirectConfig.bloodGlucoseInput` gate moves with the BG feature to the Log tab (below).

**Single-button edge case** (both reviews flagged this): if `DirectConfig.showInsulinInput == false` AND BG moves away, only MEAL remains. In that case, MEAL centers at a max width of `UIScreen.main.bounds.width / 2` rather than stretching full-width — preserves the two-button visual rhythm even when only one button is active. The current `.frame(maxWidth: .infinity)` pattern is replaced with explicit fractional sizing.

### BG entry — moves to Log tab, IN PR 1 not PR 2

Today's only BG entry path is the Overview sticky action (`OverviewView.swift:177-184`). Removing that in PR 1 without shipping the Log-tab replacement *in the same PR* strands users: they have `DirectConfig.bloodGlucoseInput` enabled, they need to calibrate with a fingerstick, and there is no entry point. Multiple reviewers flagged this as a regression-window risk that the original two-PR split explicitly creates.

**Fix:** BG entry moves to the Log tab **in PR 1**, not deferred to PR 2. Concrete approach: `ListsView` gets wrapped in a `NavigationStack` (needed anyway for the SensorDetailView flow in PR 2 and for the BG trailing toolbar `+`). The trailing `+` button presents `AddBloodGlucoseView` via `.sheet(isPresented:)` local to `ListsView`, gated on `DirectConfig.bloodGlucoseInput`. Same sheet content, same dispatch — just a new presenter.

**Discoverability migration note:** first launch after the upgrading to this PR shows a one-shot `.alert`-style hint ("BG entry is now in the Log tab"). Persisted via a new `hasSeenBGRelocationHint: Bool = false` on AppState (UserDefaults-backed, cleared by default). Alternative: a short in-app toast on Overview for the first three app opens. Pick one during writing-plans — either is small.

### Full sensor controls — new SensorDetailView under Settings

Everything in the current `ConnectionView.swift` beyond the compact status (pair / scan / disconnect / transmitter-specific flows) + everything in `SensorView.swift` (transmitter battery, hardware/firmware strings, MAC address, serial, sensor-type + region) moves to a new `App/Views/Settings/SensorDetailView.swift`. **Enumerated migration:**

| From | To |
|---|---|
| `ConnectionView.swift` sensor-pair + scan UI (lines 73-91) | SensorDetailView |
| `ConnectionView.swift` transmitter-pair + scan UI (lines 54-71) | SensorDetailView |
| `ConnectionView.swift` destructive-disconnect button + alert (lines 92-112, 143-153) | SensorDetailView |
| `ConnectionView.swift` connection-error Section (lines 16-41) | SensorDetailView + surfaced via the `CONNECTION ERROR` sensor-line state (above) |
| `ConnectionView.swift` connection-state Section (lines 43-54) | SensorLineView summary + SensorDetailView detail |
| `SensorView.swift` sensor lifetime + warmup (lines 18-57) | SensorLineView summary + SensorDetailView detail |
| `SensorView.swift` sensor-type / region / serial / MAC (lines 95-130) | SensorDetailView (detail-only — not in the compact line) |
| `SensorView.swift` transmitter-name / battery / hardware / firmware (lines 132-171) | SensorDetailView (detail-only — not in the compact line) |

`SensorDetailView` is routed from `SettingsView` via a `NavigationLink` row. This requires `SettingsView` to be wrapped in a `NavigationStack` — a small scaffolding change (~5 LOC) that DMNC-794 (Settings IA redesign) is on the hook for anyway.

### What doesn't change

- `GlucoseView` (hero): unchanged.
- `TreatmentBannerView`: unchanged, slot position preserved.
- Chart itself (body below the toolbar): no content change this spec. Marker lane tweaks belong to DMNC-796.
- System `TabView` in `ContentView.swift:19-34`: unchanged.
- The `ActiveSheet` enum + sheet orchestration: unchanged in OverviewView (one case removed — `.bloodGlucose` migrates to `ListsView`'s local sheet state).

## File-level changes — **single PR scope**

Merging the originally-split PRs into one cohesive change. Separate PRs created more risk than they reduced: the NavigationStack scaffolding that PR 1 needs (for Log tab `+BG`) is the same scaffolding PR 2 needs (for SensorDetailView push) — splitting would mean adding NavigationStack twice, or deferring BG-move to PR 2 which strands users during the PR 1 TestFlight window.

| File | Change |
|---|---|
| `App/Views/OverviewView.swift` | Body: `List { ... }` → `VStack(spacing: 0) { ... }`. Remove `ConnectionView()`, `SensorView()` rows. Insert `SensorLineView()` under `GlucoseView()`. `ChartToolbarView` pulled out of the chart body into its own pinned region. `StickyQuickActions` trimmed to 2 buttons. Remove the `.bloodGlucose` case's sticky-action trigger (the ActiveSheet enum case stays — still used by the treatment-modal "log BG" flow). |
| `App/Views/Overview/ChartView.swift` | Unwrap outer `Section { VStack { ... } }` at body level — body becomes a plain `VStack(spacing: 0) { switch selectedReportType { ... } }`. Remove `ReportTypeSelectorView` (lines 356-378). Remove `ZoomLevelsView` (lines 477-508) — lifted into `ChartToolbarView`. Accept `selectedReportType` as a parameter (not `@State`); `chartZoomLevel` stays in Redux state as today. |
| `App/Views/Overview/ChartToolbar.swift` | **New.** Module-scope `ReportType` enum + `ChartToolbarView` struct. Two `@Binding` rows (report-type + zoom-level). Underline-on-selected styling via `.overlay(alignment: .bottom) { Rectangle().frame(height: 2) }.opacity(selected ? 1 : 0)`. 44pt vertical padding per row. |
| `App/Views/Overview/SensorLineView.swift` | **New.** State-aware compact row per the state table above. Reveal state + elsewhere-tap dismiss. Uses existing dispatch actions (`.connectConnection`, `.disconnectConnection`). |
| `App/Views/Overview/ConnectionView.swift` | **Deleted.** Logic distributed into `SensorLineView` (summary) + `SensorDetailView` (full controls). |
| `App/Views/Overview/SensorView.swift` | **Deleted.** Lifetime display into `SensorLineView`; transmitter/hw/fw/MAC/serial into `SensorDetailView`. |
| `App/Views/Settings/SensorDetailView.swift` | **New.** Pair / scan / disconnect / transmitter UI + sensor/transmitter detail fields + connection-error detail. Migrates the destructive alert to iOS 15+ `.alert(_:isPresented:actions:message:)` form. |
| `App/Views/SettingsView.swift` | Wrap in `NavigationStack`. Add `NavigationLink` row "Sensor" → `SensorDetailView`. |
| `App/Views/ListsView.swift` | Wrap in `NavigationStack`. Add trailing toolbar `+` button gated on `DirectConfig.bloodGlucoseInput`, presents `AddBloodGlucoseView` via `.sheet`. Add `AppState.hasSeenBGRelocationHint` one-shot alert (see BG-entry decision). |
| `App/AppState.swift` + `Library/Extensions/UserDefaults.swift` + `Library/DirectReducer.swift` + `Library/DirectAction.swift` | `hasSeenBGRelocationHint: Bool` — UserDefaults-backed, default false, set to true after first hint dismissal. Standard 4-file state-property pattern per CLAUDE.md. |

Estimated LOC diff: ~400 across 11 files (3 new, 2 deleted, 6 modified). The extra ~100 LOC vs the earlier "300" estimate reflects the honestly-named NavigationStack scaffolding + BG-move scope + state-hoist + transmitter-detail routing.

## Accessibility — minimum commitments for this PR

DMNC-797 owns the full accessibility pass, but these new primitives need baseline VoiceOver + Dynamic Type support on first ship (otherwise the spec fails its own users):

- **Sensor line:** `.accessibilityLabel("Sensor connected, 8 days remaining")` for the whole line (composed from state + lifetime); `.accessibilityHint("Double-tap to disconnect")` when the chip is revealed; `.accessibilityAddTraits(.isButton)` on the line itself. The colour dot is decorative (`.accessibilityHidden(true)`) — label conveys the state.
- **Toolbar underline selection:** `.accessibilityLabel("Time In Range")` + `.accessibilityAddTraits(.isSelected)` on the active tab; the underline is decorative. Standard iOS segmented-control semantics.
- **AmberChip (when adopted):** `.accessibilityLabel(label)` + `.accessibilityAddTraits(.isSelected)` conditional on `selected`.
- **Dynamic Type verification** on iPhone 17 Pro at the default size and at XXL (accessibility sizes deferred to DMNC-797). If chart region drops below 25% of screen height at XXL, the spec commits to either (a) the chart gaining vertical scroll or (b) the sensor line collapsing into the hero — pick during implementation, document in the PR.

## Success criteria

The PR is "done enough" to ship when all eight hold:

1. Overview page does not scroll vertically on iPhone 17 Pro at default Dynamic Type — with or without the treatment banner.
2. Chart toolbar (report-type + zoom) stays visible while the chart scrolls horizontally.
3. Sensor line renders correctly for every row in the state table above — state labels + dot colours + trailing elements all match.
4. Connect (from disconnected) is 1 tap. Disconnect (from connected) is 2 taps + alert confirm. Destructive alert matches the migrated iOS 15+ API form.
5. BG entry from the Log tab works identically to today's Overview-sticky entry — same sheet, same dispatch. `hasSeenBGRelocationHint` one-shot migration hint fires on first launch after upgrade and never again.
6. SensorDetailView in Settings shows pair / scan / disconnect / transmitter details + all content from the deleted `ConnectionView` + `SensorView` — **nothing is silently lost**. Grep-verification: no Swift-type reference in the deleted files is orphaned.
7. Visual snapshot tests exist for: `ChartToolbarView` (both rows, selected + unselected), `SensorLineView` (every state table row), `StickyQuickActions` (two-button, and single-button edge case), `SensorDetailView` (transmitter + sensor paths).
8. **Small-screen gate:** on iPhone SE at default Dynamic Type, either the Overview does not scroll, or the chart region gains horizontal scroll with a documented scroll-affordance indicator. PR description records which.

## Open questions — resolved 2026-04-23 post-review

All five were resolved during the review pass:

- **A · Toolbar selected-state:** underline (codesign's Option E). Aesthetic departure from CGA acknowledged in § Chart toolbar; recession benefit + lowest-effort implementation justified.
- **B · Zoom picker location:** lifted into `ChartToolbarView` (two-row toolbar). Matches screens 06/08/09. `ChartView` loses both `ReportTypeSelectorView` and `ZoomLevelsView`.
- **C · Sensor error routing:** tap anywhere on the sensor line routes to Settings → SensorDetailView silently. No inline "tap for details" hint — the red dot + `CONNECTION ERROR` label is self-explanatory and the whole row is the tap target.
- **D · BG migration hint:** one-shot `.alert` on first launch after upgrade. Persisted via `AppState.hasSeenBGRelocationHint` UserDefaults flag.
- **E · Sequencing vs DMNC-798:** ship DMNC-793 now with plain text + amber border for the disconnect chip; AmberChip sweep commits when DMNC-798 lands.

## Out-of-scope & follow-ups

**Explicitly out of scope:**

- **Full accessibility pass** (WCAG-level VoiceOver coverage, accessibility-size Dynamic Type verification, reduce-motion handling for the disconnect-chip reveal). Minimum VoiceOver + default-size Dynamic Type covered above. Full pass → DMNC-797.
- **Settings IA restructure.** This PR adds one NavigationLink row to the existing SettingsView and wraps it in NavigationStack. DMNC-794 owns any larger restructure.
- **Marker lane visual changes** — DMNC-796.
- **AmberChip adoption for the sensor-line DISCONNECT reveal** — ships as plain text + amber border; swept to AmberChip when DMNC-798 lands.
- **Widget + Live Activity** — unchanged. The sensor-line refactor doesn't touch `UserDefaults.shared` (App Group) or `SensorGlucoseActivityAttributes.ContentState`.
- **Localisation of new strings** (`WARMUP`, `CONNECTING…`, `NO SENSOR`, `BLUETOOTH OFF`, migration-hint copy) — deferred to the regular `Localizable.strings` sweep at PR-review time.

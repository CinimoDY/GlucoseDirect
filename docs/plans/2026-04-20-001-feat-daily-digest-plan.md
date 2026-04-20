---
title: "feat: Daily Digest — End-of-Day Summary with AI Insight"
type: feat
status: active
date: 2026-04-20
origin: docs/brainstorms/2026-04-19-daily-digest-requirements.md
---

# feat: Daily Digest — End-of-Day Summary with AI Insight

## Overview

Add a fourth tab (Digest) that shows a daily glucose summary with stats grid, AI-generated insight from Claude Haiku, and event timeline. Persisted to GRDB for history browsing. AI insight references past 7 days for cross-day trend spotting.

## Problem Frame

The app monitors glucose all day but never summarizes. Users must mentally reconstruct their day from the chart. The Daily Digest provides an actionable "how did today go?" signal with AI-powered pattern recognition. (see origin: `docs/brainstorms/2026-04-19-daily-digest-requirements.md`)

## Requirements Trace

- R1. Dedicated Digest tab (fourth tab: Overview > Lists > Settings > Digest)
- R2. Stats grid (2x3): TIR, Lows, Highs, Avg, Carbs, Insulin with color coding
- R3. AI insight card: adaptive-length Claude Haiku analysis with full context + 7-day history
- R4. Event timeline: chronological, color-coded meals/insulin/exercise
- R5. Date navigation: browse past days via date bar
- R6. Persistent storage: GRDB table, one row per calendar day
- R7. Separate AI consent toggle (`aiConsentDailyDigest`)
- R8. Loading states: spinner for stats, pulsing placeholder for AI, graceful degradation

## Scope Boundaries

- Stats computation from existing data stores
- AI insight with full context + cross-day references
- GRDB persistence for history browsing
- Date navigation for past days
- Refresh button for re-generating insight
- Separate AI consent toggle

### Deferred to AI Health Companion

- Conversational follow-up (asking AI questions)
- Health journal entries (illness, stress)
- Push notifications for digest availability
- Weekly/monthly aggregates

## Context & Research

### Relevant Code and Patterns

- Tab bar: `App/Views/ContentView.swift` — `TabView(selection:)` with 3 tabs, view tags in `Library/DirectConfig.swift`
- Middleware registration: `App/App.swift` — two arrays (device + simulator), both must be updated
- DataStore singleton: `App/Modules/DataStore/DataStore.swift` — GRDB model conformance pattern
- GRDB table creation: `App/Modules/MealImpact/MealImpactStore.swift` — recent example of new table + Future queries
- Claude API: `App/Modules/Claude/ClaudeService.swift` — async/await, Keychain API key, `Future` wrapper in `ClaudeMiddleware.swift`
- Settings toggle: `aiConsentFoodPhoto` across 4 files (DirectState, AppState, UserDefaults, DirectReducer)
- Data load guard pattern: handle `.setAppState(.active)`, guard `state.appState == .active` in load handlers

### Institutional Learnings

- **appState guard** (`docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`): Every DataStore middleware must guard `.active` or reads silently fail
- **Reducer-before-middleware** (`docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`): Don't guard on state the reducer just changed for the same action
- **Dangling Future** (`docs/solutions/logic-errors/grdb-future-nil-dbqueue-hangs-subscriber-20260318.md`): Every `Future` else-branch must call `promise(...)` — never leave unresolved
- **Keychain side channel** (`docs/solutions/security-issues/redux-action-secret-leakage-keychain-side-channel.md`): API key never in Redux actions
- **XML injection** (`docs/solutions/security-issues/xml-injection-ai-prompt-context-20260318.md`): Escape user strings in AI prompts
- **Sheet collision** (`docs/solutions/ui-bugs/swiftui-sheet-collision-ios15-sibling-views-20260315.md`): If digest tab presents sheets, use single `.sheet(item:)` with enum discriminator

## Key Technical Decisions

- **Tab instead of sheet:** Digest is a primary navigation destination, not a modal. Avoids cluttering Overview action buttons and gives full-screen space for the rich content.
- **Separate middleware file:** `DailyDigestMiddleware.swift` handles both stats computation and AI orchestration (not split into separate store + AI middlewares). The feature is cohesive and a single middleware keeps the data flow traceable.
- **Stats computed on-demand, not pre-aggregated:** Query raw readings/meals/insulin per day and compute stats at view time. Avoids a background aggregation job and keeps GRDB simple. Cached after first computation.
- **AI insight stored as plain text:** No structured JSON for the insight — it's free-form text the AI adapts based on content. Simpler storage, no schema to version.
- **Glucose sampling at 30-min intervals for AI:** ~48 data points per day. Enough for pattern recognition without bloating the prompt.

## Open Questions

### Resolved During Planning

- **Where to put the tab?** Fourth position (after Settings). Tag = 5.
- **Separate middleware or extend ClaudeMiddleware?** Separate `DailyDigestMiddleware` — the stats computation logic doesn't belong in Claude middleware.
- **How to handle "today" digest when day isn't complete?** Generate with available data. User can refresh later. `generatedAt` field tracks staleness.

### Deferred to Implementation

- **Exact SF Symbol for tab icon:** Several candidates (`doc.text.magnifyingglass`, `chart.bar.doc.horizontal`, `text.page.badge.magnifyingglass`). Pick during UI implementation.
- **Glucose sampling implementation:** Whether to use SQL `GROUP BY` with 30-min buckets or Swift-side filtering. Decide when writing the query.

## Implementation Units

- [ ] **Unit 1: DailyDigest model + GRDB table**

**Goal:** Define the domain model and database table for persisted daily digests.

**Requirements:** R6

**Dependencies:** None

**Files:**
- Create: `Library/Content/DailyDigest.swift`
- Modify: `App/Modules/DataStore/DataStore.swift` (add GRDB conformance)
- Create: `App/Modules/DataStore/DailyDigestStore.swift`
- Test: `DOSBTSTests/DailyDigestTests.swift`

**Approach:**
- `DailyDigest` struct in `Library/Content/` with all fields from R6
- GRDB conformance (FetchableRecord, PersistableRecord, Columns enum) in `DataStore.swift`
- `DailyDigestStore.swift` with `createDailyDigestTable()`, `saveDailyDigest()`, `getDailyDigest(date:)`, `getRecentDigests(days:)`, `updateInsight(date:insight:)`
- Every `Future` else-branch must call `promise(...)` when `dbQueue` is nil

**Patterns to follow:**
- `Library/Content/MealImpact.swift` for model struct
- `App/Modules/MealImpact/MealImpactStore.swift` for table creation + Future queries
- `App/Modules/DataStore/DataStore.swift` for GRDB conformance extension

**Test scenarios:**
- Happy path: DailyDigest model initializes with all fields and auto-generates UUID
- Happy path: Two digests with different dates are not equal
- Edge case: DailyDigest with nil aiInsight and nil generatedAt (pre-AI-generation state)

**Verification:**
- Model compiles, GRDB conformance is complete, store methods return Futures

---

- [ ] **Unit 2: Redux wiring (actions, state, reducer)**

**Goal:** Add all digest-related actions, state properties, and reducer cases.

**Requirements:** R1, R6, R7, R8

**Dependencies:** Unit 1

**Files:**
- Modify: `Library/DirectAction.swift`
- Modify: `Library/DirectState.swift`
- Modify: `App/AppState.swift`
- Modify: `Library/DirectReducer.swift`
- Modify: `Library/Extensions/UserDefaults.swift`
- Test: `DOSBTSTests/DirectReducerTests.swift`

**Approach:**
- Actions: `loadDailyDigest(date:)`, `setDailyDigest(digest:)`, `generateDailyDigestInsight(date:)`, `setDailyDigestInsight(date:insight:)`, `refreshDailyDigestInsight(date:)`, `setAIConsentDailyDigest(enabled:)`
- State: `currentDailyDigest: DailyDigest?`, `dailyDigestLoading: Bool`, `dailyDigestInsightLoading: Bool`, `aiConsentDailyDigest: Bool` (UserDefaults-backed)
- Reducer: handle `setDailyDigest`, `setDailyDigestInsight`, `setAIConsentDailyDigest`, loading state toggles
- Follow the 4-file pattern for `aiConsentDailyDigest` (DirectState, AppState, UserDefaults, DirectReducer)
- GRDB-backed state (`currentDailyDigest`) follows the 3-file pattern (no UserDefaults)

**Patterns to follow:**
- `aiConsentFoodPhoto` pattern for consent toggle
- `scoredMealEntryIds` pattern for GRDB-backed state
- IOB state tests in `DirectReducerTests.swift` for test style

**Test scenarios:**
- Happy path: `setDailyDigest` populates `currentDailyDigest`
- Happy path: `setDailyDigestInsight` updates insight on existing digest
- Happy path: `setAIConsentDailyDigest` toggles consent
- Edge case: `setDailyDigest` with nil replaces existing digest
- Happy path: loading flags set correctly by reducer

**Verification:**
- All actions compile, reducer handles each case, tests pass

---

- [ ] **Unit 3: DailyDigestMiddleware — stats computation**

**Goal:** Middleware that computes daily stats from existing data stores and persists them to GRDB.

**Requirements:** R2, R6, R8

**Dependencies:** Unit 1, Unit 2

**Files:**
- Create: `App/Modules/DailyDigest/DailyDigestMiddleware.swift`
- Modify: `App/App.swift` (register in both middleware arrays)

**Approach:**
- Handle `.setAppState(.active)` — no-op for now (digest loads on tab view, not app launch)
- Handle `.loadDailyDigest(date:)`:
  - Guard `state.appState == .active`
  - Check GRDB cache via `DailyDigestStore.getDailyDigest(date:)`
  - If cached: dispatch `.setDailyDigest`
  - If not cached: query `SensorGlucoseStore`, `MealStore`, `InsulinDeliveryStore`, `ExerciseStore` for the day's data
  - Compute stats: TIR/TBR/TAR from glucose readings vs alarm thresholds, low/high counts, averages, sums
  - Build `DailyDigest` (no insight), save to GRDB, dispatch `.setDailyDigest`
  - If consent + API key present: dispatch `.generateDailyDigestInsight(date:)`
- Register in both middleware arrays in `App.swift`
- **Critical:** Do not guard on `dailyDigestLoading` — the reducer sets it before middleware runs (reducer-before-middleware gotcha)

**Patterns to follow:**
- `App/Modules/MealImpact/MealImpactMiddleware.swift` for middleware function signature
- `App/Modules/IOB/IOBMiddleware.swift` for multi-store query orchestration
- Data load guard pattern from `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`

**Test scenarios:**
- Test expectation: none — middleware returns Combine publishers with side effects (DataStore queries). Unit testing middleware requires mocking DataStore. Stats computation logic can be tested via the model if extracted to a pure function.

**Verification:**
- Middleware registered in both arrays in App.swift
- Tapping Digest tab with existing glucose/meal/insulin data loads stats
- Browsing to a past date with data shows correct stats
- Browsing to a date with no data shows zeros

---

- [ ] **Unit 4: ClaudeService — digest insight generation**

**Goal:** Add a method to ClaudeService that generates a daily insight from stats + context.

**Requirements:** R3

**Dependencies:** Unit 1

**Files:**
- Modify: `App/Modules/Claude/ClaudeService.swift`

**Approach:**
- New method: `generateDigestInsight(digest:, events:, glucoseSamples:, recentDigests:) async throws -> String`
- Build system prompt with rules from R3 (reference specific times, call out recurring patterns, actionable observations, no medical advice)
- User message: structured text with stats summary, timestamped events, sampled glucose curve, and last 7 days' digest summaries
- Plain text output (no JSON schema — use `max_tokens: 300`)
- Sanitize user-entered text (meal descriptions) with XML escaping per `docs/solutions/security-issues/xml-injection-ai-prompt-context-20260318.md`
- API key from Keychain — never in Redux actions

**Patterns to follow:**
- `ClaudeService.analyzeFoodText()` for async request building and error handling
- `sanitizeFoodName()` for XML escaping

**Test scenarios:**
- Test expectation: none — calls external API. Verify at integration level during manual testing.

**Verification:**
- Method compiles, accepts correct parameters, returns plain text string
- Prompt includes all required context sections
- User text is XML-escaped

---

- [ ] **Unit 5: DailyDigestMiddleware — AI insight orchestration**

**Goal:** Wire the middleware to call ClaudeService for AI insight generation and update GRDB.

**Requirements:** R3, R7, R8

**Dependencies:** Unit 3, Unit 4

**Files:**
- Modify: `App/Modules/DailyDigest/DailyDigestMiddleware.swift`

**Approach:**
- Handle `.generateDailyDigestInsight(date:)`:
  - Guard `state.aiConsentDailyDigest`
  - Guard API key exists via `KeychainService.read(key:)`
  - Set `dailyDigestInsightLoading = true` (via dispatching a loading action, or let the reducer handle the generate action)
  - Query last 7 digests from GRDB for cross-day context
  - Sample glucose at 30-min intervals for the day
  - Query day's events (meals, insulin, exercise, treatment events)
  - Call `ClaudeService.generateDigestInsight()`
  - On success: dispatch `.setDailyDigestInsight(date:insight:)`, update GRDB row
  - On failure: dispatch action to clear loading state, leave insight nil
- Handle `.refreshDailyDigestInsight(date:)`: same as above but always re-generates (ignores cached insight)
- Use `Future` + `Task {}` wrapper pattern from `ClaudeMiddleware.swift`

**Patterns to follow:**
- `claudeMiddleware()` action handlers for `Future`/`Task` wrapping of async service calls
- Consent gate pattern: `guard state.aiConsentDailyDigest else { return Empty()... }`

**Test scenarios:**
- Test expectation: none — middleware with async side effects. Verify via manual testing.

**Verification:**
- AI insight appears in the UI after stats load (when consent + API key present)
- "Analyzing..." placeholder shows while loading
- "Insight unavailable — tap to retry" shows on API failure
- "Enable AI Insights in Settings" shows when consent not given

---

- [ ] **Unit 6: DigestView — main tab view**

**Goal:** Build the Digest tab UI with date navigation, stats grid, AI insight card, and event timeline.

**Requirements:** R1, R2, R3, R4, R5, R8

**Dependencies:** Unit 2, Unit 3, Unit 5

**Files:**
- Create: `App/Views/DigestView.swift`
- Modify: `App/Views/ContentView.swift` (add fourth tab)
- Modify: `Library/DirectConfig.swift` (add `digestViewTag`)

**Approach:**
- Date navigation bar: `< SAT APR 19 >` with left/right arrows. `@State selectedDate: Date` defaulting to today. Future dates disabled. Changing date dispatches `.loadDailyDigest(date:)`.
- Stats grid: 2x3 `LazyVGrid` with stat tiles. Each tile: label (dim amber), value (color-coded per R2). Use `AmberTheme` colors.
- AI insight card: cyan border (`AmberTheme.cgaCyan`), dim background. Shows:
  - Loading: pulsing "ANALYZING..." text
  - Loaded: insight text in `AmberTheme.amberLight`
  - No consent: "Enable AI Insights in Settings"
  - Error: "Insight unavailable — tap to retry" (tap dispatches `.refreshDailyDigestInsight`)
- Event timeline: `ForEach` over day's events sorted by timestamp. Color-coded by type (amber meals, cyan insulin, green exercise).
- Refresh button: small button in AI card header, dispatches `.refreshDailyDigestInsight(date:)`.
- Add tab to `ContentView.swift`: `DigestView().tabItem { Label("Digest", systemImage: "doc.text.magnifyingglass") }.tag(DirectConfig.digestViewTag)`
- Dispatch `.loadDailyDigest(date: today)` in `.onAppear`
- DOS amber CGA styling: monospace fonts (`DOSTypography`), dark background, sharp corners

**Patterns to follow:**
- `App/Views/OverviewView.swift` for tab view structure and store binding
- `App/Views/Overview/ChartView.swift` for date navigation pattern
- `AmberTheme`, `DOSTypography`, `DOSSpacing` for design tokens

**Test scenarios:**
- Test expectation: none — pure UI view. Verify visually.

**Verification:**
- Fourth tab appears in tab bar with correct icon
- Tapping tab shows today's digest with stats and AI insight
- Date navigation arrows work, future dates disabled
- Loading states display correctly for both stats and AI
- All text uses monospace fonts, colors match CGA theme
- Event timeline shows correct color coding

---

- [ ] **Unit 7: Settings — AI consent toggle**

**Goal:** Add the `aiConsentDailyDigest` toggle to Settings.

**Requirements:** R7

**Dependencies:** Unit 2

**Files:**
- Modify: `App/Views/Settings/AISettingsView.swift` (or equivalent settings file)

**Approach:**
- Add a toggle row: "AI Daily Insights" with description text explaining what data is sent
- Bind to store dispatch `.setAIConsentDailyDigest(enabled:)`
- Place near existing `aiConsentFoodPhoto` toggle for discoverability

**Patterns to follow:**
- Existing `aiConsentFoodPhoto` toggle in Settings for layout and copy style

**Test scenarios:**
- Test expectation: none — UI toggle. Verify by toggling and checking that digest AI behavior changes.

**Verification:**
- Toggle appears in Settings
- Toggling on enables AI insight generation on next digest load
- Toggling off shows "Enable AI Insights in Settings" in the AI card

---

- [ ] **Unit 8: Xcode project file updates**

**Goal:** Add all new Swift files to the Xcode project so they compile.

**Requirements:** All

**Dependencies:** Unit 1, Unit 3, Unit 6

**Files:**
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

**Approach:**
- Add entries for each new file in 4 pbxproj sections: PBXBuildFile, PBXFileReference, PBXGroup (correct parent folder), PBXSourcesBuildPhase
- New files to add:
  - `Library/Content/DailyDigest.swift` (Library group)
  - `App/Modules/DataStore/DailyDigestStore.swift` (DataStore group)
  - `App/Modules/DailyDigest/DailyDigestMiddleware.swift` (new DailyDigest group under Modules)
  - `App/Views/DigestView.swift` (Views group)
- Test file (`DOSBTSTests/DailyDigestTests.swift`) is auto-discovered via `PBXFileSystemSynchronizedRootGroup`
- Use unique hex IDs following existing patterns

**Patterns to follow:**
- Existing pbxproj entries for recently added files (e.g., MealImpact files)

**Test scenarios:**
- Test expectation: none — build infrastructure

**Verification:**
- `xcodebuild build` succeeds with no missing file errors

## System-Wide Impact

- **Interaction graph:** `DailyDigestMiddleware` reads from `SensorGlucoseStore`, `MealStore`, `InsulinDeliveryStore`, `ExerciseStore`, and `DailyDigestStore`. Calls `ClaudeService`. No other middleware needs to know about digests.
- **Error propagation:** API failures stay local to the AI insight card (graceful degradation). GRDB failures logged via `DirectLog.error()`.
- **State lifecycle risks:** `currentDailyDigest` is overwritten on each date navigation. No stale-state risk since it's always freshly loaded.
- **API surface parity:** No other interfaces affected. Widget does not show digest data.
- **Unchanged invariants:** Existing tabs, alarm system, treatment workflow, food analysis — all unchanged. The Digest tab is purely additive.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| AI insight quality varies with data completeness | Show stats regardless; AI card gracefully handles sparse days with shorter insights |
| API costs if user browses many past days | Insights are cached after first generation; only one API call per day |
| Token budget may exceed estimate for data-rich days | Cap glucose samples at 48 (30-min intervals), cap event count if needed |
| pbxproj merge conflicts | Single unit at the end; do all file additions in one commit |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-19-daily-digest-requirements.md](docs/brainstorms/2026-04-19-daily-digest-requirements.md)
- Related patterns: `App/Modules/MealImpact/` (recent GRDB + middleware), `App/Modules/Claude/` (AI integration)
- Learnings: `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`, `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`, `docs/solutions/logic-errors/grdb-future-nil-dbqueue-hangs-subscriber-20260318.md`

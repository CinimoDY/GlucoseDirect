# Dev Journal: DOSBTS Food Logging AI Evolution

**Session:** dosbts-editable-ai-results
**Dates:** 2026-03-17 through 2026-03-20
**Builds shipped:** 27, 28, 29
**PR:** #2 (merged)
**Linear:** DMNC-553

---

## Overview

Two arcs: fixing a critical data persistence bug, then building and hardening a substantial new feature — per-item editing of AI food analysis results with a learning system.

## Arc 1: Data Persistence Bug (Build 27)

Data entered through the UI was written to GRDB but never loaded. Root cause: SwiftUI's `onChange(of: scenePhase)` doesn't fire if the value is already `.active` at launch. The app's `appState` was stuck at `.inactive`, causing all middleware data load guards to silently fail. Fix: dispatch `.setAppState(.active)` in `.onAppear`.

Secondary fixes: database path API (`absoluteString` → `path`), removed latent data-loss bug where `.clearBloodGlucoseValues` incorrectly deleted meals and insulin.

## Arc 2: Editable AI Food Results — Staging Plate (Build 28)

### What Was Built

- **Staging plate UI** — AI-identified food items land on an editable list. Tap to expand (inline, not sheets), swipe-to-delete, add missing items. Nutrition banner auto-recalculates from items.
- **AI learning system** — Corrections logged to GRDB `FoodCorrection` table. Auto-populates `PersonalFood` dictionary. XML-structured prompt injection feeds corrections + dictionary into future Claude calls.
- **Privacy hardening** — Food actions suppressed from log middleware. AI consent disclosure updated.

### Architecture Decisions

- Single `.saveMealWithCorrections` dispatch → middleware chains to `.addMealEntry` (avoids race condition)
- `ClaudeMiddleware` reads from DirectState, not GRDB (preserves ownership boundary)
- Atomic GRDB transaction for corrections + dictionary upserts
- Custom expand/collapse over DisclosureGroup (iOS 15 animation bugs)

### Code Review (13 findings, all fixed)

Multi-agent review caught: dangling Future, XML injection, log PII leak, stuck UI, plus 9 lower-priority items. All addressed before merge.

## Documentation Created

- `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md`
- `docs/solutions/logic-errors/grdb-future-nil-dbqueue-hangs-subscriber-20260318.md`
- `docs/solutions/security-issues/xml-injection-ai-prompt-context-20260318.md`
- `docs/plans/2026-03-18-feat-editable-ai-results-and-food-learning-plan.md`
- Updated CLAUDE.md with data load guard pattern + TestFlight deploy notes

---

## Arc 3: Natural Language Food Parsing (Build 29) — 2026-03-20

### What Was Built

"ASK AI" row in the food entry search bar. User types a description ("cheeseburger from McDonalds", "200ml whole milk", "small Ben&Jerry's cookies and cream") and Claude parses it into structured nutrition data — same schema as photo analysis, landing on the same staging plate.

### Key Design Decisions

- **Search bar doubles as NL input** — "Ask AI" appears in actionsSection when text >= 3 chars
- **Zero new files** — extends ClaudeService (new `analyzeFoodText()` method), ClaudeMiddleware (new case handler), UnifiedFoodEntryView (new NavigationLink row)
- **FoodPhotoAnalysisView needs zero changes** — the existing state machine already handles the text path (state machine shows resultsSection when result != nil, never shows photoPickerSection)
- **Enhanced prompt** with resolution protocol (branded foods, portion defaults), confidence definitions with explicit criteria, and `reasoning` field for chain-of-thought before numbers
- **Personal food dictionary only** in text prompts (skip photo corrections — they're visual-specific)

### Research-Driven Prompt Engineering

The plan was deepened with research from NutriBench, Taralli study, and PMC12513282:
- CoT reasoning field reduces multi-item errors ~50%
- Few-shot examples improve accuracy from 25% to 76% (deferred to iteration)
- Explicit portion defaults ("a handful" = 28g nuts) resolve ambiguous quantities
- Confidence definitions with error thresholds prevent LLM overconfidence

### Post-Merge Review Findings (3 HIGH, fixed)

1. `.onAppear` on NavigationLink destination re-fires on back navigation → added guard against loading/result already present
2. `stagedItems` stale on re-entry → added `.onDisappear` to clear staged items
3. `.setFoodAnalysisError` not suppressed from logs → added to suppression list

### Linear Issues Created

- DMNC-558: NL food parsing (this feature, done)
- DMNC-560: Conversational follow-up (backlog)
- DMNC-561: Barcode scanning + food database (backlog)
- DMNC-562: Portion presets (backlog)
- DMNC-563: 2026 food logging vision (reference)

### Documentation

- `docs/plans/2026-03-20-feat-natural-language-food-parsing-plan.md`
- `docs/references/food-logging-2026-vision.md`
- Updated CLAUDE.md with dual Claude analysis paths

---

## Arc 4: Barcode Scanning with Open Food Facts (Build 30) — 2026-03-20

### What Was Built

Dedicated barcode scanner using AVCaptureSession + AVCaptureMetadataOutput (EAN-13/EAN-8/UPC-E). Scanned barcode → Open Food Facts API lookup (free, no auth) → NutritionEstimate on staging plate for confirmation. One new file (BarcodeScannerView), OFF API inlined in ClaudeMiddleware (~150 lines).

### Key Decisions

- **1 new file instead of 3** — OFF API call inlined in ClaudeMiddleware, no separate service or middleware (YAGNI — one endpoint, one caller)
- **SCAN button outside API key gate** — OFF is free, always available
- **EAN/UPC only** — no QR/Code128 (security: prevents arbitrary string injection)
- **Missing nutrition = nil, not zero** — critical for CGM safety (0g carbs would be dangerous)
- **Bounds-clamp** all OFF nutrition data before HealthKit (carbs 0-1000, calories 0-10000)
- **Programmatic NavigationLink** for auto-push to staging plate (avoids double NavigationView)

### Review Findings (3 fixed)

1. Double NavigationView from embedding FoodPhotoAnalysisView in Group → used NavigationLink(isActive:)
2. "Try Again" not clearing error → dispatch .setFoodAnalysisResult(nil)
3. Unused @State variable → removed

### Linear

- DMNC-561: Barcode scanning (done)
- DMNC-562: Portion presets (backlog, unblocked by this)

---

## Arc 5: Conversational Follow-up (Build 31) — 2026-03-21

### What Was Built

When Claude returns low/medium confidence results from text input, an inline clarification section appears on the staging plate: "Can you be more specific?" + text field + Send button. User answers → multi-message follow-up to Claude → updated NutritionEstimate replaces staged items. Up to 3 rounds.

### Key Decisions

- **Zero new Redux state** — all follow-up state (history, round counter, loading, error) in `@State`
- **Zero new schema fields** — trigger from `confidence != .high` in the view, not a Claude-supplied field
- **Zero new files** — extended existing `.analyzeFoodText(query:history:)` with optional history
- **Multi-turn API** — pass raw assistant JSON + user answers as multi-message conversation
- **Text-path only** — photo/barcode results don't show clarification (no `rawAssistantJSON`)
- **View owns history, service replays verbatim** — clean separation, no double-append

### Review Findings (9 found, all fixed)

3 HIGH:
1. Double user turn in messages → service replays verbatim, view owns appends
2. onChange misses when description unchanged → observe both totalCarbsG and description + error handler
3. Cap exceeded leaves spinner → check in view before dispatch + error onChange resets state

6 MEDIUM: double-tap guard, round counter on success only, hide for photo results, sanitize editDescription, transient field docs, error resets spinner

### Documentation

- `docs/plans/2026-03-20-feat-conversational-food-clarification-plan.md`
- DMNC-560 Done in Linear

---

## Session Summary

**Dates:** 2026-03-17 through 2026-03-21
**Builds shipped:** 27, 28, 29, 30, 31
**PRs merged:** #2 (editable AI results), #3 (NL parsing), #4 (barcode), #5 (conversational follow-up)
**Linear issues closed:** DMNC-553, DMNC-558, DMNC-560, DMNC-561

### What Was Built (Across All Arcs)

1. **Data persistence fix** (Build 27) — appState stuck at .inactive
2. **Editable AI food results** (Build 28) — staging plate, per-item editing, AI learning from corrections
3. **NL text food parsing** (Build 29) — type "cheeseburger from McDonalds" → structured nutrition
4. **Barcode scanning** (Build 30) — EAN/UPC scan → Open Food Facts lookup → staging plate
5. **Conversational follow-up** (Build 31) — "some almonds" → "How many?" → "about 10" → accurate result

### Remaining Backlog

- DMNC-562: Portion presets & smart quantities (only remaining food logging issue)

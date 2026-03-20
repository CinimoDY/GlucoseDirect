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

# Dev Journal: DOSBTS Editable AI Results

**Session:** dosbts-editable-ai-results
**Date:** 2026-03-18
**Builds shipped:** 27, 28
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

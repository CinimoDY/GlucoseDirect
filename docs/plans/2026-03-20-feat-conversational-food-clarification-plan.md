---
title: "feat: Conversational Follow-up for Food Clarification"
type: feat
status: completed
date: 2026-03-20
deepened: 2026-03-20
linear: DMNC-560
---

# Conversational Follow-up for Food Clarification

## Enhancement Summary

**Deepened on:** 2026-03-20
**Research agents:** multi-turn-api-researcher, architecture-strategist, code-simplicity-reviewer

### Key Simplifications
1. **No new Redux state** — follow-up loading handled by `@State` in the view, not global state
2. **No schema change to NutritionEstimate** — detect follow-up trigger from `confidence != .high` in the view. Fixed prompt for clarification question.
3. **No new action** — extend existing `.analyzeFoodText` to accept optional conversation history
4. **Merged history + round counter** into single `FollowUpSession` struct in `@State`
5. **Multi-turn API confirmed** — pass raw JSON assistant response in messages array, schema re-sent each turn

---

## Overview

When Claude returns a low/medium confidence food estimate, show an inline clarification prompt on the staging plate. User answers → follow-up sent as multi-message conversation → updated result replaces staging plate items. Up to 3 rounds. Text-path only. Zero new Redux state, zero schema changes.

## Problem Statement

The NL text parser (DMNC-558) is single-shot. For ambiguous inputs like "some almonds", "milk", or "a burger", Claude guesses conservatively. A brief inline conversation resolves ambiguity naturally — the user clarifies, Claude returns an improved estimate.

## Proposed Solution

### UX Flow

1. User types "some almonds" → taps "ASK AI"
2. Claude returns `NutritionEstimate` with `confidence: .low`
3. Staging plate shows the initial estimate AND an inline clarification section (before the confidence badge):
   - Fixed prompt: "Can you be more specific? (e.g. portion size, brand, cooking method)"
   - Text field for user's answer + "Send" button
4. User types "about 10 almonds" → taps Send
5. Inline spinner in the clarification row (staging plate stays visible)
6. Follow-up sent to Claude as multi-message conversation (original query + AI response + user answer)
7. Updated `NutritionEstimate` replaces staging plate items
8. If new result is `confidence: .high` → clarification UI hidden. If still low → another round.
9. User taps "Log Meal" at any point.

**Skip path:** `confidence == .high` → no clarification UI shown. Most queries go straight to staging plate.

**Ignore path:** User can tap "Log Meal" at any time with the current estimate.

**Exhaustion:** After 3 rounds, clarification field hidden. Note: "Best estimate after clarification."

### Architecture (Simplified)

**No schema changes.** Trigger clarification UI from `confidence != .high` in the view. Fixed question prompt — Claude doesn't need a custom question field.

**No new action.** Extend `.analyzeFoodText(query: String)` to accept optional history:
```swift
case analyzeFoodText(query: String, history: [ConversationTurn] = [])
```
Where `ConversationTurn` is a lightweight struct: `struct ConversationTurn { let role: String; let content: String }`.

When `history` is non-empty, `ClaudeService` builds a multi-message request instead of single-turn. Same schema, same response handling.

**No new Redux state.** Follow-up loading is `@State private var isFollowingUp = false` in the view. The staging plate stays visible because we do NOT dispatch `.setFoodAnalysisLoading(true)` during follow-up. When the result arrives via `.setFoodAnalysisResult`, the view detects the update via `.onChange(of:)`.

**Conversation state in `@State`:**
```swift
private struct FollowUpSession {
    var history: [ConversationTurn] = []
    var round: Int { history.filter { $0.role == "user" }.count }
    var rawAssistantResponse: String?  // Last raw JSON from Claude for multi-turn
}
@State private var followUp = FollowUpSession()
```

**Staging plate update:** On follow-up, detect new result via `.onChange(of: store.state.foodAnalysisResult)` with `isFollowUp` flag. Explicitly replace staged items. The existing `populateStagedItems` guard stays intact for initial population.

### Multi-Turn API Pattern (Confirmed)

Claude API supports multi-message arrays with `json_schema` output:
```json
{
  "messages": [
    {"role": "user", "content": "Analyze: some almonds"},
    {"role": "assistant", "content": "{\"reasoning\":\"...\",\"items\":[...],\"confidence\":\"low\"}"},
    {"role": "user", "content": "about 10 almonds"}
  ],
  "output_config": {"format": {"type": "json_schema", "schema": {...}}}
}
```
- Assistant message is the raw JSON string from the prior response
- Schema re-sent each turn (cached server-side ~24h)
- ~$0.0005/follow-up additional input cost on Haiku
- Always end messages array with a `user` role

## Technical Considerations

### Files to Modify

| File | Change |
|------|--------|
| `App/Modules/Claude/ClaudeService.swift` | Extend `analyzeFoodText()` to accept `history: [ConversationTurn]`. Build multi-message request when history non-empty. Add prompt instruction for clarification. Define `ConversationTurn` struct. |
| `App/Modules/Claude/ClaudeMiddleware.swift` | Update `.analyzeFoodText` handler to pass history to service. Return raw assistant response text alongside NutritionEstimate (for multi-turn context). |
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Add inline clarification section (question + text field + send). `FollowUpSession` struct in `@State`. `.onChange(of: foodAnalysisResult)` to detect follow-up updates. Round cap. |
| `App/Modules/Log/Log.swift` | `.analyzeFoodText` already suppressed — no change needed (history is in the same action) |

### No New Files, No New Redux State, No Schema Changes

This is the simplest possible implementation. 3 files modified. Zero new actions, zero new state properties, zero new models.

### Key Decisions

1. **Detect clarification from `confidence != .high`** — not a schema field. Fixed prompt in view: "Can you be more specific?" Zero NutritionEstimate changes.

2. **All follow-up state in `@State`** — `FollowUpSession` struct with history array + computed round. `isFollowingUp` bool for inline spinner. No Redux state for clarification loading/error.

3. **Extend existing action** — `.analyzeFoodText(query:history:)` with defaulted empty history. When middleware sees non-empty history, builds multi-message request. Same code path, same response handling.

4. **Staging plate stays visible during follow-up** — do NOT dispatch `.setFoodAnalysisLoading(true)`. Use local `@State isFollowingUp` for inline spinner only.

5. **Explicit replace on follow-up** — `.onChange(of: store.state.foodAnalysisResult)` with `isFollowUp` flag triggers item replacement. Initial `populateStagedItems` guard untouched.

6. **3-round cap** — computed from `followUp.history.filter { $0.role == "user" }.count`. After 3, clarification section hidden.

7. **Clarification UI placed before confidence section** — user encounters it while reviewing results, not after scrolling.

8. **Service-layer character budget** — cap total history at 4000 chars as defense-in-depth against runaway API spend.

### Learnings Applied

- **No middleware guards on loading state** — clarification loading is view-local `@State` (avoids reducer-first timing)
- **Sanitize follow-up text** — XML escape, cap at 200 chars (xml-injection learning)
- **Do not dispatch `.setFoodAnalysisLoading(true)` during follow-up** — it nils out `foodAnalysisResult` in the reducer, destroying the staging plate
- **Text-path only** — keeps scope tight, avoids image re-transmission

### Edge Cases

- **High confidence** → no clarification UI → staging plate shows normally
- **User ignores question** → taps "Log Meal" → current estimate logged as-is
- **3 rounds exhausted** → question hidden, "Best estimate after clarification" note
- **Follow-up network failure** → show error inline in clarification row (via `@State followUpError`), staging plate stays visible, offer retry
- **User changes food entirely** → "actually it was cashews" → Claude handles in multi-turn context
- **Nonsense follow-up** → Claude returns best-guess, possibly another low-confidence round
- **Follow-up answer too long** → cap at 200 chars
- **User edits staging plate then sends follow-up** → follow-up result replaces edits (documented)
- **History exceeds 4000 chars** → service rejects, show error

## Acceptance Criteria

- [x] **Inline clarification UI** — question prompt + text field + Send button on staging plate when `confidence != .high`
- [x] **Multi-message follow-up** sent to Claude with full conversation history
- [x] **Staging plate stays visible** during follow-up (no `.setFoodAnalysisLoading` dispatch)
- [x] **Updated result replaces staging plate items** after follow-up
- [x] **3-round cap** — clarification hidden after 3 rounds
- [x] **"Log Meal" always enabled** — user can log at any round
- [x] **Follow-up error inline** — doesn't replace staging plate
- [x] **Follow-up answer sanitized** — XML escaped, capped at 200 chars
- [x] **Text-path only** — clarification only for `.analyzeFoodText` results
- [x] **No new Redux state** — all clarification state in `@State`
- [x] **No NutritionEstimate schema changes** — trigger from `confidence` level (+ rawAssistantJSON transient field)
- [x] **Builds on simulator**

## Success Metrics

- "some almonds" → inline prompt → "about 10" → accurate estimate for 10 almonds
- "milk" → prompt → "oat milk, 200ml" → correct oat milk nutrition
- "200ml whole milk" (clear input) → no clarification UI → straight to staging plate
- Most queries see no clarification UI at all — zero friction for the common case

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Claude asks for clarification too often (annoying) | Only trigger on `confidence != .high`; prompt instruction limits questions to genuinely ambiguous cases. 3-round cap. |
| Token cost per follow-up | ~$0.0005 input cost on Haiku. Negligible. |
| `populateStagedItems` guard blocks follow-up update | Explicit replace via `.onChange` with `isFollowUp` flag — guard untouched |
| Conversation history lost on interruption | Acceptable — user has the last estimate, can log or start over |
| Raw assistant JSON in multi-turn messages | Confirmed working with Claude API — pass `response.content[0].text` as assistant role message |

## Sources & References

### Research
- [Anthropic Messages API — multi-turn + structured output](https://docs.anthropic.com/en/api/messages) — confirmed: multi-message array with json_schema works, assistant message is raw JSON string
- Haiku pricing: $1/MTok input, $5/MTok output. Follow-up overhead: ~$0.0005/call.

### Linear
- [DMNC-560](https://linear.app/lizomorf/issue/DMNC-560) — This issue
- [DMNC-558](https://linear.app/lizomorf/issue/DMNC-558) — NL text parsing (prerequisite, done)

### Internal References
- `App/Modules/Claude/ClaudeService.swift` — extend `analyzeFoodText()` for multi-turn
- `App/Modules/Claude/ClaudeMiddleware.swift` — update handler to pass history
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — add inline clarification section
- `docs/plans/2026-03-20-feat-natural-language-food-parsing-plan.md` — NL parsing plan (foundation)

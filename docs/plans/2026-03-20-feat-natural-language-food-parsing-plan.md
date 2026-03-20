---
title: "feat: Natural Language Food Parsing via Claude"
type: feat
status: completed
date: 2026-03-20
deepened: 2026-03-20
linear: DMNC-558
---

# Natural Language Food Parsing via Claude

## Enhancement Summary

**Deepened on:** 2026-03-20
**Research agents:** prompt-engineering-researcher, architecture-strategist, security-sentinel, code-simplicity-reviewer

### Key Improvements
1. **`reasoning` field in JSON schema** — forces Claude to think step-by-step before numbers, reduces multi-item errors by ~50% (NutriBench research)
2. **Portion defaults embedded in prompt** — "a handful" = 28g nuts, "a couple" = 2, standardizes ambiguous quantities
3. **`FoodPhotoAnalysisView` needs zero changes** — existing state machine already hides photo picker when result is present
4. **Structural XML isolation for user query** — wrap in `<food_description>` element, not raw string interpolation
5. **Defence-in-depth input cap** — 500-char cap enforced in both view AND service layer

---

## Overview

Extend the food entry search bar to double as a natural language input. When the user types (or dictates via Wispr) a description like "a cheeseburger from McDonalds" or "200ml whole milk", an "Ask AI" row appears in the actions section. Tapping it sends the text to Claude, which returns a structured `NutritionEstimate`. The result lands on the existing staging plate for confirmation, correction, and logging.

## Problem Statement

Currently food logging requires manual entry (type name + carbs), picking from favorites/recents, or taking a photo. There's no way to describe food in natural language and get structured nutrition data. Users want to quickly say "eating a Big Mac" and have the app figure out the nutrition — especially when they know what they're eating but don't have the food in front of them for a photo.

## Proposed Solution

### UX Flow

1. User opens UnifiedFoodEntryView (MEAL button)
2. Types in search bar: "cheeseburger from McDonalds"
3. Local search runs instantly (favorites + recents)
4. **"Ask AI" row** appears in `actionsSection` (alongside MANUAL and PHOTO) when text >= 3 chars and `aiConsentFoodPhoto` is true
5. User taps "Ask AI"
6. Dispatches `.setFoodAnalysisLoading(true)` then `.analyzeFoodText(query:)`
7. Loading state shown (same progress phases as photo analysis)
8. Claude returns `NutritionEstimate` → auto-push to `FoodPhotoAnalysisView` via programmatic `NavigationLink`
9. User reviews/edits items on staging plate → taps "Log Meal"
10. `saveMealWithCorrections` dispatched, view pops back, toast shown

### Architecture

**New action:** `DirectAction.analyzeFoodText(query: String)` — text-only, no image data.

**New service method:** `ClaudeService.analyzeFoodText(query:personalFoods:)` — text-only API call, same `NutritionEstimate` JSON schema response. No image in the API call body.

**Shared state:** Reuse `foodAnalysisResult` / `foodAnalysisLoading` / `foodAnalysisError`. Dispatch `.setFoodAnalysisLoading(true)` before `.analyzeFoodText` — the reducer atomically clears result and error.

**Middleware:** Handle `.analyzeFoodText` in `claudeMiddleware`. Guard on `state.aiConsentFoodPhoto` (same as photo path). Read `state.personalFoodValues` (dictionary only, skip photo corrections). Call `ClaudeService.analyzeFoodText()`. Dispatch result or error.

**Staging plate:** Push to existing `FoodPhotoAnalysisView` via NavigationLink. The existing state machine already handles the text path correctly — when `foodAnalysisResult != nil`, it shows `resultsSection` (staging plate) and never shows `photoPickerSection`. **No changes to `FoodPhotoAnalysisView` needed.**

### Prompt Design

#### Research Insights

Research (NutriBench, PMC12513282, Taralli study) shows:
- **`reasoning` field** in schema forces Claude to think step-by-step before numbers — reduces errors ~50% on multi-item meals
- **Few-shot examples** improve accuracy from ~25% (zero-shot) to ~76% (3-5 examples). Start with zero-shot + CoT reasoning; add 3-5 hand-picked examples after initial testing if accuracy is insufficient
- **Explicit portion defaults** in the prompt resolve ambiguity ("a handful" = 28g nuts)
- **Brand instruction** ("use published nutrition data for named brands") dramatically improves branded food accuracy
- **Confidence definitions** with explicit criteria prevent overconfidence (LLMs are systematically overconfident without them)

#### Prompt Structure

```
You are a registered dietitian AI assistant. Given a food description, identify each distinct food item and estimate nutritional content.

<resolution_protocol>
- Named restaurant items ("Big Mac", "Grande Latte"): use the brand's published nutrition data.
- Named packaged products ("Ben & Jerry's Cookies & Cream"): use standard serving or stated size.
- Metric quantities (200ml, 100g): use as stated.
- Informal quantities: "a couple" = 2, "a few" = 3, "a handful" of nuts = 28g,
  "a slice" of bread = 28g, pizza = 100g, "a cup" = 240ml liquid.
- "small/medium/large" at a restaurant: match the chain's published size tiers.
- When quantity is unclear: assume one standard serving; note the assumption.
</resolution_protocol>

<confidence_definitions>
"high": Specific branded/restaurant product with known nutrition, or precise metric quantities for common foods. Error < 15%.
"medium": Recognized food type but brand is generic, quantity informal, or cooking method unclear. Error 15-35%.
"low": Ambiguous food, very vague quantity, unusual/regional item, or combining multiple assumptions. Error > 35%.
When in doubt between two levels, choose the lower one.
</confidence_definitions>

<food_description>{sanitized query wrapped in XML element}</food_description>

<user_food_dictionary>
{personal foods — max 50 entries}
</user_food_dictionary>
```

#### Enhanced JSON Schema

Add `reasoning` field (forces CoT before numbers) and keep existing `NutritionEstimate` compatible:

```json
{
  "reasoning": "string — step-by-step identification of each food item and data source",
  "description": "string — brief meal description",
  "items": [...],  // same NutritionItem schema
  "total_carbs_g": "number",
  "total_calories": "number",
  "confidence": "high|medium|low",
  "confidence_notes": "string"
}
```

The `reasoning` field is consumed by `ClaudeService` but stripped before creating `NutritionEstimate` — the model doesn't need a new property. Just ignore it during JSON decoding (it's not in the `CodingKeys`).

## Technical Considerations

### Files to Modify

| File | Change |
|------|--------|
| `Library/DirectAction.swift` | Add `.analyzeFoodText(query: String)` |
| `App/Modules/Claude/ClaudeService.swift` | Add `analyzeFoodText()` method + `buildTextPrompt()` with enhanced prompt |
| `App/Modules/Claude/ClaudeMiddleware.swift` | Handle `.analyzeFoodText` with consent guard + personalFoods from state |
| `App/Views/AddViews/UnifiedFoodEntryView.swift` | Add "Ask AI" NavigationLink in `actionsSection` + loading state |
| `App/Views/AddViews/AIConsentView.swift` | Update consent copy: "food photo or description" |
| `App/Modules/Log/Log.swift` | Add `.analyzeFoodText: break` to suppression list |

**`FoodPhotoAnalysisView.swift` — NO CHANGES NEEDED.** The existing state machine already shows `resultsSection` when `foodAnalysisResult != nil` and never shows `photoPickerSection`. Verified by code review.

### No New Files Needed

Extends existing files only. No new models, GRDB tables, or middlewares.

### Key Architectural Decisions

1. **Shared state, clear on entry** — Dispatch `.setFoodAnalysisLoading(true)` before `.analyzeFoodText`. Reducer atomically clears result + error.

2. **NavigationLink to staging plate** — Push to `FoodPhotoAnalysisView` (existing). No sheet (nested sheet constraint). Apply `.navigationBarHidden(true)` on destination (same as photo path).

3. **"Ask AI" in `actionsSection`** — Alongside MANUAL and PHOTO NavigationLinks. Gated on `searchText.count >= 3 && (store.state.claudeAPIKeyValid || store.state.aiConsentFoodPhoto)`. Not in `recentsSection`.

4. **Personal dictionary only** — Include `personalFoodValues` (max 50 entries). Skip `recentFoodCorrections` (photo-specific).

5. **Defence-in-depth input validation** — Cap at 500 chars in BOTH the view (before dispatch) AND `ClaudeService.analyzeFoodText()`. Min 3 chars. XML-escape via `sanitizeFoodName` pattern. Wrap query in `<food_description>` XML element for structural isolation.

6. **`reasoning` field requires a separate schema dictionary** — The text prompt uses a different JSON schema from the photo prompt (adds `reasoning` as a required string field). Create a `private let textNutritionSchema` alongside the existing `nutritionSchema` in `ClaudeService`. The `NutritionEstimate` Swift model doesn't need to change — `reasoning` is not in `CodingKeys` so the decoder ignores it.

7. **Consent guard in middleware** — Replicate `guard state.aiConsentFoodPhoto` in `.analyzeFoodText` case, same as `.analyzeFood`.

### Learnings Applied (from docs/solutions/)

- **No middleware guards on `foodAnalysisLoading`** — reducer runs first (middleware-race-condition)
- **Wrap user text in XML element** — structural isolation, not just escaping (xml-injection)
- **API key stays in Keychain** — action carries query only (secret-leakage)
- **Clear state on dismiss** — `.setFoodAnalysisLoading(false)` on every dismiss path (dangling-future)

### Edge Cases

- **Empty items** → Show "Couldn't identify foods — try being more specific" with option to retry or use manual entry. Guard in `resultsSection`: `if stagedItems.isEmpty { show error state }`
- **Low confidence** → Amber warning on staging plate, still allow logging
- **Non-food input** → Claude returns low confidence; user can cancel
- **Long input** → Cap at 500 chars in view + service; show truncation indicator
- **No API key** → "Ask AI" row hidden (existing gate logic)
- **Network failure** → Error section with "Try Again" (existing pattern)
- **Stale photo result in state** → Cleared by `.setFoodAnalysisLoading(true)` before text dispatch

### Post-Parse Validation (deferred)

Not in MVP scope. The staging plate already lets users see and edit all values visually. Automated validation (calorie formula checks, fiber <= carbs clamping) can be added later if AI output quality proves unreliable.

## Acceptance Criteria

- [x] **"Ask AI" row** in `actionsSection` when search text >= 3 chars and AI is set up
- [x] **Text sent to Claude** via `analyzeFoodText()` (text-only, enhanced prompt with reasoning + portion defaults)
- [x] **Loading state** shown while Claude processes
- [x] **Staging plate** displays results (push via NavigationLink to existing `FoodPhotoAnalysisView`)
- [x] **Per-item editing** works (existing staging plate)
- [x] **Corrections logged** on save (existing `saveMealWithCorrections`)
- [x] **Personal dictionary** in text prompt (max 50 entries, not photo corrections)
- [x] **Input sanitized** — XML-escaped, wrapped in `<food_description>`, capped 500 chars in view + service
- [x] **Empty results handled** — "couldn't identify" message, not empty staging plate
- [x] **Consent copy updated** — "food photo or description"
- [x] **`.analyzeFoodText` suppressed** from log middleware
- [x] **State cleared on dismiss**
- [x] **Consent guard** replicated in middleware `.analyzeFoodText` case
- [x] **Builds on simulator**

## Success Metrics

- Type "cheeseburger from McDonalds" → accurate per-product nutrition → log in < 15 seconds
- Branded foods (Ben & Jerry's, McDonalds) return accurate data (`data_source: brand_published` equivalent)
- Quantity-aware ("200ml milk") returns correctly scaled nutrition
- "a couple of almonds" → Claude asks no follow-up, returns 2 almonds with correct nutrition
- Personal dictionary improves results over time

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Claude hallucinating nutrition for obscure foods | Confidence flag + staging plate + `reasoning` field improves accuracy |
| API latency (~2-4s) | Show progress phases; local results appear instantly |
| Short/ambiguous queries | Min 3 chars; portion defaults in prompt; conversational follow-up (DMNC-560) later |
| Prompt injection via user text | XML structural isolation + escaping + length cap |
| Shared state stale results | Atomic clear via `.setFoodAnalysisLoading(true)` before dispatch |
| Token cost | Haiku ~$0.003/call; negligible. Reasoning field adds ~50 output tokens |

## Sources & References

### Research
- [NutriBench: LLMs on Nutrition Estimation from Meal Descriptions](https://arxiv.org/html/2407.12843v2) — CoT reduces error ~50%
- [Taralli: Improving LLM Food Tracking via Few-Shot Learning](https://www.zenml.io/llmops-database/improving-llm-food-tracking-accuracy-through-systematic-evaluation-and-few-shot-learning) — zero-shot 25% → few-shot 76%
- [PMC12513282: LLMs for Nutritional Content Estimation](https://pmc.ncbi.nlm.nih.gov/articles/PMC12513282/) — Claude accuracy benchmarks
- [Claude Structured Outputs Docs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)

### Linear
- [DMNC-558](https://linear.app/lizomorf/issue/DMNC-558) — This issue
- [DMNC-553](https://linear.app/lizomorf/issue/DMNC-553) — Editable AI results (prerequisite, done)
- [DMNC-560](https://linear.app/lizomorf/issue/DMNC-560) — Conversational follow-up (future)

### Internal References
- `App/Modules/Claude/ClaudeService.swift` — photo analysis + prompt building pattern
- `App/Modules/Claude/ClaudeMiddleware.swift` — `.analyzeFood` handler to mirror
- `App/Views/AddViews/UnifiedFoodEntryView.swift` — `actionsSection` for "Ask AI" row
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — staging plate (no changes needed)
- `docs/solutions/security-issues/xml-injection-ai-prompt-context-20260318.md`
- `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md`

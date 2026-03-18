---
title: "feat: Editable AI Food Results + Learning from Corrections"
type: feat
status: completed
date: 2026-03-18
deepened: 2026-03-18
---

# Editable AI Food Results + Learning from Corrections

## Enhancement Summary

**Deepened on:** 2026-03-18
**Research agents used:** architecture-strategist, data-integrity-guardian, security-sentinel, performance-oracle, code-simplicity-reviewer, learnings-analyzer, prompt-engineering-researcher, swiftui-patterns-researcher

### Key Improvements
1. **Fixed action dispatch race condition** — view dispatches single `.saveMealWithCorrections` action; middleware chains to `.addMealEntry`
2. **XML-structured prompt format** — research shows XML tags + `<lesson>` fields dramatically improve Claude's correction adherence
3. **Custom expand/collapse over DisclosureGroup** — iOS 15 DisclosureGroup has animation bugs with dynamic ForEach; manual `isExpanded` is more reliable
4. **Sanitize food names before prompt injection** — strip newlines, cap at 100 chars to prevent prompt manipulation
5. **Use `asyncWrite` for all new GRDB writes** — existing codebase uses synchronous `write` on main thread; new code should not replicate this pattern

### Institutional Learnings Applied
- New middleware must handle `.setAppState(.active)` to trigger initial data load (from `appstate-inactive-blocks-data-loading-20260317`)
- View creates UUIDs, not middleware (from `redux-undo-uuid-mismatch-middleware-creates-object-20260315`)
- Reducer runs before middleware — don't guard on state changed by same dispatch (from `middleware-race-condition-guard-blocks-api-call-Claude-20260313`)
- Suppress food-related actions from log middleware for privacy (from `redux-action-secret-leakage-keychain-side-channel`)

---

## Overview

Make AI food photo results fully editable at the per-item level, and build a learning system where user corrections improve future AI accuracy. Currently the AI returns individual food items but they're read-only — users can only edit aggregate totals. This means you can't fix "marmalade jam" to "butter" without overwriting the entire description and manually recalculating nutrition.

## Problem Statement

1. **No per-item editing**: AI returns `NutritionItem[]` with name, carbs, protein, fat, etc., but `FoodPhotoAnalysisView` only renders them as read-only tags. User can edit aggregate totals but can't fix individual ingredients.
2. **No learning**: The Claude prompt is static (`ClaudeService.buildPrompt`). The AI makes the same mistakes on repeat foods. No correction history is stored or fed back.
3. **Can't add/remove items**: If the AI hallucinates an ingredient or misses one, there's no way to fix the item list — only override the totals.

## Proposed Solution

### A. Per-Item Editing — Staging Plate Pattern

Adopt the **staging plate pattern** (see `docs/references/staging-plate-pattern.md`) for the AI results screen. Instead of read-only item tags with separate editable totals, the AI items land on a "plate" — a staging area where the user builds and corrects their meal before logging.

**Plate layout** (replaces current results sections):
1. **Nutrition banner** (top) — running totals for carbs, protein, fat, calories, auto-computed from plate items. Tappable to override manually.
2. **Plate items** (main list) — each AI-identified food as an editable row:
   - Tap row → inline expand with editable name + carbs fields (NOT a sheet — nested sheet constraint)
   - Swipe-to-delete removes wrong items, totals recalculate
   - Macro tags (carbs, protein, fat) shown inline per item
3. **"+ Add Item"** button at bottom — inline row with text field + carb field for missing foods
4. **Description + timestamp** — editable meal description and time picker (existing)
5. **Confidence + disclaimer** — read-only (existing)
6. **"Log Meal"** button — commits the plate as a single MealEntry

**Key behaviors**:
- Auto-recalculate: use a **computed property** (not `.onChange`) — `items.reduce(0) { $0 + $1.carbsG }`. Computed properties naturally recompute when `@State` mutates.
- Manual override: tapping the nutrition banner allows direct total editing (overrides auto-calc)
- Plate state is ephemeral `@State` — not persisted, cleared on save or cancel

#### Research Insights: SwiftUI Inline Editing (iOS 15+)

**Use custom expand/collapse, NOT DisclosureGroup:**
- DisclosureGroup has known iOS 15 bugs: animation breaks when items are inserted/removed from surrounding ForEach while groups are expanded (Apple Forums thread/681275)
- Cannot suppress the default chevron without custom `DisclosureGroupStyle`
- Instead: add `isExpanded: Bool` to the editable item struct, use `if item.isExpanded { ... }` with `withAnimation(.linear(duration: 0.2))`

**ForEach binding pattern:**
```swift
@State private var stagedItems: [EditableFoodItem] = []
ForEach($stagedItems) { $item in
    FoodItemRow(item: $item)
}
```
- `EditableFoodItem` must be `Identifiable` with stable `UUID` — never use index-based identity
- This Xcode 13 binding syntax is backward-compatible to iOS 13

**Inline add with focus:**
```swift
@FocusState private var focusedField: UUID?

func addItem() {
    let newItem = EditableFoodItem(name: "", carbsG: 0, isExpanded: true)
    stagedItems.append(newItem)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        focusedField = newItem.id
    }
}
```

**Safe deletion:**
```swift
.onDelete { offsets in
    focusedField = nil  // dismiss keyboard BEFORE removing
    stagedItems.remove(atOffsets: offsets)
}
```

**State management**: Keep editable items in local `@State` array in the view (not DirectState). On save, the view computes corrections by comparing the edited items to the original `NutritionEstimate` (available via `store.state.foodAnalysisResult`), then dispatches a **single action** `.saveMealWithCorrections(meal:, corrections:)`. The middleware writes corrections, upserts personal foods, then emits `.addMealEntry` — guaranteeing correct ordering through the middleware chain (not two sequential dispatches from the view, which would race).

### B. Correction Log (GRDB)

New `FoodCorrection` table to record what the AI got wrong:

```swift
struct FoodCorrection: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let correctionType: CorrectionType
    let originalName: String?           // AI's name (nil for additions)
    let correctedName: String?          // User's name (nil for deletions)
    let originalCarbsG: Double?
    let correctedCarbsG: Double?

    enum CorrectionType: String, Codable, DatabaseValueConvertible {
        case nameChange  = "name_change"
        case carbChange  = "carb_change"
        case deleted     = "deleted"
        case added       = "added"
    }
}
```

#### Research Insights: Data Integrity

- **Stable raw values**: Use explicit string raw values (`"name_change"` not `nameChange`) so renaming a Swift case never breaks historical data reads
- **No `timegroup` column**: Unlike MealEntry/SensorGlucose, corrections have no chart consumer. Query on `timestamp` directly. (FavoriteFood also has no timegroup.)
- **CHECK constraints**: Use raw SQL for table creation to enforce field validity per correction type (e.g., `carb_change` requires both carb fields non-null)
- **Atomic writes**: Correction batch + PersonalFood upserts must share one `dbQueue.write` transaction

**Trigger**: On save, compare final editable items array to original `NutritionEstimate.items`. Any differences create correction records. Cancelled sessions discard corrections.

### C. Personal Food Dictionary (GRDB)

New `PersonalFood` table — curated from corrections over time:

```swift
struct PersonalFood: Codable, Identifiable {
    let id: UUID
    let name: String              // Canonical name (user's preferred term)
    let carbsG: Double
    let lastUsed: Date
}
```

#### Research Insights: Upsert Strategy

- **UNIQUE INDEX with COLLATE NOCASE** required on `name` — without it, "apple" and "Apple" coexist as duplicates
- **Manual upsert** (not `INSERT OR REPLACE`): query by name first, UPDATE if exists (preserving UUID), INSERT if new. `INSERT OR REPLACE` on a unique index deletes the old row and creates a new UUID.
```swift
func upsertPersonalFood(_ food: PersonalFood, in db: Database) throws {
    if let existing = try PersonalFood
        .filter(sql: "name = ? COLLATE NOCASE", arguments: [food.name])
        .fetchOne(db) {
        try db.execute(sql: "UPDATE PersonalFood SET carbsG = ?, lastUsed = ? WHERE id = ?",
                       arguments: [food.carbsG, food.lastUsed, existing.id.uuidString.uppercased()])
    } else {
        try food.insert(db)
    }
}
```

**Population**: When a correction is saved:
- `nameChange` → upsert PersonalFood with corrected name
- `carbChange` → upsert PersonalFood with corrected carbs (most recent wins)
- `added` → upsert PersonalFood with the added item's values
- `deleted` → no dictionary entry (but correction log records the hallucination)

**Deduplication**: Case-insensitive via UNIQUE INDEX COLLATE NOCASE.

**Pruning** (runs on `.startup`, not on save path):
1. Delete entries where `lastUsed < now - 90 days`
2. If count > 200, delete oldest by `lastUsed` to bring to 200
Both steps in one `asyncWrite` transaction.

### D. Prompt Injection (AI Learning)

#### Research Insights: Prompt Engineering

**Use XML-structured format** — Anthropic's guidance (2026) recommends XML tags for structured context injection. This outperforms key-value lists because Claude is trained to parse XML structure.

**Optimal injection counts** (research consensus): 8-12 dictionary entries + 5-7 corrections. Performance peaks at ~5-8 few-shot examples then plateaus; beyond 10-15 examples quality can degrade (especially on Haiku-class models). The SQL `LIMIT` on the query is sufficient — no in-code token counting needed.

**Prompt format:**
```xml
<user_food_dictionary>
These are this user's confirmed foods. Use these exact values when identified:
- butter: 0g carbs, 11g fat per tbsp
- sourdough toast: 18g carbs per slice
</user_food_dictionary>

<user_corrections>
This user has corrected these misidentifications:
<example>
  <ai_said>marmalade jam</ai_said>
  <user_corrected>butter</user_corrected>
  <lesson>Shiny yellow spread on toast in this user's photos is butter, not jam</lesson>
</example>
</user_corrections>

<items_not_present>
Do not include these items unless you see unmistakable visual evidence:
<excluded_item>
  <name>syrup</name>
  <reason>User does not use syrup. Yellow liquids are butter or olive oil.</reason>
</excluded_item>
</items_not_present>
```

**Key principles:**
- The `<lesson>` field helps Claude generalize ("shiny yellow spread = butter") rather than just memorizing one correction
- Frame negatives as positive constraints ("identify as X instead") — bare "never include Y" is less effective
- Limit to 3-5 hard exclusions maximum
- Sanitize food names before interpolation: strip `\n`/`\r`, cap at 100 chars, validate carb values are in 0-500g range

**Extend `buildPrompt()` signature** to accept lightweight plain structs (not GRDB model types) to keep `ClaudeService` testable without a database:
```swift
func buildPrompt(thumbWidthMM: Double?, personalFoods: [PersonalFoodSummary], recentCorrections: [CorrectionSummary]) -> String
```

## Technical Considerations

### Architecture Impact

| Component | Change |
|-----------|--------|
| `NutritionEstimate.swift` | No change — items already mutable (`var`) |
| `FoodPhotoAnalysisView.swift` | Major rewrite of items section → staging plate with editable list |
| `ClaudeService.swift` | `buildPrompt()` accepts personal foods + corrections as lightweight structs |
| `ClaudeMiddleware.swift` | Reads `state.personalFoodValues` + `state.recentFoodCorrections` — NO direct GRDB access |
| `DirectAction.swift` | New actions: `saveMealWithCorrections`, `loadPersonalFoods`, `setPersonalFoods`, `setRecentFoodCorrections` |
| `DirectReducer.swift` | New reducer cases for personal foods + recent corrections |
| `DirectState.swift` / `AppState.swift` | New `personalFoodValues: [PersonalFood]`, `recentFoodCorrections: [FoodCorrection]` |
| New: `FoodCorrectionStore.swift` | GRDB middleware — handles save, upsert PersonalFood directly via DataStore, loads corrections |
| New: `FoodCorrection.swift` | Model in `Library/Content/` |
| New: `PersonalFood.swift` | Model in `Library/Content/` |
| `DataStore.swift` | New `FetchableRecord`/`PersistableRecord` extensions for both models |
| `App.swift` | **Both** `createAppStore()` and `createSimulatorAppStore()` must register new middleware |
| `Log.swift` | Suppress `.saveMealWithCorrections`, `.setPersonalFoods`, `.setRecentFoodCorrections` from logs (privacy) |

### Architecture Decisions (from research)

1. **Single dispatch from view**: View dispatches `.saveMealWithCorrections(meal: MealEntry, corrections: [FoodCorrection])`. `FoodCorrectionStore` handles this action → writes corrections + upserts PersonalFood in one GRDB transaction → emits `.addMealEntry(mealEntryValues: [meal])`. This guarantees correct sequencing through the middleware chain. **Do NOT dispatch two actions sequentially from the view** — this creates a race condition.

2. **No intermediate relay actions**: Drop `.updatePersonalFoods`. The `FoodCorrectionStore` calls `DataStore.shared.upsertPersonalFood()` directly (same pattern as `favoriteFoodStoreMiddleware` calling `updateFavoriteFoodLastUsed` directly). One middleware handles the full write path.

3. **ClaudeMiddleware reads from DirectState, not GRDB**: `personalFoodValues` and `recentFoodCorrections` are GRDB-backed arrays loaded into DirectState (3-file pattern: DirectState protocol, AppState default `= []`, DirectReducer case). `ClaudeMiddleware` reads `state.personalFoodValues` — preserving the existing boundary where DataStore middlewares own GRDB and other middlewares read state.

4. **PersonalFood is distinct from FavoriteFood**: PersonalFood is AI-observed, auto-populated from corrections, never user-editable. FavoriteFood is user-managed with sortOrder, isHypoTreatment, and manual CRUD. They serve different roles: PersonalFood feeds AI prompts, FavoriteFood feeds the quick-log UI.

### Nested Sheet Constraint

`FoodPhotoAnalysisView` is presented via NavigationLink (not a sheet) from `UnifiedFoodEntryView`. Per-item editing must use **custom inline expansion** (manual `isExpanded` toggle), NOT sheets, alerts, or DisclosureGroup.

### Cross-Middleware Listening

- `FoodCorrectionStore` handles `.saveMealWithCorrections` → writes corrections + upserts PersonalFood in one atomic `asyncWrite` transaction → emits `.addMealEntry`
- `FoodCorrectionStore` handles `.startup` → creates tables, loads recent corrections into state, triggers PersonalFood load
- `FoodCorrectionStore` handles `.setAppState(.active)` → reloads recent corrections (required per `appstate-inactive-blocks-data-loading` learning)
- `ClaudeMiddleware` handles `.analyzeFood` → reads `state.personalFoodValues` + `state.recentFoodCorrections` → passes to `buildPrompt()`

### Performance

- **Use `asyncWrite` for all new GRDB writes** — does not block main thread. The existing codebase uses synchronous `write` (a pre-existing issue); new code should not replicate this.
- **Add index** on `PersonalFood.lastUsed` and `FoodCorrection.timestamp` during table creation
- **Pre-API GRDB queries**: data is pre-loaded into DirectState; ClaudeMiddleware reads from state (~0ms), not from GRDB at call time
- **Pruning runs on `.startup`** in its own `asyncWrite` — not on the save path or analysis path
- Prompt size increase: ~300-500 tokens (XML format) — negligible cost on Haiku, well within 200K context window

## System-Wide Impact

- **Interaction graph**: `saveAnalysis()` → `.saveMealWithCorrections(meal:, corrections:)` → `foodCorrectionStoreMiddleware` (atomic: correction log + PersonalFood upsert + prune) → emits `.addMealEntry` → `mealEntryStoreMiddleware` (DB write) + `favoriteFoodStoreMiddleware` (recents update)
- **Error propagation**: Correction write failures should be silent (log error, still emit `.addMealEntry`). Meal save is the critical path.
- **State lifecycle risks**: Original `NutritionEstimate` must be preserved in view state until save completes. If the view is dismissed before save, corrections are discarded (acceptable).
- **API surface parity**: No other interfaces need updating — this is entirely within the photo analysis flow.
- **Privacy**: Suppress food-related actions from `logMiddleware` — meal descriptions and correction data are health-adjacent PII. Update `AIConsentView` disclosure to mention that food preferences are included in prompts.

## Acceptance Criteria

- [x] **Per-item name editing**: Tap item row → inline expand with text field for name
- [x] **Per-item carb editing**: Inline number field for carbs per item
- [x] **Delete items**: Swipe-to-delete removes item, totals recalculate
- [x] **Add items**: "Add Item" button creates new inline row with focus on name field
- [x] **Auto-recalculate**: Changing any item's carbs updates the nutrition banner totals
- [x] **Manual override**: Tapping nutrition banner allows direct total editing
- [x] **Corrections logged**: On save, differences between AI result and final edits stored in `FoodCorrection` table
- [x] **Dictionary populated**: Corrections automatically upsert `PersonalFood` entries (atomic transaction)
- [x] **AI uses context**: Future photo analyses include personal dictionary + corrections in XML-structured prompt
- [x] **Prompt size bounded**: Max 12 dictionary entries + 7 corrections (SQL LIMIT, no in-code token counting)
- [x] **No nested sheets**: All editing is custom inline expand — no sheet-from-sheet presentations
- [x] **Privacy**: Food actions suppressed from log middleware; AI consent disclosure updated
- [x] **Both middleware arrays updated**: `createAppStore()` and `createSimulatorAppStore()` in `App.swift`
- [x] **Builds on simulator**: `xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator build`

## Success Metrics

- User can correct "marmalade jam" → "butter" at the item level without touching aggregate totals
- After 5+ corrections, the AI correctly identifies frequently-eaten foods
- Personal food dictionary grows automatically from natural usage
- No increase in meal logging time (editing is optional, not required)

## Dependencies & Risks

| Risk | Mitigation |
|------|------------|
| Prompt injection via food names | Sanitize: strip newlines, cap 100 chars, validate numeric ranges. Structured JSON output mode is a hard barrier regardless. |
| Dictionary grows unbounded | Prune on startup: >90 days unused → delete; cap at 200 entries |
| Conflicting corrections (same food, different carbs) | Most-recent-wins upsert strategy |
| Few-shot examples degrade Haiku output quality | Research shows saturation at 5-8 examples; limit to 7 corrections + 12 dictionary entries |
| New GRDB tables need pbxproj entries | 2 new model files + 1 new store file = 6 pbxproj sections to add manually |
| iOS 15 DisclosureGroup animation bugs | Use custom expand/collapse with `isExpanded` bool instead |
| PersonalFood vs FavoriteFood confusion | Document distinction: PersonalFood = AI-observed, auto-populated; FavoriteFood = user-managed, manual CRUD |

## New Files

| File | Target | Purpose |
|------|--------|---------|
| `Library/Content/FoodCorrection.swift` | Library | Correction model (with CorrectionType enum) |
| `Library/Content/PersonalFood.swift` | Library | Dictionary model |
| `App/Modules/DataStore/FoodCorrectionStore.swift` | App | Single middleware: handles save, PersonalFood upsert, load, prune |

## Sources & References

### Linear Issues
- [DMNC-427](https://linear.app/lizomorf/issue/DMNC-427) — Phase 3: AI-Powered Food Analysis (Done)
- [DMNC-532](https://linear.app/lizomorf/issue/DMNC-532) — Food Logging UX Overhaul (Done) — references future Phase 7 "Smart suggestions + meal templates"
- [DMNC-527](https://linear.app/lizomorf/issue/DMNC-527) — Portion size estimation helper (Done, thumb calibration shipped)

### Internal References
- `App/Modules/Claude/ClaudeService.swift` — prompt construction + API call
- `App/Views/AddViews/FoodPhotoAnalysisView.swift` — results UI (main file to modify)
- `Library/Content/NutritionEstimate.swift` — AI response model
- `App/Modules/DataStore/FavoriteStore.swift` — pattern for GRDB middleware + direct DataStore calls
- `docs/references/staging-plate-pattern.md` — staging plate UX pattern
- `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md` — middleware must handle `.setAppState(.active)`
- `docs/solutions/logic-errors/redux-undo-uuid-mismatch-middleware-creates-object-20260315.md` — view creates UUIDs
- `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md` — reducer timing
- `docs/solutions/security-issues/redux-action-secret-leakage-keychain-side-channel.md` — suppress from logs
- `docs/solutions/ui-bugs/swiftui-nested-sheets-present-wrong-view-20260316.md` — no nested sheets

### External References
- [Anthropic: Multishot Prompting Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/multishot-prompting)
- [Anthropic: Structured Outputs Documentation](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [The Few-shot Dilemma (arxiv 2509.13196)](https://arxiv.org/abs/2509.13196) — few-shot saturation research
- [SwiftUI List Bindings — Peter Friese](https://peterfriese.dev/blog/2021/swiftui-list-item-bindings-behind-the-scenes/)
- [Managing Focus in SwiftUI Lists — Peter Friese](https://peterfriese.dev/blog/2021/swiftui-list-focus/)

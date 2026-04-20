---
date: 2026-04-19
topic: daily-digest
---

# Daily Digest — End-of-Day Summary with AI Insight

## Problem Frame

The app monitors glucose all day but never summarizes. A user finishing their day has no "how did today go?" signal — they must mentally reconstruct events from the chart. This makes it hard to spot patterns, evaluate decisions, or know what to adjust tomorrow.

## Requirements

### R1. Dedicated Digest tab

Add a fourth tab to the tab bar: **Overview > Lists > Settings > Digest**.

- SF Symbol icon (e.g. `doc.text.magnifyingglass`), label "Digest"
- New `DirectConfig.digestViewTag = 5`
- DOS amber CGA styling consistent with existing tabs

### R2. Stats grid (2x3)

Six metric tiles in a 2-column, 3-row grid:

| Tile | Source | Color logic |
|------|--------|-------------|
| TIR % | GlucoseStatistics.tir | Green if >= 70%, amber if 50-69%, red if < 50% |
| Lows count | Filter sensorGlucoseValues < alarmLow | Red if > 0, green if 0 |
| Highs count | Filter sensorGlucoseValues > alarmHigh | Yellow if > 0, green if 0 |
| Avg glucose | GlucoseStatistics.avg | Neutral amber |
| Total carbs | Sum mealEntryValues.carbsGrams | Neutral amber |
| Total insulin | Sum insulinDeliveryValues.units | Neutral amber |

### R3. AI insight card

A cyan-bordered card below the stats grid containing an adaptive-length AI-generated insight.

**Adaptive length:** One sentence if the day was unremarkable; 2-4 sentences if there are patterns worth discussing. The AI decides based on content.

**Input context (full):**
- Today's stats (TIR, avg, lows, highs, carbs, insulin, exercise)
- Timestamped event timeline (meals with carbs, insulin with type/units, exercise with duration)
- Glucose curve sampled at 30-minute intervals (~48 data points)
- IOB at key moments (meal times, lows)
- Treatment events if any occurred
- Last 7 days' cached digest summaries (stats + insight text) for cross-day trend spotting

**System prompt rules:**
- Reference specific times and values (e.g., "the 65g dinner at 21:12")
- Call out recurring patterns from past digests (e.g., "third evening high this week")
- Focus on actionable observations: timing, dosing, meal composition
- Never give medical advice — frame as observations to discuss with care team
- Be direct, no greetings or filler

**Model:** Claude Haiku 4.5 (same as food analysis). Plain text output (no JSON schema).

**Token budget:** ~800-1200 input, ~200 output.

### R4. Event timeline

Chronological list of the day's events below the AI insight card. Color-coded:
- Meals: amber (`#ffb000`) — show description + carbs
- Insulin: cyan (`#55ffff`) — show units + type
- Exercise: green (`#55ff55`) — show activity + duration

### R5. Date navigation

Date bar at the top: `< SAT APR 19 >`. Tap arrows to browse history. Today is the default. Future dates disabled.

Changing the date loads the cached digest for that day, or generates a new one if none exists.

### R6. Persistent storage (GRDB)

New `DailyDigest` table — one row per calendar day:

```swift
struct DailyDigest: Codable, Identifiable {
    let id: UUID
    let date: Date              // start of day (unique)
    let tir: Double
    let tbr: Double
    let tar: Double
    let avg: Double
    let stdev: Double
    let readings: Int
    let lowCount: Int
    let highCount: Int
    let totalCarbsGrams: Double
    let totalInsulinUnits: Double
    let totalExerciseMinutes: Double
    let mealCount: Int
    let insulinCount: Int
    let aiInsight: String?      // nil until AI generates
    let generatedAt: Date?      // when AI was called
}
```

Digest is regeneratable from raw data. "Refresh" button re-generates the AI insight for the current day.

### R7. Separate AI consent

New setting: `aiConsentDailyDigest: Bool` (UserDefaults-backed). Independent from `aiConsentFoodPhoto`. Toggle in Settings under an AI section.

### R8. Loading states

- Stats: computed from GRDB, fast. Show immediately or brief spinner.
- AI insight: pulsing "Analyzing..." placeholder while API call runs.
- No API key or consent not given: stats show normally, AI card shows "Enable AI Insights in Settings".
- API failure: "Insight unavailable — tap to retry". No error popups.

## Architecture

### Redux flow

**Actions:**
- `.loadDailyDigest(date: Date)` — triggered on tab appear or date change
- `.setDailyDigest(digest: DailyDigest)` — reducer stores result
- `.generateDailyDigestInsight(date: Date)` — triggers Claude API call
- `.setDailyDigestInsight(date: Date, insight: String)` — updates cached digest
- `.refreshDailyDigestInsight(date: Date)` — force re-generate

**State:**
- `currentDailyDigest: DailyDigest?`
- `dailyDigestLoading: Bool`
- `dailyDigestInsightLoading: Bool`
- `aiConsentDailyDigest: Bool` (UserDefaults)

**Middleware flow:**
1. On `.loadDailyDigest(date)`:
   - Check GRDB for cached digest
   - If cached → dispatch `.setDailyDigest`
   - If not cached:
     a. Query glucose readings for the day → compute stats + low/high counts
     b. Query meals, insulin, exercise for the day
     c. Build `DailyDigest` (no insight yet), save to GRDB, dispatch `.setDailyDigest`
     d. If consent + API key → dispatch `.generateDailyDigestInsight(date)`
2. On `.generateDailyDigestInsight(date)`:
   - Query last 7 cached digests
   - Sample glucose at 30-min intervals
   - Build prompt, call ClaudeService
   - On success → dispatch `.setDailyDigestInsight`, update GRDB row
   - On failure → set insight to nil, loading to false

### New files

| File | Purpose |
|------|---------|
| `Library/Content/DailyDigest.swift` | Model + GRDB Columns enum |
| `App/Modules/DataStore/DailyDigestStore.swift` | GRDB table creation, queries |
| `App/Modules/DailyDigest/DailyDigestMiddleware.swift` | Stats computation + AI orchestration |
| `App/Views/DigestView.swift` | Main digest tab view |

### Existing files to modify

| File | Change |
|------|--------|
| `Library/DirectAction.swift` | Add digest actions |
| `Library/DirectState.swift` | Add digest state properties |
| `App/AppState.swift` | Add digest state with UserDefaults for consent |
| `Library/DirectReducer.swift` | Handle digest actions |
| `App/App.swift` | Add middleware to both arrays, add tab |
| `Library/Extensions/UserDefaults.swift` | Add consent key |
| `App/Modules/Claude/ClaudeService.swift` | Add `generateDailyInsight()` method |
| `App/Views/Settings/` | Add AI consent toggle for daily digest |

## Scope Boundaries

**In scope:**
- Stats computation from existing data stores
- AI insight with full context + cross-day trend references
- GRDB persistence for history browsing
- Date navigation for past days
- Refresh button for re-generating insight
- Separate AI consent toggle

**Out of scope (deferred to AI Health Companion):**
- Conversational follow-up (asking the AI questions)
- Health journal entries (illness, stress, etc.)
- Memory across sessions beyond cached digest summaries
- Push notifications for digest availability
- Weekly/monthly aggregate summaries

## Future: AI Health Companion

The daily digest lays groundwork for a larger AI Health Companion feature:
- Conversation mode: ask follow-up questions about the day's data
- Health journal: log illness, stress, sleep quality, menstrual cycle — context that affects glucose
- Persistent memory: AI remembers patterns and user preferences across days
- Proactive suggestions: "You usually go high on Fridays — pizza night?"

This will be brainstormed and designed as a separate feature.

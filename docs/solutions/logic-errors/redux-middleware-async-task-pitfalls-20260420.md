---
title: Redux Middleware Async Task Pitfalls — Stale State and Sentinel Values
date: 2026-04-20
category: logic-errors
module: DailyDigest, Redux middleware
problem_type: logic_error
component: tooling
symptoms:
  - AI insight generated with zero-stats digest when user navigates dates quickly
  - Infinite retry loop for AI insight on past days after API failure
root_cause: architecture_misuse
resolution_type: refactor
severity: high
tags: [redux, middleware, async, state-snapshot, combine, future, sentinel-value]
---

# Redux Middleware Async Task Pitfalls — Stale State and Sentinel Values

## Problem

Two related bugs in `DailyDigestMiddleware` caused by misunderstanding how Redux state snapshots interact with async `Task` blocks inside Combine `Future` publishers.

## Symptoms

1. **Stale state snapshot**: When user rapidly navigated dates (Apr 19 → 18 → 17), the AI insight for the newest date was sometimes generated with zero stats because the middleware read `state.currentDailyDigest` inside an async `Task` — by the time the Task body executed, the state had been updated by a subsequent date navigation.

2. **Infinite retry loop**: When AI insight generation failed (API error), the catch block dispatched `.setDailyDigestInsight(date:, insight: "")`. The empty string was written to Redux state but NOT to GRDB cache. On next visit to that date, GRDB returned `nil` for `aiInsight`, triggering the `setDailyDigestEvents` handler to re-dispatch `generateDailyDigestInsight` — which failed again, creating an infinite loop.

## What Didn't Work

- The initial implementation used `state.currentDailyDigest` inside the `Task` closure, assuming it would reflect the current state. It reflected the state at dispatch time (before async hops).
- Using an empty string `""` as a sentinel for "no insight" conflated "failed to generate" with "not yet generated" (`nil`).

## Solution

**Fix 1 — Stale state**: Fetch the digest from GRDB inside the Task instead of reading the stale `state` snapshot:

```swift
// Before (broken): reads stale state snapshot
let digest = state.currentDailyDigest ?? fallback

// After (fixed): fetch fresh from GRDB
let digest: DailyDigest
if let cached = try? await DataStore.shared.getDailyDigest(date: date).asyncValue() {
    digest = cached
} else {
    digest = fallback
}
```

**Fix 2 — Sentinel value**: Replace the empty-string sentinel with a dedicated error action:

```swift
// Before (broken): empty string triggers infinite retry
promise(.success(.setDailyDigestInsight(date: date, insight: "")))

// After (fixed): dedicated error action only clears loading flag
promise(.success(.setDailyDigestInsightError))
```

The reducer for `.setDailyDigestInsightError` sets `dailyDigestInsightLoading = false` without touching `aiInsight`, so the view shows "tap to retry" but the `setDailyDigestEvents` handler's `digest.aiInsight == nil` check doesn't auto-trigger a new generation attempt (the retry only fires on explicit user tap via `force: true`).

## Why This Works

1. **State snapshots are frozen at dispatch time.** The `state` parameter in a Redux middleware closure is captured when `Store.dispatch()` calls the middleware — before any async work begins. Any `await` inside a `Task` may yield for an arbitrary duration, during which new actions can mutate state. Reading `state` after an `await` reads the old snapshot, not current state. GRDB is the source of truth for persisted data.

2. **Sentinel values conflate distinct states.** An empty string for "failed" and `nil` for "not yet generated" look different to the developer but trigger the same downstream behavior (the middleware checks `aiInsight == nil` to decide whether to auto-generate). A dedicated error action keeps the two states distinct: `nil` = "should generate", `error flag` = "tried and failed, wait for explicit retry".

## Prevention

- **Never read `state` inside a `Task` block in middleware.** If you need current data after an `await`, fetch it from GRDB or another source of truth — not the stale closure parameter.
- **Never use sentinel values (empty strings, magic numbers) to represent error states.** Create dedicated error actions that the reducer handles independently.
- **For auto-trigger chains (action A triggers B triggers C), map the full state machine** including error paths before implementation. Ask: "if C fails, does A or B re-trigger C? Is that intentional?"

## Related Issues

- `docs/solutions/logic-errors/middleware-race-condition-guard-blocks-api-call-Claude-20260313.md` — related reducer-before-middleware timing issue
- `docs/solutions/logic-errors/grdb-write-inside-asyncread-deadlock-20260420.md` — another GRDB/async interaction bug from the same feature
- `docs/solutions/logic-errors/combine-future-async-bridge-double-resume-20260420.md` — another Combine/async bridge bug from the same feature

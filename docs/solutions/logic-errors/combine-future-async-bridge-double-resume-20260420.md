---
date: 2026-04-20
module: DailyDigest
tags: [combine, future, async-await, continuation, crash]
problem_type: logic-error
severity: high
---

# Combine Future-to-Async Bridge Double Resume Crash

## Problem

A `withCheckedThrowingContinuation` bridge over a Combine `Future` crashes with `SWIFT_CONTINUATION_MISUSE` because `continuation.resume` is called twice — once when the Future emits its value and again when it completes.

## Trigger

The `asyncValue()` helper on `Future` subscribed via `.sink(receiveCompletion:receiveValue:)`. A `Future` emits exactly one value then immediately completes with `.finished`. Both callbacks fire, and both called `continuation.resume`.

## Root Cause

Combine's `Future` is a single-value publisher. When it resolves:
1. `receiveValue` fires → `continuation.resume(returning: value)` ✓
2. `receiveCompletion(.finished)` fires immediately after → no-op in the handler, BUT if the completion handler also tried to resume (e.g., on `.failure`), the structure is fragile

The actual crash happened because `receiveValue` resumed, then `receiveCompletion(.finished)` ran but the continuation was already consumed. With `withCheckedThrowingContinuation`, any double-resume is a fatal error.

## Fix

Add a `resumed` flag to ensure `resume` is called exactly once:

```swift
var resumed = false
cancellable = self.sink(
    receiveCompletion: { completion in
        guard !resumed else { cancellable?.cancel(); return }
        if case .failure(let error) = completion {
            resumed = true
            continuation.resume(throwing: error)
        }
        cancellable?.cancel()
    },
    receiveValue: { value in
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: value)
    }
)
```

## Prevention

- When bridging Combine publishers to async/await, always use a `resumed` guard flag.
- Prefer `withCheckedContinuation` (checked) over `withUnsafeContinuation` (unsafe) during development — the checked variant crashes immediately on double-resume rather than causing undefined behavior.
- Consider using `AsyncStream` for multi-value publishers instead of continuation-based bridges.

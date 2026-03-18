---
title: "Dangling Future when dbQueue is nil hangs Combine subscriber indefinitely"
date: 2026-03-18
category: logic-errors
severity: high
component: DataStore
tags: [grdb, combine, future, async, data-store]
symptoms:
  - Middleware that depends on a DataStore fetch never emits a result action
  - Combine chain silently stalls — no error, no value, no timeout
  - Feature appears broken after first install or when database initialisation is delayed
root_cause: Every DataStore Future-returning method guards on dbQueue != nil but never calls promise on the else path, causing the Future to hang indefinitely
files_modified:
  - App/Modules/DataStore/FoodCorrectionStore.swift
---

# Dangling Future when dbQueue is nil

## Problem

GRDB DataStore methods return a `Future<[T], DirectError>` that wraps database reads inside `dbQueue.asyncRead`. If `dbQueue` is nil, the promise is never called:

```swift
func getSomething() -> Future<[Something], DirectError> {
    return Future { promise in
        if let dbQueue = self.dbQueue {
            dbQueue.asyncRead { ... promise(.success(result)) ... }
        }
        // No else: promise is never resolved → subscriber hangs forever
    }
}
```

This is a systemic pattern across ALL `*Store.swift` files in the codebase.

## Fix

Add an `else` branch that resolves with an empty success:

```swift
if let dbQueue = self.dbQueue {
    dbQueue.asyncRead { ... }
} else {
    promise(.success([]))
}
```

## Prevention

Every early-exit path inside a `Future` closure that doesn't call `promise(...)` is a bug. Treat any `return` before `promise` as a red flag.

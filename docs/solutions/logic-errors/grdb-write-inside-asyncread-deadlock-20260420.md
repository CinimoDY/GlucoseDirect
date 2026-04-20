---
date: 2026-04-20
module: DataStore
tags: [grdb, deadlock, asyncRead, DatabaseQueue]
problem_type: logic-error
severity: critical
---

# GRDB Write Inside asyncRead Causes Deadlock

## Problem

Calling a synchronous `dbQueue.write { }` from inside a `dbQueue.asyncRead { }` callback deadlocks the app. `DatabaseQueue` serializes all database access on the same internal dispatch queue. The `asyncRead` callback holds the queue, and the nested `write` waits for the queue to become available — creating a deadlock that the iOS watchdog kills.

## Trigger

`DailyDigestStore.computeDailyDigest()` used `dbQueue.asyncRead` to query glucose, meals, insulin, and exercise data, then called `self.saveDailyDigest(digest)` (which does `dbQueue.write`) from inside the same callback.

## Root Cause

`DatabaseQueue` (not `DatabasePool`) uses a single serial queue for both reads and writes. `asyncRead` dispatches to this queue. A synchronous `write` call from within that dispatch block tries to re-enter the same serial queue, causing a deadlock.

This is different from `DatabasePool`, which allows concurrent reads and serializes writes separately.

## Fix

Move the write operation outside the read callback. In this case, the middleware saves the computed digest after the Future resolves, not inside the database read transaction.

## Prevention

- **Never call `dbQueue.write` from inside `dbQueue.asyncRead` or `dbQueue.read`.**
- If a method needs to both read and compute, return the result via the Future promise and let the caller handle persistence separately.
- If you need read-then-write atomicity, use `dbQueue.asyncWrite` or `dbQueue.write` (which gives both read and write access).
- Code review signal: any DataStore method that calls another DataStore method from inside a `dbQueue.asyncRead` block is suspect.

---
title: "GlucoseDirect inherited-module audit — keep everything; migration is residual"
date: 2026-05-13
category: architecture-patterns
module: App/Modules
problem_type: architecture_pattern
component: tooling
severity: low
applies_when:
  - "Deciding what to do with the 119-ish Swift files inherited from upstream GlucoseDirect at fork time"
  - "Evaluating whether a specific module under App/Modules/ is dead code or active"
  - "Considering removal of legacy Gen1/Gen2 glucose migration in DataStore"
tags: [audit, glucosedirect, sensor-connector, migration, dmnc-386]
---

# GlucoseDirect inherited-module audit — keep everything; migration is residual

## Context

DMNC-386 (filed 2026-03-02, ~2 weeks post-fork from upstream GlucoseDirect) asked for a keep/remove/modify decision per inherited module. Now (2026-05-13) the codebase has had ~2.5 months of incremental cleanup work — DMNC-768 fileSystemSynchronized migration, DMNC-879 IOB-reactivity sweep + deprecation cleanup, DMNC-776/777/778 URL/availability/Localizable sweep, plus per-feature module additions (Claude, DailyDigest, IOB, MealImpact, TreatmentCycle, AppGroupSharing). Time to triage what remains and close the audit.

## Findings

### Top-level modules (`App/Modules/`)

Twenty modules. All registered as middlewares in `App.swift:240` (`createAppStore`) and in active use:

| Module | Registration site | Status |
|--------|-------------------|--------|
| `AppGroupSharing` | `App.swift:269` | KEEP — widget + Live Activity sync |
| `AppleExport` | `App.swift:264` (`appleHealthExportMiddleware`) | KEEP — HealthKit is source of truth per CLAUDE.md |
| `AppleImport` | `App.swift:265` (`appleHealthImportMiddleware`) | KEEP — HealthKit import |
| `AppleCalendarExport` | `App.swift:263` | KEEP — opt-in Calendar export for Watch users |
| `BellmanAlarm` | `App.swift:267` | KEEP — accessibility (deaf/hard-of-hearing) |
| `Claude` | `App.swift:273` | KEEP — AI food analysis + Daily Digest insights |
| `ConnectionNotification` | `App.swift:262` | KEEP |
| `DailyDigest` | `App.swift:252` | KEEP — Digest tab |
| `DataStore` | (many) | KEEP — GRDB persistence layer |
| `Debug` | `App.swift:298` (`isDebug` only) | KEEP — debug-only entry point |
| `ExpiringNotification` | `App.swift:260` | KEEP — sensor end-of-life alarm |
| `GlucoseNotification` | `App.swift:261` | KEEP — alarm pipeline |
| `IOB` | `App.swift:250` | KEEP — insulin-on-board model |
| `Log` | `App.swift:244` | KEEP — DirectLog |
| `MealImpact` | `App.swift:251` | KEEP — meal impact overlay |
| `Nightscout` | `App.swift:268` | KEEP — Nightscout upload still part of T1D ecosystem |
| `ReadAloud` | `App.swift:266` | KEEP — accessibility |
| `ScreenLock` | `App.swift:270` | KEEP — bedside-monitoring use case |
| `SensorConnector` | `App.swift:295` | KEEP — see breakdown below |
| `TreatmentCycle` | `App.swift:258` | KEEP — Rule of 15 workflow |
| `WidgetCenter` | `App.swift:276` | KEEP — Live Activity orchestration |

No removable top-level modules.

### Sensor connection variants (`App/Modules/SensorConnector/LibreConnection/`)

Five files. Every one is referenced via composition or inheritance — no dead code:

| File | Usage |
|------|-------|
| `LibreConnection.swift` (101 lines) | Top-level wrapper registered in `App.swift:282` as the NFC-only Libre 2 entry point |
| `Libre2Connection.swift` (216 lines) | Instantiated as `bluetoothConnection` delegate inside `LibreConnection.swift:94`; subclassed by `LibreLinkConnection` |
| `LibreLinkConnection.swift` (86 lines) | `class LibreLinkConnection: Libre2Connection`. Registered debug-only in `App.swift:292` |
| `LibreLinkUpConnection.swift` (682 lines) | Instantiated as `bluetoothConnection` delegate inside `LibreConnection.swift:96`. Not directly registered in App.swift — accessed through the parent `LibreConnection` |
| `LibreNFC.swift` (365 lines) | NFC pairing helper used by Libre2 path |

`BubbleConnection.swift` (BLE transmitter) registered in `App.swift:283/285/288`. `VirtualConnection.swift` registered for simulator builds (per `AppState.swift` `targetEnvironment(simulator)`).

No removable connection code.

### Migration module — the only residual

`App/Modules/DataStore/Migration.swift` (~200 lines) migrates `Gen1Glucose` / `Gen2Glucose` UserDefaults storage from upstream GlucoseDirect into the current GRDB `SensorGlucose` table. Runs once per install on `.startup`, then becomes a no-op (clears the legacy keys).

The Gen1/Gen2 types are `@available(*, deprecated)` — those four deprecation warnings show up in every build log (see e.g. build 91 deploy output). The warnings are intentional: the types shouldn't be used in new code; the migration is the only legitimate consumer.

**Decision: keep for now.** Risk of removal is narrow (any DOSBTS user who's opened the app since the Feb 2026 rebrand has had the migration run), but non-zero — and the cleanup has no user-visible benefit beyond quieter build logs. Track as a separate low-priority cleanup if/when the build-log noise becomes annoying.

### Settings views (`App/Views/Settings/`)

The original audit asked "Simplify?" — answer: not as a sweep. The settings restructure is tracked separately as **DMNC-794** (Figma-blocked, paired with the in-flight Overview redesign). The Figma work will produce a holistic IA recommendation; piecemeal simplification now would conflict with that.

## Why this matters

The audit asked "what can we remove" and the honest answer two months later is "almost nothing." This is itself the deliverable — future agents (and the user) shouldn't repeat the question. The fork-time fear ("119 files of GlucoseDirect debt") didn't materialize; incremental cleanup absorbed it.

## When to revisit

- A user reports an old-build install that needs Gen1/Gen2 migration — file a focused issue
- The Figma settings redesign (DMNC-794) lands — re-audit `App/Views/Settings/` against the new IA
- A sensor connection family becomes obsolete (e.g., Abbott discontinues Libre 2) — drop the matching connector
- The build-log deprecation noise becomes painful — remove `Migration.swift` + its `dataStoreMigrationMiddleware()` registration in `App.swift:245`

## Related

- `CLAUDE.md` § Project Structure — current module list
- `App/App.swift:240-301` — `createAppStore` — middleware + connection registration
- DMNC-794 — settings restructure, Figma-blocked
- DMNC-768 — fileSystemSynchronized migration (shipped, much of the "what's used" clarity came from that)
- DMNC-879 — IOB reactivity sweep + deprecation cleanup (shipped, build 86)

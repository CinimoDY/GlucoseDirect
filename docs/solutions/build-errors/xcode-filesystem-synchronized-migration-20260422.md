---
title: "Xcode fileSystemSynchronized migration — rewrite-from-template strategy"
date: 2026-04-22
category: build-errors
module: xcode-project-structure
problem_type: build_error
component: tooling
severity: high
symptoms:
  - "Long pbxproj with hundreds of PBXFileReference / PBXBuildFile entries"
  - "Every new Swift file requires manual 4-section pbxproj edits (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase)"
  - "Structural drift between pbxproj groups and filesystem layout over time"
root_cause: incomplete_setup
resolution_type: migration
tags:
  - xcode
  - pbxproj
  - file-system-synchronized
  - migration
---

# Xcode fileSystemSynchronized migration — rewrite-from-template strategy

## Problem

DOSBTS's traditional Xcode project required manual pbxproj edits for every new Swift file (PBXBuildFile, PBXFileReference, PBXGroup children, PBXSourcesBuildPhase — all with unique hex IDs). The pbxproj grew to 2,055 lines. Xcode 16 introduced `fileSystemSynchronized` project groups that obsolete this workflow: any file under a sync-root is picked up automatically.

## Two migration strategies

### Strategy A — Xcode's "Convert to Folder" (DOOMBTS approach)

Use the Project Navigator right-click menu. Requires the pbxproj group structure to exactly mirror the filesystem first. DOOMBTS needed 3 fix-up commits to reconcile years of group/filesystem drift before the convert step succeeded. See the sibling DOOMBTS learning doc at `docs/solutions/build-errors/xcode-filesystem-synchronized-migration-pbxproj-mismatches-20260421.md` for the three error classes and fixes.

### Strategy B — Rewrite pbxproj from template (DOSBTS approach)

Take a working sibling pbxproj as the template, customize by replacing project-specific identifiers (target names, test files, build numbers, xcconfig filenames), and drop in the result. This bypasses the convert-in-place workflow entirely — no need to fix accumulated drift because the rewritten file is structurally clean by construction.

Strategy B is faster and lower-risk when a sibling fileSystemSynchronized pbxproj already exists (e.g. a fork of the same codebase). It requires:

1. A template pbxproj that already uses `fileSystemSynchronized`
2. Matching target structure (same native targets, same package dependencies, same framework links)
3. Matching folder layout (same sync-root folders)

If any of these differ significantly, fall back to Strategy A.

## Customization checklist (Strategy B)

Minimum transformations when cloning a template pbxproj:

- **Project / target / bundle names** — replace every occurrence of the source project name
- **Test target files** — list the actual test `.swift` files in `PBXSourcesBuildPhase` for the test target and in the test `PBXGroup` children (tests are NOT auto-synced under fileSystemSynchronized)
- **CURRENT_PROJECT_VERSION** — match the current TestFlight build number (DOSBTS: 60, not the template's value)
- **xcconfig filenames** — `DOOMBTS.xcconfig` → `DOSBTS.xcconfig`, override file ref likewise
- **baseConfigurationReference** references in each build config
- **Per-target exclusion sets** — drop template-specific files (e.g. DOOMBTS's FreeDoom assets `doom-secret.aiff`, `FREEDOOM-LICENSE.txt`) and keep only what the target repo actually has
- **Test bundle PRODUCT_BUNDLE_IDENTIFIER** — e.g. `com.cinimody.DOSBTSTests`
- **fileSystemSynchronizedGroups** per target — app includes `App/` + `Library/`; widget includes `Library/` + `Widgets/`; test target includes nothing (its sources are listed explicitly)
- **Root group children** — must list the synchronized root groups (`App`, `Library`, `Widgets`) plus the explicit test group plus `Frameworks` / `Products`

## Validation

After the rewrite:

```
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSWidget -sdk iphonesimulator -configuration Debug build
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Baseline for DOSBTS: 137 passing tests. Any regression in test count indicates a test file was dropped from the pbxproj test group.

Also: add a throwaway `.swift` file under `App/` without touching pbxproj and confirm Xcode picks it up on next build. If it doesn't, the sync-root setup is broken.

## Watch-outs

- **Hex IDs can be reused across projects** — the IDs in DOOMBTS are fine to reuse in DOSBTS since they're internal to each pbxproj.
- **`Extensions/Float.swift` exclusion** — the DOOMBTS template excludes this file from the widget target. DOSBTS has the same file and the same exclusion applies. Keep it.
- **Widget `Library/Resources/` exclusion** — all audio files and `sensor.png` are excluded from the widget target. If a new resource is added later that the widget DOES need, remove it from the exception set.
- **Test file drift** — whenever you add a new test file to `DOSBTSTests/`, remember to add it to the explicit test group + sources build phase. Unlike App/Library files, tests aren't auto-synced.

## Related

- Linear: DMNC-768 (DOSBTS), DMNC-706 (DOOMBTS parent)
- CLAUDE.md "Adding New Files to Xcode Project" section rewritten after this migration
- DOOMBTS sibling doc: `docs/solutions/build-errors/xcode-filesystem-synchronized-migration-pbxproj-mismatches-20260421.md`

---
title: "iOS deployment target blocks Swift API cleanup (onChange 2-arg form)"
module: xcode-project-structure
date: 2026-04-22
problem_type: build_error
component: tooling
severity: medium
symptoms:
  - "Compiler error when replacing deprecated `.onChange(of:perform:)` with the new 2-argument `.onChange(of:_:_:)` form"
  - "Build fails with 'is only available in iOS 17.0 or newer' after what appeared to be a syntactic API swap"
  - "Deployment target mismatch discovered only at compile time, not caught during planning"
root_cause: config_error
resolution_type: config_change
tags:
  - xcode
  - pbxproj
  - ios
  - deployment-target
  - swift
  - onchange
  - deprecation
  - api-migration
---

# iOS deployment target blocks Swift API cleanup (onChange 2-arg form)

## Problem

Migrating `.onChange(of:perform:)` call sites to the iOS 17+ two-argument closure form `.onChange(of:_:)` breaks the build when the project's deployment target is below iOS 17.0. A migration that appears to be a mechanical three-line swap expands in scope the moment the compiler enforces the availability constraint.

Surfaced while executing DMNC-769, which had been scoped as "finish iOS 26 deprecation cleanup — 3 remaining onChange sites" based on the DOOMBTS sibling repo having completed the equivalent migration. DOOMBTS succeeded because it had already been bumped to iOS 26; DOSBTS was still at iOS 15.

## Symptoms

```
App/Views/SharedViews/NumberSelectorView.swift:66:61: error: 'onChange(of:initial:_:)' is only available in iOS 17.0 or newer
```

The error points at the new-form `onChange` call site. Xcode (and `xcodebuild`) will surface this for every migrated site until the target is raised or `#available` guards are added.

## What Didn't Work

Cold-swapping every `.onChange(of: value) { newVal in ... }` to `.onChange(of: value) { old, new in ... }` without checking the deployment target. The build succeeded in the DOOMBTS sibling repo because that project had already been bumped to iOS 26; DOSBTS was still at iOS 15.0 (widget at 16.0). The compiler accepts the two-argument form only when the minimum deployment target is ≥ iOS 17.

## Solution

### Step 1 — Raise the deployment target

Eight `IPHONEOS_DEPLOYMENT_TARGET` entries exist in `DOSBTS.xcodeproj/project.pbxproj` (across Debug/Release for the app target, widget target, and test target). All were bumped from 15.0 / 16.0 to 26.0 to match DOOMBTS.

Verify the current minimum before touching call sites:

```bash
grep -c 'IPHONEOS_DEPLOYMENT_TARGET' DOSBTS.xcodeproj/project.pbxproj
grep 'IPHONEOS_DEPLOYMENT_TARGET' DOSBTS.xcodeproj/project.pbxproj | sort -u
```

Apply with `sed` once the decision is made:

```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/IPHONEOS_DEPLOYMENT_TARGET = 26.0;/g; s/IPHONEOS_DEPLOYMENT_TARGET = 16.0;/IPHONEOS_DEPLOYMENT_TARGET = 26.0;/g' DOSBTS.xcodeproj/project.pbxproj
```

### Step 2 — Apply the two-argument form at each call site

Before (deprecated single-argument + `perform:` closure):

```swift
// ContentView.swift
.onChange(of: store.state.latestSensorGlucose, perform: { _ in
    WidgetCenter.shared.reloadAllTimelines()
})

// NumberSelectorView.swift
Slider(value: doubleProxy, in: min ... max).onChange(of: value, perform: { value in
    if let completionHandler { completionHandler(value) }
})
```

After (iOS 17+ two-argument form, no `perform:` label):

```swift
// ContentView.swift
.onChange(of: store.state.latestSensorGlucose) { _, _ in
    WidgetCenter.shared.reloadAllTimelines()
}

// NumberSelectorView.swift
Slider(value: doubleProxy, in: min ... max).onChange(of: value) { _, newValue in
    if let completionHandler { completionHandler(newValue) }
}
```

Two things to watch when migrating:

1. Drop the `perform:` argument label entirely; the new form uses a trailing closure.
2. The new form passes `(oldValue, newValue)`. The old form's single parameter was the NEW value. If the closure body referenced the parameter as the new value (common), bind the second argument: `{ _, newValue in ... }`. If the body didn't reference the value at all, bind both as `_`.

## Why This Works

`.onChange(of:_:)` (two-argument closure receiving `oldValue, newValue`) was introduced in iOS 17.0 / SwiftUI 5. The single-argument `perform:` variant still compiles against iOS 17+ targets but is deprecated and generates warnings. Below iOS 17, only the `perform:` form exists; the compiler enforces this strictly via `@available(iOS 17.0, *)` in the SwiftUI header. Raising the deployment target to 26.0 clears the availability check and allows the clean two-argument form across all sites with no `#available` guards.

## Prevention — Three Checks Before Estimating Any Swift API Migration

Treat these as a pre-flight checklist whenever a ticket involves adopting a newer API form:

### Check 1 — Lowest deployment target in the project

```bash
grep 'IPHONEOS_DEPLOYMENT_TARGET' DOSBTS.xcodeproj/project.pbxproj | sort -u
```

Look at the minimum value. That is the version the compiler enforces.

### Check 2 — Minimum iOS version for the target API

Look up the API in Apple documentation or inspect the SwiftUI header for its `@available(iOS X, *)` attribute. For `onChange(of:_:)` it is iOS 17.0. If the project minimum from Check 1 is below that number, the scope is not three lines.

### Check 3 — Existing `#available` guards in the files to be changed

```bash
grep -rn 'if #available\|@available' App Library --include='*.swift' | grep -E 'iOS 1[5-9]|iOS 2[0-6]'
```

Any `if #available(iOS 16, *)` or `@available(iOS 17, *)` guards already in those files are a reliable signal that the project's minimum target is below those versions, and that the file's author already had to work around availability constraints.

### Decision tree after the three checks

- **Target ≥ API minimum** → proceed with the clean migration as estimated.
- **Target < API minimum** → three options:
  1. Bump the deployment target if the product roadmap allows dropping older devices (preferred when a sibling repo has already raised the bar).
  2. Wrap every migrated site in `if #available(iOS X, *) { newForm } else { oldForm }` — defeats the cleanup purpose; almost always the wrong choice.
  3. Defer the ticket as blocked and record the dependency.

### Follow-on: clean up dead `#available` branches

After bumping the deployment target, every `if #available(iOS X, *)` guard where X ≤ new target becomes a dead branch (always-true). Schedule a follow-up pass to remove them. For DOSBTS, this is DMNC-777.

## Related Docs (refresh candidates)

Three existing docs reference the old iOS 15 floor and may now be stale:

- `docs/solutions/ui-bugs/swiftui-sheet-collision-ios15-sibling-views-20260315.md` — **most affected**. The workaround is positioned as required "with a deployment target of iOS 15.0." After DMNC-769, the iOS 16 fix referenced in that doc is unconditionally available. The `.sheet(item:)` pattern remains good practice but is no longer required.
- `docs/solutions/security-issues/redux-action-secret-leakage-keychain-side-channel.md` — checklist row 3 says "All new APIs availability-checked against iOS 15.0 target." The floor is now iOS 26.
- `docs/solutions/logic-errors/appstate-inactive-blocks-data-loading-20260317.md` — code sample uses the single-arg `.onChange(of: scenePhase) { newPhase in ... }` form. Compiles with a deprecation warning on iOS 26; worth updating to the two-arg form for consistency.

## Related Linear / PRs

- **DMNC-769** / [PR #19](https://github.com/CinimoDY/DOSBTS/pull/19) — the migration + deployment-target bump
- **DMNC-777** — follow-up: remove now-dead `#available(iOS 15/16/17, *)` guards codebase-wide
- **DMNC-780** — follow-up: `UIScreen.main` deprecated in iOS 26 (a separate iOS 26 surprise found during the same deployment-target bump)

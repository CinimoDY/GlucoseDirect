## Session Report — DOSBTS

**Date:** 2026-04-22
**Branch:** main
**Duration:** 6 commits to main + 3 PRs + 1 TestFlight deploy

### What Was Done

**Code cleanup sweep (PR #23 → DMNC-776/777/778).**
- Eliminated all `URL(string:)!` force-unwraps by introducing a new `URL(staticString:)` helper (`Library/Extensions/URL.swift`) and promoting `DirectConfig` URL constants from `String` to `URL`.
- Removed 18 dead `#available` / `@available` iOS 15/16/17 guards + deleted `ChartViewCompatibility.swift`.
- Swept 57 orphaned `/* (No Comment) */` markers across all 19 `Library/*.lproj/Localizable.strings` files (3 per file, left behind by PR #22's key removals).
- Plus a ce:review follow-up commit with CLAUDE.md past-tense rewrite, OverviewView MARK generalization, `appSchemaURL` consistency, AppleCalendarExport DOOMBTS-backport breadcrumb.

**Docs + screenshots (PR #24 → DMNC-779).**
- Added a formal `## CHANGELOG` section to CLAUDE.md defining the `[Unreleased]` → `[Build N]` promotion flow, "user-visible" criterion, split-cycle rule, yanked-build rule.
- Retroactively promoted `[Unreleased]` → `[Build 61] — 2026-04-22` in CHANGELOG.md.
- README: added 2×2 screenshots grid (3 real-device captures user-provided + 1 simulator capture driven through the virtual sensor).
- ce:review follow-up: re-encoded PNGs 16-bit → 8-bit via Pillow, stripped EXIF timestamps, kept Display P3 ICC profile.

**UIScreen.main iOS 26 migration (PR #25 → DMNC-780).**
- Replaced deprecated `UIScreen.main.bounds.*` reads with a scene-derived lookup walking `UIApplication.shared.connectedScenes`.
- File relocated from `Library/Extensions/` → `App/Extensions/` (UIApplication.shared is `NS_EXTENSION_UNAVAILABLE` in the widget target).
- ce:review hardening: clamp `ChartView.screenWidth` to `max(0, ...)` to prevent zero-scene cold-start cascade; extended scene-predicate fallback chain to include `.foregroundInactive`.

**Build 62 to TestFlight.** Bumped `CURRENT_PROJECT_VERSION` 61 → 62 across all four target configs, promoted `[Unreleased]` → `[Build 62]` in CHANGELOG, ran `./deploy.sh`. Archive + upload succeeded at 16:13 UTC.

**Session wrap-up.** One compound doc captured. CLAUDE.md enriched with 3 audit findings. 5 Linear issues closed; 1 follow-up created.

### Commits (main)

| Hash | Message |
|------|---------|
| `b25442a9` | docs: compound learning + CLAUDE.md audit additions |
| `e599d5b2` | chore: bump build to 62 for TestFlight, promote CHANGELOG |
| `fbd8fe79` | chore: migrate UIScreen.main off iOS 26 deprecation (#25) |
| `7c74ecb1` | docs: CHANGELOG convention + build 61 promotion + README refresh (#24) |
| `ad8d4583` | chore: post-build-61 cleanup sweep (DMNC-776/777/778) (#23) |

### Issues Updated

- **DMNC-776** (Done) — URL force-unwrap sweep
- **DMNC-777** (Done) — Remove dead `#available` guards
- **DMNC-778** (Done) — Remove orphaned Localizable keys
- **DMNC-779** (Done) — CHANGELOG maintenance convention
- **DMNC-780** (Done) — UIScreen.main iOS 26 migration
- **DMNC-790** (Created, Backlog) — Write TestFlight release notes for build 62

### Open Items (off-repo — user tasks)

- [ ] DMNC-774 — Enable GitHub Sponsors on CinimoDY account (unblocks Settings → About tip-jar link)
- [ ] DMNC-775 — Post TestFlight release notes for build 61 on App Store Connect (draft in issue)
- [ ] DMNC-790 — Post TestFlight release notes for build 62 on App Store Connect (draft in issue)

### Next Steps

1. Post build 62 release notes to App Store Connect (suggested copy in DMNC-790)
2. Enable GitHub Sponsors when convenient — unblocks the amber Settings → About link that's live on 61 and 62
3. Run `./deploy.sh` again once build 62 fixes land in a real device's cold-start path for verification

### Documentation Status

- **CLAUDE.md:** up to date. 3 audit findings applied (`URL(staticString:)` helper reference, `UIApplication.shared` NS_EXTENSION_UNAVAILABLE gotcha, deploy.sh bump clarification). Test count 138 verified against `grep -c '@Test'`.
- **README.md:** up to date. Build references bumped 60 → 61; screenshots grid added.
- **CHANGELOG.md:** current. `[Build 62] — 2026-04-22` promoted.
- **docs/solutions/:** +1 compound doc at `best-practices/ios-26-uiscreen-main-migration-20260422.md`.
- **Auto memory:** +1 feedback (`feedback_apply_all_review_fixes.md`) — "apply all fixes at review time" preference validated.
- **DevJournal:** session dir at `.devjournal/sessions/post-build-61-cleanup-2026-04-22/` with L2 built; `publishTo: null` so no L1 draft (private path, correct for DOSBTS).

### Open PRs

None — #23, #24, #25 all squash-merged; branches deleted on remote.

### Build / TestFlight

Build 62 on TestFlight, uploaded 2026-04-22 16:13 UTC. Processing runs on Apple's side.

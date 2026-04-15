# Hypo Treatment Workflow (Rule of 15)

## What happened

Built the complete low glucose treatment workflow in a single session — from idea to TestFlight (build 49).

## Flow

1. **Idea → Linear** — Created DMNC-646 with the Rule of 15 concept
2. **Brainstorm** — Used ce:brainstorm with 5 clarifying questions (trigger, logging UX, recheck behavior, timing R&D, defaults). Key decisions: auto-trigger on alarm, both notification actions + in-app modal, foreground-only auto-check, critical-low safety floor
3. **Requirements review** — 5-persona document review (coherence, feasibility, product-lens, design-lens, scope-guardian). Surfaced and resolved: alarm UI surface, background recheck reliability, default treatment mechanism, countdown banner, alarm suppression safety
4. **Plan** — 9 implementation units with dependency ordering. Repo research + institutional learnings integrated. Key architectural decisions: TreatmentEvent as separate GRDB model, separate treatment snooze state, UserDefaults for cycle persistence
5. **Plan review** — Headless 5-persona review. 7 auto-fixes applied (YAGNI simplifications from scope guardian). Remaining findings addressed interactively.
6. **Implementation** — 9 units built via parallel subagents. Foundation (Units 1, 2, 8) → Core logic (Units 3, 5) → UI (Units 6, 7) → Polish (Units 4, 9). Each batch committed incrementally.
7. **Code review** — 6-persona review (correctness, testing, maintainability, reliability, adversarial, project-standards). Found and fixed: P0 recheckDispatched race, P0 corrupt state recovery, P1 swipe-dismiss cleanup, P1 cold launch modal trigger, P1 notification error logging, P1 stale countdown race, P1 alarm timestamp recovery, P2 sheet timing, P2 auto-dismiss cancellation
8. **Deploy** — Compile errors caught on first archive (wrong design token names: headline→displayMedium, displayLarge→glucoseHero, amberPrimary→amber). Fixed, re-deployed. Agreement expired on second attempt. Third attempt succeeded.

## What was built

- **TreatmentEvent** GRDB model (write-only V1) for future absorption analysis
- **TreatmentCycleMiddleware** orchestrating the full cycle: log → countdown → recheck → chain
- **Alarm suppression** with critical-low safety floor (alarmLow - 15 mg/dL breaks through)
- **TreatmentModalView** for foreground treatment prompt + recheck results
- **TreatmentBannerView** with 4-state countdown (active, rechecking, stale data, recovered)
- **UNNotificationCategory** with TREAT NOW + More... action buttons
- **ActiveSheet enum** consolidating all OverviewView sheets (prevents iOS 15 collision)
- **Settings picker** for configurable wait time (10-30 min)
- **FavoriteStore seed migration** for existing users missing hypo treatment favorites

## Lessons

- Subagents don't have access to the design system — they invented token names (headline, displayLarge, amberPrimary) that don't exist. Always verify builds before deploying.
- The BG button was accidentally dropped during OverviewView sheet consolidation. Full-file rewrites need careful diffing against the original.
- `recheckDispatched` as a non-persisted flag creates subtle state inconsistency across app kill/restart. The code review caught this.
- The dismiss-then-present asyncAfter(0.3s) pattern is fragile. Replaced with onDismiss + pendingSheet which is deterministic.

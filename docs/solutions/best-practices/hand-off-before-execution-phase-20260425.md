---
title: Hand off to a fresh session before the execution phase of a long pipeline
module: session-workflow
tags:
  - claude-code
  - subagents
  - context-budget
  - superpowers
  - compound-engineering
problem_type: workflow_issue
track: knowledge
date: 2026-04-25
---

# Hand off to a fresh session before the execution phase of a long pipeline

## Context

In the DMNC-848 session on 2026-04-25, a single Claude Code session drove the full planning pipeline for a large feature: `superpowers:brainstorming` → `superpowers:writing-plans` (3 plans) → `compound-engineering:document-review` (5 reviewer agents) → plan revision (rewriting 2 of 3 plans end-to-end). When the session tried to transition into execution via `superpowers:subagent-driven-development`, subagent dispatch failed with "Prompt is too long" — even for a trivial 1-line CaseIterable conformance task dispatched to haiku.

The controller session had accumulated: the brainstorming skill reference, the writing-plans skill reference, the subagent-driven-development skill reference, the document-review skill reference, the findings from 5 reviewer subagents (each running ~500 tool_uses over several minutes), two full plan documents, a spec document, and all the MCP server instruction blocks. That background is prepended to every subagent dispatch prompt; even a 200-token task description couldn't fit.

## Guidance

**When a single session's job is planning, end it with a handoff and start the execution phase fresh.**

The boundary to end a session:

- You've committed a complete spec + implementation plans to the repo.
- You've run document-review over the plans and folded in the fixes.
- The next step is "execute the plan task-by-task."

Write a handoff doc at `.devjournal/sessions/<session-slug>/HANDOFF.md` containing, in priority order:

1. **Top-line resumption command.** The exact `/skill <skill-name> <args>` a fresh session needs as its first input. Offer 2-3 invocation variants (primary + fallback).
2. **Critical correctness reminders.** Pinpoint decisions the fresh subagents must honor that aren't obvious from the plan text — e.g., "use id-preserving constructors, never mutate `let` fields," "drop sibling sheets in ChartView at lines X-Y," "preserve the existing NavigationLink barcode-rescan flow in Task N."
3. **Commit trail + task-list state.** Which commits shipped and which are in-flight, so the fresh session can diff against the right baseline.
4. **Known gotchas.** Any non-obvious workflow traps specific to the codebase or pipeline stage.

Then commit and close the session.

## Why This Matters

Subagents start with a "fresh" context inside their own invocation, but the **controller's system context is serialized into the dispatch prompt**. A heavy controller cannot dispatch minimal subagents — the combined prompt overflows the model's input limit before the subagent's own work begins.

This has two downstream effects that waste time if you ignore the signal:

1. You fall back to doing trivial tasks inline, which burns more controller context and accelerates the overflow.
2. You skip the two-stage review (spec-compliance + code-quality) that subagent-driven-development provides — so quality drops exactly when the pipeline moves into the higher-risk implementation phase.

Handing off is strictly better: the fresh session has budget for subagents, the planning artifacts are already in the repo, and the two-stage review runs as designed.

## When to Apply

**Apply when all of:**

- You've been in the same session for multiple orchestrated skills (brainstorming + writing-plans + document-review counts as multiple).
- Large review outputs have been folded back into your context (5 reviewer agents × a few hundred findings-lines each).
- You're about to invoke `superpowers:subagent-driven-development` or `superpowers:executing-plans` against a plan with >5 tasks.

**The strongest trigger signal: you try a subagent dispatch and it returns "Prompt is too long."** Do not work around this by doing the task inline. Stop and write the handoff.

**Don't apply when:**

- The session is small (one skill, a few commits). A handoff adds overhead without saving anything.
- Plans are still being revised. Finish the revision first, commit it, then hand off.
- Execution is trivial (1-2 tasks, no review loops needed).

## Examples

**Trigger scenario from this session:**

```
/skill superpowers:subagent-driven-development Execute docs/superpowers/plans/...
→ [Skill prompt served]
→ Dispatch first implementer subagent (haiku, 200-token task prompt)
→ Agent returns: "Prompt is too long" (0 tokens, 0 tool_uses)
```

**Handoff doc top section (this session's actual resumption form):**

```markdown
## How to resume

### Option A — User-invoked
In a fresh Claude Code session, type at the prompt:

    /skill superpowers:subagent-driven-development Execute
    docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md
    from Task 0b onward. Phase 0 Task 0a is committed at 0f13f9ee.
    See .devjournal/sessions/dmnc-848-unified-entry-2026-04-25/HANDOFF.md

### Option B — Assistant-invoked equivalent
Paste as first user message in a fresh session:

    Please continue the DMNC-848 implementation. Read
    .devjournal/sessions/dmnc-848-unified-entry-2026-04-25/HANDOFF.md
    for context, then invoke the superpowers:subagent-driven-development
    skill on docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md
    starting from Task 0b.

### Option C — Fallback (batched execution, no subagents)
If subagent dispatch misbehaves in the fresh session too:

    /skill superpowers:executing-plans
    docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md
    — resume from Task 0b. Task 0a committed as 0f13f9ee.
```

**Critical correctness reminders a handoff should include:**

- "Task 12 (CombinedEntryEditView): use id-preserving constructors `MealEntry(id: original.id, ...)` — never mutate `let` fields."
- "Task 13 (ChartView integration): MUST drop `.sheet(item: $tappedMealEntry)` at lines 198-214 AND `.sheet(item: $tappedMealGroup)` at lines 227-286 to avoid sibling sheet collisions."
- "Task 5 (FoodPhotoAnalysisView migration): preserve the existing `NavigationLink → ItemBarcodeScannerView` flow with the `isItemScanActive` guard. Don't simplify."

**Counter-example (don't hand off):**

A 5-commit bug-fix session where you ran one skill (`debugging`) and the next step is to open a PR. Opening a PR isn't a context-heavy operation. Hand off is overhead.

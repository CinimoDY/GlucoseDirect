# Themes — DMNC-795 OOUX Brainstorm

**Retrieval tags:** ooux, object-oriented-ux, design-system, entry-patterns, staging-plate, category-panel, interaction-patterns, insulin-entry, meal-entry, blood-glucose, favourites, sophia-prater, dmnc-795, dmnc-791, dmnc-796, dmnc-797

## Thematic threads surfaced this session

- **Object-Oriented UX as organising principle** — applying Sophia Prater's OOUX to DOSBTS clarified that the app's entry surfaces had drifted because they grew feature-by-feature without a shared object vocabulary or interaction contract. A catalog is the precondition for any consistency effort.

- **"Sweep > piecemeal" applied to design work** — the user's code-refactor preference carries over to design. Rather than fixing each entry view individually, define the shared patterns first and migrate views through them in follow-ups. This also matches the user's memory rule "plan thoroughly before creating/executing Linear issues."

- **Inline-context vs modal** — "expand-in-context" literally means no modal. Three candidate Pattern 2 models were compared; the drill-down was picked, then refined: drop the drill-down (no preset chips under the selected category), keep just the category toggle + native inputs inline. Cleaner and closer to the user's actual intent.

- **Speed-path preservation** — when a workflow is frequent and pre-validated (e.g., tapping a curated favourite meal), forcing it through a generic review step is a regression, not progress. The Meal Pattern 1 + favourite-shortcut mapping acknowledges this with an explicit long-press edit affordance.

- **HealthKit as semantic boundary** — Exercise is HealthKit-imported, read-only. Recognising this early reclassifies it from "entry object" to "read/monitoring," which simplifies the catalog and avoids designing for a non-existent entry path.

- **"Aspirational spec" drift guard** — success criterion #5 makes every relationship in the object map grep-verifiable. This is an intentional discipline against specs that describe a world the code doesn't reflect.

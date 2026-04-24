# Libre Reports — reference inventory for DMNC-807

Captured 2026-04-24 from user's live FreeStyle Libre app (five report screens shared inline). Reference material for the Statistics data-cards redesign brainstorm — **not a prescription**. Documents what Libre ships today so the DOSBTS codesign session can pick, skip, or reinterpret each pattern in CGA phosphor idiom.

The purpose of this doc is *inventory + semantics*, not *visual steal*. Libre's aesthetic (blue pill navigation, soft blue shading, rounded bars) does not belong in DOSBTS. The report *taxonomy* and *per-report answer they give* does.

## Common chrome across all reports

- **Top pill-style report selector** — blue background, white uppercase report name, downward chevron. Opens a bottom-sheet picker (inferred) with the full list of report types. DOSBTS equivalent today: the in-chart `GLUCOSE / TIME IN RANGE / STATISTICS` tab row. Libre has more report types (six visible across the shared screens), which hints at growth shape for DOSBTS.
- **Date range header** — dark grey bar under the selector, format `January 25–April 24, 2026` (90-day selection) or `April 18–24, 2026` (7-day selection). Auto-derived from the window length toggle at the bottom.
- **Window length toggle** — `7 DAYS / 14 DAYS / 30 DAYS / 90 DAYS` segmented bottom row. Selected tab has a rounded grey background. DOSBTS equivalent: the new tab-aware zoom picker from DMNC-806, which currently ships `7d / 30d / 90d / ALL` for TIR + STATISTICS. **Note:** Libre exposes `14 DAYS` where DOSBTS does not, and caps at `90 DAYS` (no `ALL`). Worth considering which is actually useful.
- **Export / info buttons** — bottom of each report. Share-arrow icon (export the report image / PDF) + blue `i` circle (opens an explainer sheet — infers clinical meaning). DOSBTS doesn't have either. The `i` affordance is interesting for DOSBTS's long-form annotations (already toggled via tap-twice on Lists-Statistics today).
- **`Data available for N of M days`** — small footer telling the user how much actual data backs the report. Honest uncertainty signalling. DOSBTS already surfaces `X of Y days` in the chart TIR content from DMNC-793.

## The six report types

### 1. Daily Patterns

**Question answered:** "What does my typical glucose day look like?"

- X axis: 24-hour clock (12am → 12am, ticks at 6am / 12pm / 6pm)
- Y axis: glucose (mg/dL, 50 → 350)
- Series: **median line** (thick white) + **percentile bands** (5 tiers of blue shading — roughly 10/25/50/75/90 percentiles across the 90-day window)
- Reference lines: bright green horizontals at target range bounds (70 / 180)

This is the most interesting one for DOSBTS. It's not a "data card" — it's a chart that shows variability across a 90-day window on a 24-hour axis. Requires per-hour percentile computation over the window.

**CGA reinterpretation opportunities:**
- Replace the five blue bands with nested amber bands at reduced `opacity` — a CRT-phosphor-glow treatment where the outer band has bloom falloff.
- Median line as `AmberTheme.amber` with `dosGlowLarge`.
- Target-range bounds as `AmberTheme.cgaGreen` (we already use it).
- Sub-54 and >250 excursion bands could use `AmberTheme.cgaRed` accents at the extremes instead of more blue.

Candidate placement: a **Hero chart-card** at the top of the redesigned Statistics tab. Semantically, this is the most information-dense single view in Libre's entire report suite.

### 2. Time in Ranges

**Question answered:** "How much of my window was I in each clinical zone?"

- Five horizontal bars — `>250`, `181-250`, `70-180`, `54-69`, `<54`
- Per-bar percentage label to the right of the bar
- Colors: orange (>250), yellow (181-250), **green (70-180)**, red (54-69), red (<54)
- Left-axis labels with `mg/dL` header
- Below: explicit "Standard Target Range: 70 - 180 mg/dL" caption
- Toggle at the top: `Custom | Standard` — users can flip between their own custom-range view and the clinical standard

DOSBTS ships TIR in two places: the in-chart bars (DMNC-793, added 2026-04-23), and the existing `StatisticsView` in Lists tab. The Libre treatment has:
- **5 bands, not 3** — splits >180 into "high" and "very high", splits <70 into "low" and "very low". This matches the standardised ambulatory glucose profile (AGP) bands.
- **Standard vs Custom toggle** — a clinical-vs-personal toggle worth considering. DOSBTS alarmHigh/alarmLow are user-customisable; standard target is always 70-180. Today we conflate them.

**CGA reinterpretation opportunities:**
- The 5-band split is a clinically-better chart than our current 3-band and should probably port over.
- Colors: amber/cgaRed already match orange/red; green maps directly; yellow for 181-250 is a new token (`AmberTheme.cgaYellow` exists per CLAUDE.md).
- Horizontal bars with a scanline-texture fill would give it demoscene flavour without abandoning legibility.

### 3. Low Glucose Events

**Question answered:** "When am I going low?"

- X axis: 24-hour clock, 2-hour bins (12am / 6am / 12pm / 6pm / 12am) — 12 bars total
- Y axis: count of low-glucose events in that bin across the window
- Bars: bright red (all same colour — "it was low"), number above each bar
- Footer: "Total Events: 24"

This is interesting because DOSBTS has all the raw data — `treatmentCycleActive`, predictive-low firings, actual low alarms in the event stream. We don't present the temporal-distribution aggregate anywhere today.

Direct clinical value: "I keep going low between 3am and 6am — need to look at basal or bedtime routine". DOSBTS's hypo-treatment workflow is strong at the moment of the event, but silent on the pattern.

**CGA reinterpretation opportunities:**
- Red bars fit (`AmberTheme.cgaRed`).
- Could pair with a sibling "High Glucose Events" report in amber.
- Bins could be 2h or 3h to match the GLUCOSE zoom granularity.

### 4. Average Glucose (per-day)

**Question answered:** "How did each day of this week look?"

- X axis: 24-hour clock (12am → 12am) — but that's misleading; it's actually **per-2-hour slot across a single day** collapsed to one bar. Looking again: the axis says `12am / 6am / 12pm / 6pm / 12am` and there are 8 bars — so this IS an average-by-time-of-day report, not per-calendar-day. Numbers on top (171, 168, 170, 193, 182, 220, 215, 200).
- Color coding per-bar: **green if the slot's average is in target range (≤ ~180), amber if above**. So the 12am / 6am / 6am-12pm slots were in-range on average; post-lunch through midnight was hyperglycaemic.
- Footer: "Average: 189 mg/dL / Data available for 7 of 7 days"

This is a **semantic colour-coding** treatment — each bar isn't just an amount, it's a pass/fail against the target. Clinical utility: immediately visible "I run high after lunch".

**CGA reinterpretation opportunities:**
- Maps cleanly to `AmberTheme.cgaGreen` in-range, `AmberTheme.amber` above-range, `AmberTheme.cgaRed` below-range — three-state colouring.
- Could extend: bars whose average crosses `alarmHigh` get a glow treatment; in-range bars stay flat.
- Would be more interesting as AVG + error bars (±SD) to show variance per slot, not just mean.

### 5. GMI (Glucose Management Indicator)

**Question answered:** "What's my estimated HbA1c equivalent?"

- Single giant number: `7.5 %` (approx 60pt type)
- Below: `( 58 mmol/mol )` secondary unit in parentheses
- Label above: "Glucose Management Indicator (GMI)"
- Footer: "Data available for 90 of 90 days"

This is the **pure hero-card** treatment the user asked for in earlier feedback ("nice big numbers"). One metric, giant, no chrome, footer for provenance.

**CGA reinterpretation opportunities:**
- Phosphor-glow giant number (`DOSTypography.glucoseHero` + `dosGlowLarge`).
- Semantic colour-coding — GMI < 5.7 = green, 5.7-6.4 = amber (pre-diabetic range), ≥ 6.5 = red (per ADA conventions). Our existing `cgaGreen / amber / cgaRed` trio.
- Could add a target-badge — a thin phosphor ring around the number showing distance from a user-set GMI goal (e.g., "target: 7.0%").
- Maybe a sparkline across the bottom showing 4-week GMI trend so users see whether they're getting better or worse over time. That turns it from a static number into a **trajectory**.

### 6. (Missing from the share) — but implied

Libre's selector is a dropdown chevron, meaning more reports are available beyond the five screens shared. Candidates based on the AGP standard library:

- **AGP (Ambulatory Glucose Profile)** — combines Daily Patterns + TIR + GMI into a single clinical report page. Printable PDF.
- **Time in Target (overlay)** — green zone %, over time as a line (trajectory of TIR week-by-week). A "progress metric."
- **Sensor Usage** — % of the window that the CGM was actively transmitting. DOSBTS already computes this implicitly via `sensor.remainingLifetime` but doesn't surface it as a report.

Worth asking: does DOSBTS want a **printable AGP report**? That unlocks a clinical-visit use case.

## Mapping to DOSBTS current state

| Libre report | DOSBTS today | Delta |
|---|---|---|
| Daily Patterns (percentile band chart) | — | Not implemented. Largest-effort opportunity; high clinical utility. |
| Time in Ranges | `ChartView.TimeInRangeContent` (3 bands) + `StatisticsView` | Split into 5 bands (low / very-low / in / high / very-high). Add Custom/Standard toggle. |
| Low Glucose Events | — | Not implemented. Have the data; just need a query + chart. |
| Average Glucose per time-of-day | — | Not implemented. Similar effort to Low Events. |
| GMI | `StatisticsView` (label+value row) | Promote to a hero-card (giant number + phosphor glow + semantic colouring). |
| AGP (implied) | — | Deferred — needs print / export pipeline. |

## Design language deltas vs Libre

DOSBTS should **not** inherit:
- Libre's blue pill navigation — our idiom is AmberTheme underlined tabs (DMNC-793).
- Libre's rounded bars and cards — we prefer sharp CGA corners.
- Libre's mixed-case "Reports" title — our idiom is uppercase mono (`DOSTypography`).

DOSBTS **should** consider:
- The full 5-band TIR split (clinically stronger than our 3-band).
- Per-time-of-day temporal reports (Low Events, Average Glucose) — we have the data and don't surface it.
- The daily-patterns percentile band chart as a hero view on the Statistics tab.
- A GMI hero-card with semantic colouring as the secondary top-of-stats element.
- The export / info affordance as small chrome for each report.

## Next steps (for the codesign session, not tonight)

Concrete brainstorm hand-off:

1. Pick the **report inventory**: which of the 6 Libre reports ships in DOSBTS's redesigned Statistics tab, in what order.
2. For each chosen report, pick a **card taxonomy** (hero / strip / bar / chart) per the DMNC-807 proposal.
3. For each card, pick an **eiDotter effect token** combination (phosphor-glow + scanline + bloom) that matches its clinical-importance weight.
4. For the daily-patterns report specifically: decide band count (5 or 3), band opacity curve, and whether to render with SwiftUI Charts `AreaMark` + `LineMark` or a custom Canvas.
5. Decide whether the report selector stays as the existing GLUCOSE/TIR/STATS tab or becomes a full bottom-sheet picker like Libre (more reports → bottom sheet makes sense).

Once the codesign session picks direction, spec goes to `docs/brainstorms/` and implementation plan to `docs/plans/`, then subagent-driven execution per DMNC-793's pattern.

## Not in scope for DMNC-807

- Custom date range picker (Libre only exposes 7/14/30/90).
- AGP PDF export.
- Multi-report comparison view.

All are real opportunities but belong to separate issues if the codesign session wants to pursue them.

## Additional Libre surfaces shared 2026-04-24 (second batch)

User note on these: *"Just as inspiration / for knowledge. We don't want to do it that way exactly but at least look at it and analyze it."* Framed as a reference for thinking, not a pattern to lift. Decisions deferred to the codesign session.

### 7. Sensor Usage report (with explainer modal)

Two companion screens:

- **Data view** — three bare metrics, each as a number-plus-label row:
  - `2,920  Total Views` (lifetime or window app opens)
  - `32  Views Per Day` (average)
  - `99  % Time Sensor is Active` (sensor uptime in the window)
- **Explainer modal** (fired from the `i` affordance) — dark rectangular modal, uppercase "SENSOR USAGE" header, prose paragraph, single "OK" dismiss button. *"Sensor Usage provides information about how often you have viewed your glucose readings in the app and how much information has been captured from your Sensor."*

**What's interesting for DOSBTS:**
- The **meta-engagement metric** — "how often do I check my CGM" — is a mental-health signal. Overcheckers (200+/day) and undercheckers (<5/day) are both patterns worth surfacing. DOSBTS doesn't track this today; easy to add via a counter in middleware.
- Sensor uptime (`99%`) is already computable from `Sensor.remainingLifetime` + outages captured in `SensorErrorStore`. Not surfaced in any user-visible view.
- The **explainer modal pattern** (tap `i` → dark modal with clinical-voice prose + OK) is a distinct interaction from DOSBTS's current "tap twice on the label to toggle inline annotations" in the Lists → StatisticsView. The `i`-to-modal model is more discoverable; the inline toggle is faster for repeat views. Decision belongs to the codesign session — which model does DOSBTS want, or a hybrid (inline expand default, `i` to modal for deep explanation)?

**What we explicitly don't want to copy:**
- The bare label-colon-value left-aligned layout. It's legible but unremarkable — the kind of "functional but dull" treatment the DMNC-807 brief is specifically reacting against. CGA equivalent should be hero/card-based, not list-based.

### 8. Connected Apps (data-sharing surface)

Three rows, each a branded logo + description + action button:

- **LibreView** — blue italic logo. "Share your diabetes care information with your healthcare team through LibreView." Button: `MANAGE`.
- **LibreLinkUp** — orange italic logo. "Share your diabetes care information with anyone using the LibreLinkUp app." Button: `MANAGE`.
- **Libre Data Share** — bold sans-serif name. "Create a temporary access code to share your data with your healthcare team for a limited time." Button: `CREATE`.

Blue banner at top: "Manage data sharing connections."

**What's interesting for DOSBTS:**
- **Per-integration row with a primary verb button** is a cleaner IA than DOSBTS's current scattered-across-Settings approach. Today DOSBTS's sharing affordances live in: Settings → Nightscout (URL + secret), Settings → Apple Health (toggles), Settings → Calendar export. A unified "Connected Apps" or "Data Sharing" screen consolidating all three would reduce cognitive load.
- The **temporary access code** pattern (Libre Data Share) is clever for HCP visits — shares real-time data for a bounded window with a time-limited credential. DOSBTS doesn't have this. Nightscout sharing is "always on or not set up"; a bounded-window mode is an interesting addition but out of scope for DMNC-807.
- The three-verb taxonomy — **MANAGE** (reconfigure existing), **CREATE** (bounded one-shot) — is a nice microcopy distinction.

**What we explicitly don't want to copy:**
- The branded marketing-logo look (LibreView's blue italic, LibreLinkUp's orange). DOSBTS's ecosystem is Nightscout (community) + Apple Health + Calendar — none of them are brand-marketing surfaces. Text-first with function-descriptive names (e.g., `NIGHTSCOUT`, `HEALTHKIT`, `CALENDAR EXPORT`) fits the CGA phosphor terminal voice better.
- The blue banner header. DOSBTS already has a consistent uppercase section-label idiom (`> QUICK`, `> RECENT`); a banner would fight that.

**Related issue candidate:** a separate DMNC issue for "consolidate data-sharing surfaces into a single Settings → Connections screen" is worth filing. Not DMNC-807's scope; log it as adjacent.

### 9. About / device-metadata screen

Regulatory surface with:
- Country (`Germany`)
- Customer service URL (freestylelibre.com link, tappable)
- `MD` icon (Medical Device marker per EU MDR)
- `UDI` — Unique Device Identifier (`(01)05021791008872(8012)3.6.6.12977.4`)
- "Consult Instructions For Use" book-icon row
- Date of Manufacture / Build Date (`2025-11-17`)
- Manufacturer address (Abbott Diabetes Care Ltd., Witney, Oxon, UK)
- `REF` catalog number (`72107-01`)
- `EC REP` European representative address
- `CE 2797` notified-body marking
- Abbott logo + trademark disclaimer footer

**What's interesting for DOSBTS:**
- **DOSBTS is NOT a regulated medical device** under EU MDR. GlucoseDirect (upstream) and DOSBTS are open-source consumer apps that interface with the user's own sensor — the regulated device is Abbott's Libre hardware, not our reader app. So *most* of this screen doesn't apply to DOSBTS.
- **What does translate:** a reasonable **About / Credits** surface showing:
  - App version + build number (DOSBTS already has this in Settings)
  - Fork attribution (already in LICENSE + CHANGELOG)
  - Build date (derived from pbxproj or git sha)
  - Links to upstream GlucoseDirect, DOSBTS repo, author contact (GitHub Sponsors row already added in build 61)
  - Explicit non-regulatory disclaimer: *"This app is not a medical device. Treatment decisions must be verified with the manufacturer's hardware reader."*
- The Abbott trademark footer is a model for our own attribution. DOSBTS already credits GlucoseDirect in LICENSE but the in-app surfacing could be tightened.

**What we explicitly don't want to copy:**
- UDI / REF / EC REP / CE markings. These are regulatory claims we do not hold and cannot display without legal risk.
- The "Consult Instructions For Use" affordance. We don't ship IFU and our users are their own clinicians.

**Related issue candidate:** a small "clean up Settings → About section" issue for the non-regulatory elements worth lifting (build date surfacing, clearer disclaimer, fork-attribution tightening). Adjacent to DMNC-807, not blocking.

## Updated takeaway for the codesign session

Libre's app at large gives us a mental map for where DOSBTS could grow beyond its current Overview-centric layout. DMNC-807 is narrowly scoped to the Statistics tab redesign, but adjacent opportunities surfaced by these reference screens:

| Adjacent opportunity | Scope | Next step |
|---|---|---|
| Meta-engagement report (views/day, sensor uptime) | Small — new report + existing data | Could ship as DMNC-807 sibling after stats cards. |
| Consolidated Connected Apps / Data Sharing screen | Medium — consolidate 3 existing surfaces | File separate DMNC issue. |
| About / Credits cleanup (non-regulatory) | Small — 1 settings screen | File separate DMNC issue. |
| Explainer modal (`i` → dark modal) interaction model | Small — pattern decision | Resolve in DMNC-807 codesign session. |
| 5-band TIR split (low/very-low/in/high/very-high) | Medium — chart rework + alarm-band semantic | In DMNC-807 scope. |
| Per-time-of-day reports (Low Events, Avg by slot) | Medium — new query + chart | In DMNC-807 scope. |

The codesign session picks which of these DMNC-807 covers directly vs. which spawn sibling issues, before any mockups get made.

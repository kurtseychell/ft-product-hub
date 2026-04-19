# Claude Design Handoff Pack — Product Hub

## What this bundle is for

Everything needed to upload Product Hub to **claude.ai/design** so Claude Design can:
1. Extract a unified design system from the 17 visually-aligned screens
2. Become the generation surface for new screens (Bug pipeline, v2 admin screens, etc.)
3. Hand finalised designs back to Claude Code with a "handoff bundle" for production implementation

## Important context (per research dated 2026-04-19)

- **Claude Design is browser-only:** no API, MCP, or CLI exists. You upload via claude.ai/design in the Anthropic web app.
- **The integration is one-way:** the *only* automated bridge is Claude Design's "Send to Claude Code" feature, which packages HTML/React + design specs for you to drop into a Claude Code session.
- **Eligibility:** Pro / Max / Team / Enterprise plans (research preview).
- **Canonical reference for all decisions:** `../_SOURCES/User_Journey_Flow.md`.

## Bundle contents

| File | Purpose | Audience |
|---|---|---|
| `README.md` (this file) | Overview, upload sequence, recommendations | You |
| `Brief.md` | Shaped brief describing product, personas, journey, design system tokens, screen inventory | Claude Design (upload as project document) |
| `Regeneration_Prompts.md` | Prompts to use *after* design system is established — for re-skinning the 3 IBM-Carbon outliers + generating missing Bug pipeline screens + v2 admin screens | You (paste into Claude Design as new generations) |

## Upload sequence

### Step 1 — Onboarding (one-time)
Open claude.ai/design. During onboarding:
- Upload `Brief.md` as the project context document
- Add `../screens/` directory for codebase ingestion. **Upload only the 17 "aligned" screens listed in Brief.md → Screen Inventory.** Skip C02, Z01, E04 (they use IBM Carbon styling and would pollute the extracted design system).

### Step 2 — Design system extraction
Let Claude Design run its design-system extraction pass. It will read the 17 screens + the explicit tokens in Brief.md and produce its internal model of Product Hub's visual language.

### Step 3 — Validation
Generate one new screen as a sanity check before committing more work. **Suggested validation screen: Notification Settings** (a small, low-stakes screen we know is missing per OL-3). If the output looks on-brand, the extraction worked.

### Step 4 — Production work
Use the prompts in `Regeneration_Prompts.md` to generate:
- **Re-skinned outliers:** new versions of `[C02]` RICE Scoring, `[Z01]` LLM Usage & Costs, `[E04]` Success Metrics
- **New Bug pipeline screens (per Stage B-Bug):** Bug Workspace, Manual Replication, Bug Triage Queue
- **v2 admin screens:** Notification Settings, Manage Users, Platform Settings

### Step 5 — Hand back to Claude Code
For each finalised design, use Claude Design's "Send to Claude Code" feature. The handoff bundle contains HTML/React code + design specs + component descriptions. Drop into a Claude Code session and ask Claude Code to implement against the existing codebase.

## Recommended first screens to upload (in this order)

1. **`A02 Dashboard`** — broadest sample of components (cards, charts, sidebar, top nav, stats grid, gradient-decorated welcome banner). Anchors design-system extraction with the widest visual variety.
2. **`B02 PRD Builder`** — canonical 3-panel AI workspace pattern (source | AI chat | live document). Establishes the AI workspace convention used in C01, C03, E02.
3. **`D02 Domain Backlogs`** — multi-view layout (Ranked List / Board / Table) + cross-domain summary cards + comparison overlay panel. Establishes data-comparison patterns.
4. The remaining 14 aligned screens (any order).

## On the 3 IBM-Carbon outlier screens

`[C02]` RICE Scoring, `[Z01]` LLM Usage & Costs, `[E04]` Success Metrics use IBM Carbon styling — sharp 0px corners, IBM Plex Sans font, `#0F62FE` blue. They visually clash with the rest of Product Hub.

**Recommended approach:** skip them in Step 1. Regenerate via Claude Design in Step 4 (prompts ready in `Regeneration_Prompts.md`). This is more efficient than manually re-editing the HTML *and* gives you a real test of whether Claude Design has internalized your design system.

**If you'd rather manually re-skin the HTML first** (so you can compare original vs. AI-regenerated side-by-side), say the word and I'll edit the 3 files directly using the canonical tokens.

## What's *not* in this pack (and why)

- **The screens themselves** — they live in `../screens/` and stay there; Claude Design ingests them directly via folder upload.
- **Source specs** — `../_SOURCES/Product_Hub_Gap_Specifications.md` and `../_SOURCES/Stitch_Prompts_Product_Hub_Backoffice.md` are stale for journey questions (superseded by `../_SOURCES/User_Journey_Flow.md`). Don't upload them; they'd confuse Claude Design.
- **HTML prototypes in repo root** — `product-hub-prototype.html` and `product-hub-prototype-v2.html` are early sketches, not canonical. Don't upload.

## Open questions still owned by you (from `User_Journey_Flow.md` §9.2)

These don't block the upload but will need answers before generating production-ready screens:
- **OL-B1** Brief v(N+1) supersession UX — what's the prompt when Stakeholder submits v2 while v1 is locked under review?
- **OL-B2** Bug AI replication mechanism — what does the agent actually do? (sandbox? automated tests? log query?)
- **OL-B3** Bug scoring model — Severity × Reach instead of standard RICE?
- **OL-B6** Submission Score algorithm spec — formula + weights + edge cases (Q5 follow-up)

---

*Generated 2026-04-19 from canonical journey + design decisions. See `../_SOURCES/User_Journey_Flow.md` for full context.*

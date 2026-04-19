# Regeneration Prompts for Claude Design

> **Use these prompts AFTER Claude Design has extracted the design system from the 17 aligned screens.** Each prompt assumes Claude Design has internalized the canonical Product Hub design system (Material 3 indigo + Inter/Manrope + the conventions in Brief.md §6).

---

## Section 1 — Re-skin existing IBM-Carbon outliers

These three screens currently use IBM Carbon styling (sharp 0px corners, IBM Plex Sans, `#0F62FE` blue). Regenerate them in the Product Hub style.

### 1.1 — Regenerate `[C02]` RICE Scoring

```
Regenerate the RICE Scoring page using the established Product Hub design system (replace its current IBM Carbon styling).

Page purpose: A Product Lead reviews three independently-named AI council agents (Market Analyst, Technical Feasibility, Business Strategy — these are PM-BOT council agents) of a PRD's RICE score, sees an aggregate consensus with confidence range, and can override individual dimensions with an audit note.

Layout:
- Top section: PRD title with "PRD Approved" status pill (emerald), brief description below, "Edit Details" button (primary outline) on the right
- Below the header: 4-column R/I/C/E summary strip with circle badges (Reach: 8k, Impact: 3.0, Confidence: 80%, Effort: 2.5 — note Effort uses red ring to signal "low is good here")

Main grid (12-col):
- Left 7-col: 
  - Section heading "Agent Assessments" (small, uppercase, with smart_toy icon)
  - 3 stacked Agent Assessment cards. Each card: colored icon avatar (square, color-coded per agent — primary indigo / tertiary purple / amber), agent name, brief commentary text (2 lines max), and a row of small R/I/C/E badges with values
  - Below the 3 cards: "Aggregate RICE Score" banner — full-width primary indigo background, large value "31.5" with "/100" subscript on left, confidence range "78–85%" with progress bar on right
- Right 5-col:
  - "Score Dimension" card with radar chart (4 axes: Reach top, Impact bottom, Confidence left, Effort right) + "Compare" button
  - Below: "Score History" timeline (vertical list with status dots)
  - Below: "Override Score" card with R/I/C/E numeric inputs (4 in a 2x2 grid) + Audit Note textarea + "Save Manual Override" primary CTA

Use Product Hub design system: indigo Material 3 palette, Inter body + Manrope headline, Material 3 border radius scale (cards xl, badges full pill).
```

### 1.2 — Regenerate `[Z01]` LLM Usage & Costs

```
Regenerate the LLM Usage & Costs admin page using the established Product Hub design system (replace IBM Carbon).

Page purpose: Admin monitors per-feature LLM API spend, configures per-feature LLM choice and token limits, sets cost-alert thresholds, reviews per-feature cost breakdown.

Layout:
- Top: 3 stat cards in a row
  - Monthly Spend: "$2,847" + "Used 71% of $4,000 budget" caption + horizontal progress bar
  - Total API Calls: "12,430" + "+12% from last month" trend pill
  - Avg Cost per PRD: "$1.24" + "Optimized for Sonnet" footnote

- 2-col grid:
  - Left col (span 2): Daily LLM Spend bar chart (last 30 days) with red dashed budget threshold line + small legend
  - Right col (span 1): Model Configuration card — section title "Model Configuration", subtitle "Default feature inference models", then per-feature blocks (PRD Generator / Research Bot) with: dropdown for model + horizontal slider for max tokens with current value caption. Bottom: "Save Configurations" primary CTA

- Cost Alerts section (full width)
  - Section title + subtitle
  - 3 cards in a row, each: threshold name (50% / 75% / 90%) + "Notify admin@org.com" + toggle switch on right

- Cost & Usage Breakdown table (full width, white card)
  - Title bar: "Cost & Usage Breakdown"
  - Columns: Feature | API Calls | Tokens Used | Cost | Avg Latency | Sparkline (5-bar mini chart)
  - Rows: PRD Generator ($1,142.50), RICE Scoring ($285.40), UAT Assistant ($945.20), Research Bot ($473.90)

- Bottom: 2 greyed-out preview cards in 2-col grid (placeholder for "Manage Users" and "Platform Settings" tabs — v2 scope)

Sidebar: Admin context (single nav group with LLM Usage & Costs / Manage Users / Platform Settings, with LLM active).

Use Product Hub design system. Replace IBM Plex Sans with Inter+Manrope.
```

### 1.3 — Regenerate `[E04]` Success Metrics

```
Regenerate the Success Metrics analytics page using the established Product Hub design system (replace IBM Carbon).

Page purpose: Executives and analysts consume pipeline KPIs, conversion funnel, domain distribution, top-performing releases, and prediction accuracy of the RICE model.

Layout:
- Top header: page title "Success Metrics" + subtitle + 2 filter dropdowns on the right (Date Range: Last 30 Days, Domain: All Domains)

- 4 KPI cards in a row (each with a sparkline mini-chart on the right)
  - Ideas Submitted: 47 (+12%)
  - PRDs Generated: 31 (+8%)
  - Avg Time to Ship: 23 days (-15%) — green "trending_down" icon (down is good)
  - Release Adoption: 78% (+5%)

- 2-col grid:
  - Left col: "Submissions to Release Pipeline" funnel chart (multi-line SVG: Submitted, PRD Created, Approved, In Dev, Released over 6 weeks) + 2-color legend
  - Right col: "Domain Distribution" stacked horizontal bars (Fintech 84 / Logistics 52 / User Growth 120 / Infrastructure 28); each bar 3-segment colored

- 2-col grid:
  - Left col: "Top Performing Releases" table card. Columns: Release | Domain | Adoption % | Sat. (5-star rating) | Impact (Low/Med/High/Extreme)
  - Right col: "RICE Score Accuracy" scatter plot card with R²=0.84 pill in top-right corner; scatter dots + diagonal trend line; axis labels "Predicted Score" / "Actual Impact"

- Bottom footer: "Generate Report" link + 3 export buttons (PDF / CSV / Email Stakeholders) on the right

Use Product Hub design system. Manrope for chart titles, Inter for body. Indigo primary throughout (replace `#0F62FE` blue).
```

---

## Section 2 — Generate missing Bug pipeline screens

These screens don't exist yet but are required for the Bug-path described in `Brief.md` §3 (Stage B-Bug). Generate them once the design system is established.

### 2.1 — Bug Workspace (analog of B02 PRD Builder for bugs)

```
Generate a new screen: Bug Workspace.

Page purpose: This is the bug-path analog of [B02] PRD Builder. When a Stakeholder submits a Request with type=Bug, the system routes here. PM-BOT · PRD Agent (Bug-Triage variant) generates a Reproduction Steps Document (RSD) from the Bug Brief; PM-BOT · Bug Replication Agent then attempts to reproduce.

Layout (3-panel, matching B02 PRD Builder):
- Left panel (~28%): Bug Brief (read-only once review starts)
  - "SOURCE OF TRUTH" badge + version pill (v3)
  - Title: "Payment Retry Notifications failing on iOS Safari"
  - Submitter avatar + name + timestamp
  - Sections: Objective (problem description), Environment (browser, OS, build), Severity Estimate (Stakeholder's gauge: Low/Medium/High/Critical), Attachments
  - At bottom: "Brief Lock Status" info panel (indigo) — "This brief is locked to v3 because review has started"

- Middle panel (~34%): Chat with PM-BOT · PRD Agent (Bug-Triage variant)
  - Header: PM-BOT logo + "PM-BOT · Bug-Triage Agent" + "more_vert" icon
  - Conversation: AI proposes RSD structure → User refines → AI generates → "Generating..." indicator
  - Input area: textarea + "Regenerate Section" / "View RSD Methodology" chip buttons + send button

- Right panel (~38%): Live RSD document
  - Top meta bar: version pill (e.g., v7) + "68% Complete" with progress bar
  - Tabs: Document (active) | Sections | Changelog
  - Document content with numbered sections:
    01. Environment (browser/OS/build/account context)
    02. Expected Behaviour
    03. Actual Behaviour
    04. Reproduction Steps (numbered, code blocks for any commands)
    05. Severity Assessment (with rationale)
    Below: greyed-out placeholders for upcoming sections

- Top header (sticky):
  - Breadcrumb: Submissions > SUB-0093: Payment Retry Notifications failing on iOS > Bug Workspace
  - Right side: "Submission Score" mini-gauge + "Save Draft" + primary "Mark for AI Replication" CTA (instead of "Mark as Final")
  - Status pill: "RSD v7 — Ready for Replication"

- Use the same canonical 3-panel pattern, glass-panel chat header, soft shadows, version badges as B02.

Use Product Hub design system.
```

### 2.2 — Bug Replication Result (intermediate state)

```
Generate a new screen: Bug Replication Result.

Page purpose: After PM-BOT · Bug Replication Agent runs, this screen shows whether replication succeeded or failed, with full evidence. From here, the bug either continues to triage (if reproduced) or hands to QA for manual replication (if failed).

Two visual states (toggle in mockup or show both):

STATE A — Replicated by AI (success):
- Top: "Replicated by AI ✓" pill (emerald) + RSD title + "Re-run" outline button
- Hero card: large emerald checkmark icon + "Replication confirmed" + summary stats (attempts: 1, time: 3.2s, cost: $0.12)
- Evidence section (grid):
  - "Run Log" card with collapsible timeline of replication steps
  - "Evidence Artifacts" card with chips/files (e.g., screenshot.png, log.txt, video.mp4)
  - "Environment Used" card with browser/OS/build details
- Bottom CTA bar: "Continue to Triage" primary + "Edit RSD" outline + "View Backlog Item" link

STATE B — Replication Failed:
- Top: "Replication Failed" pill (amber) + RSD title + "Re-run" outline button
- Hero card: amber warning icon + "AI couldn't reproduce" + summary stats (attempts: 3, time: 9.6s, cost: $0.36)
- "Why it failed" section: bulleted reasons inferred by AI (e.g., "Could not access user-specific data", "Stripe sandbox returned different state", "Cookies/session unavailable")
- Bottom CTA bar: PRIMARY "Hand to QA for Manual Replication" + "Re-run with hints" outline + "Edit RSD" outline

Use Product Hub design system. Match the soft card aesthetic of B03 Request Tracking.
```

### 2.3 — Manual Bug Replication

```
Generate a new screen: Manual Bug Replication.

Page purpose: When PM-BOT · Bug Replication Agent fails, a QA engineer manually attempts to reproduce the bug. They mark the outcome (Reproduced / Cannot Reproduce) and annotate the RSD with their findings. AI Test Agent assists with diagnostic suggestions.

Layout (mirrors E02 UAT Testing):
- Top: Breadcrumb to Bug Workspace > Manual Replication, RSD title with "In Manual Replication" pill (orange), severity tag

- Left panel (55%, light surface):
  - Section "RSD Reference" — collapsed accordion sections with the original RSD content (Environment, Expected, Actual, Repro Steps)
  - Section "AI Attempt Log" — collapsible accordion showing what PM-BOT · Bug Replication Agent tried and why each attempt failed
  - Section "Replication Outcome" — radio group: 
    () Reproduced exactly
    () Reproduced partially (annotate which steps differed)
    () Cannot Reproduce
  - Section "Findings" — rich-text textarea with file upload zone for screenshots/video/log dumps
  - Bottom CTA bar: "Update RSD" outline + "Submit & Triage" primary

- Right panel (45%, surface-container):
  - Header: "PM-BOT · Test Agent" with sparkle icon + "ANALYZING REPLICATION ATTEMPTS" status text
  - Chat conversation:
    - AI message: "Based on the AI's failed attempts, I suggest checking these 3 things..." with bulleted suggestions
    - AI proposes: "Did you try [specific scenario]?" with quick-reply chips
    - User can ask follow-up questions
  - Input field at bottom (matches E02's chat input pattern)

Use Product Hub design system. Layout structure exactly matches E02 UAT Testing.
```

### 2.4 — Bug Triage Queue (recommended)

```
Generate a new screen: Bug Triage Queue.

Page purpose: Engineering Lead or QA Lead views the pipeline of bugs awaiting triage decisions. Filters by severity, status, age, source. Bulk-assigns to engineers or promotes to Backlog.

Layout (mirrors B05 PRD Evaluation queue):
- Top header: Title "Bug Triage" + tab toggles: Triage Queue (active) | In Manual Replication | Resolved | Cannot Reproduce
- Filter bar: Severity dropdown (Low/Medium/High/Critical) | Status dropdown | Source dropdown (Stakeholder / UAT) | Age range picker | Search input + "Bulk Assign" outline button

- Main table:
  - Columns: Checkbox | Bug Title (linked) | Bug ID | Severity badge (color-coded: green/amber/orange/red) | Status (RSD Drafted / In AI Replication / Replication Failed / Reproduced / Cannot Reproduce) | AI Replication Result (mini icon: ✓ green or ✗ amber or - grey) | Submitter (avatar + name) | Submitted date | Assigned engineer (or "Unassigned" italic)
  - 8 example rows with varied severities and statuses
  - One row highlighted (selected) with light indigo background

- Right slide-out panel (500px, opens on row select):
  - Bug summary header (title, severity, submitter)
  - "Open RSD" button (outline) → links to Bug Workspace
  - Sections: Environment / Reproduction Status / Severity Confirmation
  - Actions: "Promote to Backlog" primary + "Reassign" outline + "Close as Cannot Reproduce" red outline
  - Below: Comments thread

- Right side stat strip (top of main table area): Open Bugs (count) | Awaiting Manual Replication | Awaiting Triage Decision

Use Product Hub design system. Match the table+slide-out pattern from B05 exactly.
```

---

## Section 3 — v2 Admin / Settings screens (optional)

These are explicitly v2 scope per OL-3 and OL-4 in the journey doc. Generate when ready.

### 3.1 — Notification Settings (per-user)

```
Generate a new screen: Notification Settings.

Page purpose: Any user (Stakeholder, PM, Product Lead, Engineering, QA, Admin) configures their notification preferences across channels (Email / In-App / Slack / SMS) per event type.

Layout: settings page with categorized toggle groups
- Top: "Notification Schedule" card with radio: () Real-time () Daily Digest at 9am () Weekly Digest on Mondays
- Per-event sections (cards with section headers), each containing 4-channel toggle row per event:
  - "Request Lifecycle" card: Submit confirmation / PRD ready for review / PRD approved / Backlog committed / Released
  - "PRD Activity" card: Mention in comment / New version available / Review assigned to me
  - "Bug Pipeline" card: AI replication result / Manual replication assigned to me / Bug triaged / Bug resolved
  - "Releases" card: New release published / Release affects my domain
- Each toggle row: event name on left, 4 toggle switches on right (E / I / S / SMS) with labels above
- Bottom: "Save Changes" primary + "Reset to Defaults" outline + "Send Test Notification" link

Use Product Hub design system. Settings section conventions (subtle cards, hairline dividers).
```

### 3.2 — Manage Users (admin)

```
Generate a new screen: Manage Users (Admin).

Page purpose: Admin invites/removes users, assigns roles, manages email whitelist for sign-up gating, suspends/reactivates accounts.

Layout (mirrors B05 PRD Evaluation queue):
- Top: Title "Manage Users" + tab toggles: Active (active) | Invited | Suspended | All
- Top-right: "Invite User" primary CTA + "Email Whitelist" outline button (opens modal)
- Filter bar: Role dropdown | Domain dropdown | Search

- Main table:
  - Columns: Avatar+Name | Email | Role pill (Admin / PM / Product Lead / Domain Owner / Engineering Lead / QA / Stakeholder / Viewer) | Domain (if Domain Owner — color pill) | Last Active (relative time) | Status pill (Active green / Invited amber / Suspended red) | Actions (3-dot menu: Edit Role / Change Domain / Suspend / Resend Invite / Remove)

- Right slide-out (500px, opens on row select):
  - User profile header (avatar, name, email)
  - Role assignment dropdown
  - Domain assignment (only visible if role = Domain Owner)
  - Activity log (recent actions, last login, etc.)
  - Permissions matrix (read-only summary of what this role can do)
  - Action footer: "Save Changes" primary + "Suspend" red outline

- Email Whitelist modal (separate state):
  - Header: "Manage Email Whitelist"
  - Description: "Only emails matching these domains can self-register"
  - Tag input with chips (e.g., @company.com, @partners.org) + add new
  - Save / Cancel

Use Product Hub design system.
```

### 3.3 — Platform Settings (admin)

```
Generate a new screen: Platform Settings (Admin).

Page purpose: Admin configures org-wide settings — branding, SSO, default models, integrations, feature flags.

Layout: settings page with vertical section nav on left + content area on right
- Left nav (200px): Organization / Branding / SSO & Authentication / Default LLM Models / Integrations / Feature Flags / Advanced
- Right content: Card per setting group

Example section (Organization, default visible):
- Org Name (input, current: "Acme Corp")
- Org Domain (input, "acme.com")
- Org Logo upload zone
- Default Timezone (dropdown)
- Default Language (dropdown)
- Save / Discard buttons

Other section preview cards (collapsed):
- Branding: primary color picker, logo, favicon, custom CSS toggle
- SSO: Okta / Azure AD / Google Workspace / SAML manual config
- Default LLM Models: dropdowns per feature (links back to [Z01])
- Integrations: Figma / Slack / Confluence / Jira / Linear toggles + connect buttons
- Feature Flags: toggle list of beta features (e.g., "Bug Pipeline v1", "Cross-Domain Comparison v2")
- Advanced: API tokens, webhooks, audit log export

Use Product Hub design system. Settings page conventions (left vertical nav + right content cards).
```

---

## Section 4 — When in doubt

For any new screen not covered above, the Brief.md §6 design system + the 17 already-uploaded screens should be sufficient context for Claude Design. Just describe the new screen's purpose, layout, and key elements — Claude Design will apply the established conventions automatically.

If the output looks off-brand (wrong indigo shade, wrong fonts, sharp corners), check that Claude Design successfully ingested:
1. Brief.md as project context
2. The 17 aligned screens as codebase
3. Specifically that it skipped C02, Z01, E04 (otherwise it'll see two competing palettes)

---

*End of regeneration prompts. See `README.md` for upload sequence and `Brief.md` for the full design system spec.*

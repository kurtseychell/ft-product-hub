# Google Stitch Prompts — Modern AI Product Hub Backoffice UI

> **How to use this document:** Stitch works best with one screen at a time. Start with **Prompt 0** to establish the design system, then paste each numbered prompt into a fresh Stitch session (or iterate within the same session). Each prompt is self-contained so Stitch has full context.

---

## Design System & Global Notes

- **Style:** Clean, modern SaaS backoffice. White background, neutral grays, with a single bold accent color (deep indigo #4F46E5). Subtle shadows, 8px rounded corners, Inter or system sans-serif font.
- **Layout:** Persistent left sidebar navigation (collapsible), top header bar with search + user avatar + notifications bell. Main content area with breadcrumbs.
- **Data density:** Medium-high — this is an internal productivity tool, not a marketing site. Prioritize information density with good whitespace.
- **Responsive:** Desktop-first (1440px), but panels should gracefully stack on tablet.

---

## Prompt 0 — App Shell & Navigation Sidebar

```
Design a modern SaaS backoffice app shell for a product called "Product Hub". Clean, minimal design with a white background, deep indigo (#4F46E5) accent color, subtle gray borders, and 8px rounded corners on all cards and containers.

Layout:
- Collapsible left sidebar (240px expanded, 64px collapsed) with a dark navy (#1E1B4B) background
- Sidebar logo area at top showing "Product Hub" with a hexagonal icon
- Sidebar navigation grouped into sections with small gray uppercase labels:
  - MAIN: Dashboard, Submissions
  - PRODUCT: PRD Generator, PRD Viewer, PRD Evaluation, Research & Analysis, RICE Scoring, Speckit Specs, Figma Designs
  - BACKLOG: Global Backlog, Domain Backlogs, Priority Board, Quarterly Roadmap
  - DELIVERY: Tech Handover, Delivery Tracker, UAT Testing, Release Notes
  - INSIGHTS: Success Metrics, Reports
  - ADMIN: Users, Platform Settings, LLM Costs
- Each nav item has a small icon to its left and a subtle hover state (indigo-tinted background)
- Active nav item has a solid indigo left border accent and light indigo background
- Top header bar (64px) with: breadcrumb trail on the left, global search input (pill-shaped) in the center, and on the right: a notification bell icon with a red badge count, and a user avatar circle with dropdown

The main content area should show a placeholder "Dashboard" page with a welcome banner and 6 summary stat cards in a 3x2 grid (Total Submissions, Active PRDs, In Backlog, In Development, Ready for UAT, Released This Quarter). Each card has a large number, a label, and a subtle trend arrow (up/down) with a percentage.
```

---

## Prompt 1 — Login & Registration

```
Design a clean login page for "Product Hub", a modern SaaS product management tool. Deep indigo (#4F46E5) accent, white background, Inter font.

Left side (50%): A tall indigo-to-purple gradient panel with the Product Hub logo (hexagonal icon + wordmark in white), a tagline "From idea to delivery — powered by AI", and subtle abstract geometric line art in the background.

Right side (50%): Centered login form with:
- "Welcome back" heading and "Sign in to your account" subtext
- Email input field with envelope icon
- Password input field with lock icon and show/hide toggle
- "Remember me" checkbox and "Forgot password?" link on the same row
- Large indigo "Sign In" button, full width
- Divider line with "or" in the middle
- "Sign in with Google" button (outline style with Google icon)
- Bottom text: "Don't have an account? Request Access" — the Request Access link is indigo

Below the form, a small muted note: "Access is restricted to whitelisted email addresses. Contact your admin to be added."
```

---

## Prompt 2 — Stakeholder Submission Form

```
Design a multi-step submission form page titled "Submit a Product Idea" inside a SaaS backoffice app. Clean, modern design with deep indigo (#4F46E5) accent, white card on a light gray (#F9FAFB) background, 8px rounded corners.

Top of page: Breadcrumb (Dashboard > Submissions > New Submission). Below it, a horizontal stepper showing 3 steps: "1. Idea Details" (active, indigo), "2. Attachments" (upcoming, gray), "3. Review & Submit" (upcoming, gray).

Step 1 visible — a white card with the form:
- "Idea Title" — text input
- "Problem Statement" — large textarea (4 rows) with placeholder "What problem does this solve?"
- "Target Users" — multi-select dropdown with tag chips (e.g., "Internal Ops", "End Customers", "Partners")
- "Business Domain" — single select dropdown (e.g., Payments, Onboarding, Risk, Growth, Platform)
- "Estimated Impact" — radio button group: Low / Medium / High / Critical
- "Additional Context" — rich text editor area with basic formatting toolbar
- "Attachments" section — a dashed-border dropzone with upload icon, text "Drag & drop files here or click to browse", and a note "Supports PDF, DOCX, PNG, JPEG up to 25MB"
- Two buttons at the bottom right: "Save as Draft" (outline) and "Continue to Attachments" (solid indigo with right arrow)

Show the sidebar navigation on the left with "Submissions" highlighted.
```

---

## Prompt 3 — PRD Generator & Validator (AI Chat Interface)

```
Design a PRD Generator page inside a SaaS backoffice. Clean, modern, indigo (#4F46E5) accent. This page has a split layout.

Left panel (55%): An AI chat conversation interface for generating and refining a PRD.
- Header: "PRD Generator" title with a sparkle/AI icon, and a dropdown to select the source submission ("Payment Retry Logic — #SUB-0042")
- Chat area with alternating messages:
  - AI message (light gray bubble, left-aligned): "I've analyzed the submission and generated a draft PRD. Here's the structure I recommend..." followed by a bulleted outline
  - User message (indigo bubble, right-aligned): "Add more detail to the user stories section and include edge cases for failed retries"
  - AI message: "Updated. I've expanded the user stories to 8 scenarios including 3 edge cases for retry failures..."
  - A typing indicator showing AI is generating
- Input area at bottom: A text input with placeholder "Ask the AI to refine the PRD..." with a send button (indigo arrow) and a small "Regenerate PRD" button with refresh icon

Right panel (45%): A live PRD preview panel.
- Tab bar at top: "Markdown" (active), "HTML Preview", "Export" tabs
- Below tabs: The rendered PRD document with proper headings (H1: PRD title, H2 sections: Overview, Problem Statement, User Stories, Requirements, Success Metrics, Open Questions)
- A floating action bar at the bottom of this panel with icon buttons: Download as PDF, Download as DOCX, Download as PPTX, Copy Markdown, and "Validate PRD" (indigo button with checkmark)

Show the sidebar with "PRD Generator" highlighted.
```

---

## Prompt 3A — PRD Document Viewer (Multi-Format)

```
Design a PRD Document Viewer page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Full-width layout for immersive document reading.

Top: Breadcrumb (Product > PRD Generator > PRD-042: Payment Retry Logic > Viewer). Title shows the PRD name with a status badge "Approved" (green). Right side: "Share Link" button (outline), "Print" button (outline), and an "Export" dropdown button (solid indigo) with options for .md, .html, .pdf, .pptx, .docx.

Tab bar below the title with 5 format tabs, each with a small icon:
- "Markdown" (active, indigo underline) — document icon
- "HTML Preview" — browser icon
- "Slide Preview" — presentation icon
- "PDF" — file icon
- "Images" — gallery icon

Main content — Markdown tab active:
- Left side (20%): An auto-generated table of contents sidebar listing all H2 and H3 headings from the PRD, with the current section highlighted in indigo. Clicking a heading scrolls the document.
- Right side (80%): The rendered Markdown PRD with proper typography — H1 title, H2 section headers (Overview, Problem Statement, User Stories, Requirements, Success Metrics, Open Questions), tables, bulleted lists, and inline code blocks. The content looks like a polished, readable document.

Right-edge sticky action bar (vertical, narrow):
- "Annotate" toggle button (pencil icon) — when active, clicking any paragraph shows a small comment popover with a text input and "Save Annotation" button
- "Version History" button (clock icon) — opens a slide-out drawer from the right listing version entries: "v3 — Apr 12, 2026 — Kurt Carabott", "v2 — Apr 10, 2026", "v1 — Apr 8, 2026". Each entry has a "View" and "Compare" button. The compare view shows a side-by-side diff with green highlights for additions and red for deletions.

Bottom status bar (subtle gray): Author name, Created date, Last modified date, Word count (2,847 words), and linked Submission ID (#SUB-0042).

Show the sidebar with "PRD Viewer" highlighted under PRODUCT.
```

---

## Prompt 3B — Product Processing & Evaluation

```
Design a PRD Evaluation page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent.

Top: Title "PRD Evaluation" with 3 tab toggles: "Review Queue" (active, indigo underline), "Completed Reviews", "My Evaluations". Below: a filter bar with dropdowns for Domain, Status (Pending / In Review / Revised / Approved / Rejected), Assigned Reviewer, and a Date Range picker. When checkboxes are selected in the queue, a "Bulk Approve" button appears (indigo, enabled only when all selected have avg score ≥ 4.0).

Main content — Review Queue table:
Columns: Checkbox, PRD Title (bold, linked), Submission ID (#SUB-xxxx), Domain (colored pill — "Payments" blue, "Growth" green, etc.), Submitter (avatar circle + name), Submitted Date, Assigned Reviewer (avatar + name or "Unassigned" in gray italic), Auto-Score (a small horizontal bar filled proportionally, with a number like "3.8"), Status badge (colored: Pending=gray, In Review=yellow, Approved=green, Rejected=red, Revised=blue), Actions (three-dot menu: Assign, View PRD, Evaluate).

Show 8 rows of data with varied statuses. One row highlighted with a light indigo background to indicate it's selected.

Right slide-out evaluation panel (500px wide, overlaying the table from the right):
- Header: PRD title "Payment Retry Logic" with domain tag and submitter info
- "Open Full PRD" button (outline indigo, opens in PRD Viewer)
- 4 evaluation criteria rows, each with:
  - Criterion label: "Completeness", "Strategic Alignment", "Technical Feasibility", "Clarity & Quality"
  - 5 clickable star icons (3 out of 5 filled for demo)
  - A small text input for an optional comment per criterion
- "Overall Assessment" — a textarea (3 rows) with placeholder "Summarize your evaluation..."
- 3 decision buttons at the bottom in a row:
  - "Approve" (green button with checkmark)
  - "Request Revisions" (yellow/amber button with refresh icon)
  - "Reject" (red button with X icon)
  - Below the buttons: a "Decision Rationale" textarea that appears when any decision button is clicked, with a note "Required — minimum 20 characters"
- Collapsible "Evaluation History" section at the very bottom showing past reviews if any

Show the sidebar with "PRD Evaluation" highlighted under PRODUCT.
```

---

## Prompt 3C — PRD Research & Analysis (LLM Bot)

```
Design a Research & Analysis page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Split layout similar to the PRD Generator.

Left panel (55%): "Research Assistant" AI chat interface.
- Header: "Research & Analysis" title with a sparkle/AI icon, a PRD selector dropdown ("Payment Retry Logic — PRD-042"), and a "Research Mode" toggle with 3 pill-shaped options: "Quick Scan" (5 min), "Standard" (15 min, selected/active in indigo), "Deep Dive" (30 min)
- Below header: 5 quick-action buttons in a horizontal row as small outlined pills: "Market Analysis", "Competitor Scan", "User Sentiment", "Tech Feasibility", "Full Research"
- Chat conversation area:
  - AI message (light gray bubble): "I've loaded PRD-042: Payment Retry Logic. Based on the problem statement, I'll research market demand, competitor approaches, and technical feasibility. Starting with market analysis..." with a small "[3 sources]" link at the bottom of the bubble
  - AI message: A formatted finding with a mini comparison table inside the bubble showing 3 competitors (Stripe, Adyen, Braintree) with columns for Retry Logic, Max Retries, and Smart Routing. Below the table: "Stripe's smart retry engine achieves 15% recovery rate. Your proposed approach targets 20% with ML-based timing."
  - User message (indigo bubble): "What's the user sentiment around failed payment retries?"
  - AI message: "Analyzing support tickets and public reviews..." with a sentiment summary showing a small bar: 72% Negative, 18% Neutral, 10% Positive, and a 2-line summary
- Input area: text field with "Ask a research question..." placeholder, send button, and an "Attach Data" button (paperclip icon)

Right panel (45%): "Research Report" live document.
- Tab bar: "Live Report" (active), "Sources", "History"
- Live Report content — a continuously updating document:
  - "Executive Summary" section with 3 bullet points
  - "Market Landscape" section with narrative text
  - "Competitive Analysis" section with a comparison table
  - "User Sentiment" section with a sentiment score bar
  - "Technical Feasibility" section with risk flags
  - A highlighted "Priority Recommendation" card at the bottom with a green "PURSUE" badge, a confidence bar at 78%, and 3 supporting evidence bullets
- Bottom action bar: "Generate PDF Report" button (solid indigo), "Attach to PRD" button (outline), "Share with Team" button (outline), "Export Markdown" button (outline)

Show the sidebar with "Research & Analysis" highlighted under PRODUCT.
```

---

## Prompt 4 — RICE Scoring with Multiple Agents

```
Design a RICE Scoring page for a SaaS product management backoffice. Clean, modern design, indigo (#4F46E5) accent.

Top section: A card with the product idea title "Payment Retry Logic" and a tag showing its current status "PRD Approved". Below it, a horizontal bar showing the 4 RICE dimensions as tab-like segments: Reach, Impact, Confidence, Effort — each with a circular score badge.

Main content — a 2-column layout:

Left column (60%): "Agent Assessments" section. Show 3 agent cards stacked vertically, each representing a different AI evaluator:
- Card 1: "Market Analyst Agent" with a blue avatar icon. Shows its individual R/I/C/E scores as small pill badges, a 2-line rationale summary, and an "expand" chevron for full reasoning
- Card 2: "Technical Feasibility Agent" with a green avatar icon. Same layout with different scores
- Card 3: "Business Strategy Agent" with an orange avatar icon. Same layout with different scores
- Below the 3 cards: A "Consensus Score" banner with a large composite RICE score number (e.g., "31.5") calculated from the weighted average, with a confidence interval range shown as a subtle bar

Right column (40%):
- A radar/spider chart visualizing the 4 RICE dimensions
- Below it, a "Score History" mini timeline showing past scoring events with dates and score changes
- A "Compare" button (outline) to compare this item's score with others
- An "Override Score" section with 4 small number input fields (R, I, C, E) and a "Save Manual Override" button, with a note "Manual overrides are logged for audit"

Show the sidebar with "RICE Scoring" highlighted.
```

---

## Prompt 4A — Speckit Specs Generation

```
Design a Speckit Specifications page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Two-zone layout — spec list on the left, spec detail on the right.

Top bar: Breadcrumb (Product > Speckit Specs > PRD-042: Payment Retry Logic). Title "Speckit Specifications" with a PRD selector dropdown. Status summary text: "18 specs generated — 12 approved, 4 in review, 2 draft". Buttons on the right: "Generate Specs" (solid indigo with sparkle icon), "Regenerate All" (outline), "Export All" (outline). View toggle: "List" (active) | "Dependency Graph".

Left zone (40%) — Spec List:
A scrollable list grouped by type with collapsible section headers. Each section has a small icon, title, and count badge:
- "API Contracts" (globe icon, 4 items) — expanded, showing:
  - "POST /payments/retry" — green "Approved" badge
  - "GET /payments/{id}/status" — green "Approved" badge
  - "PATCH /payments/{id}/retry-config" — yellow "In Review" badge
  - "Webhook /retry-events" — gray "Draft" badge
- "Data Models" (database icon, 3 items) — collapsed
- "UI Components" (layout icon, 4 items) — collapsed
- "Business Logic" (cpu icon, 4 items) — collapsed
- "Integrations" (plug icon, 3 items) — collapsed

Each item in the list shows: title, type icon, status badge (green/yellow/gray/red), and a small AI confidence indicator (green dot = High, yellow = Medium, red = Low). The currently selected item has a light indigo background.

A "+ Add Spec Item" button at the bottom of each section (subtle, with a plus icon).

Right zone (60%) — Spec Detail:
Showing the detail for the selected spec "POST /payments/retry":
- Title (editable inline) with type label "API Contract" (blue pill)
- Status dropdown (showing "Approved" in green)
- "AI Confidence: High" indicator (green dot with text)
- Section: "Description" — a rich text area showing the endpoint spec: HTTP method, URL, request body schema (JSON formatted in a code block), response schema, error codes table (400, 401, 404, 429, 500 with descriptions)
- Section: "Acceptance Criteria" — a numbered checklist with 6 items, each with a checkbox:
  1. "Endpoint accepts valid payment ID and retry configuration"
  2. "Returns 429 when max retry limit exceeded"
  3. "Triggers async retry job within 5 seconds"
  (etc.)
- Section: "Edge Cases" — bulleted list with 4 items:
  - "Payment already in terminal success state"
  - "Concurrent retry requests for same payment"
  (etc.)
- Section: "Dependencies" — linked pills showing: "RetryPolicy schema" (data model), "Stripe webhook handler" (integration), "Max retry limit enforcement" (business logic)
- Section: "Source PRD Section" — a collapsible light gray quote block showing the PRD paragraph this spec was derived from, with a small "View in PRD" link
- Action buttons at the bottom: "Approve" (green), "Request Revision" (yellow), "Regenerate" (outline with refresh icon), "Delete" (red outline)

Show the sidebar with "Speckit Specs" highlighted under PRODUCT.
```

---

## Prompt 4B — Figma Design Generation

```
Design a Figma Design Generation page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Gallery-centric layout.

Top bar: Breadcrumb (Product > Figma Designs > PRD-042: Payment Retry Logic). Title "Design Generation" with a PRD selector dropdown. Buttons: "Generate Designs" (solid indigo with sparkle icon), "Push All to Figma" (outline with Figma logo icon), view toggle: "Gallery" (active) | "Flow View".

Configuration panel (collapsible card below the top bar, currently expanded):
- "Design Style" selector: 3 cards in a row, each with a thumbnail preview and label:
  - "Wireframe" (gray sketch style, line-art preview) — outline border
  - "Low-Fidelity" (basic shapes, placeholder text preview) — outline border
  - "High-Fidelity" (polished, Product Hub branded preview) — selected with indigo border and checkmark
- "Screens to Generate" section: A list of auto-suggested screens with checkboxes (all checked):
  - ☑ "Retry Configuration Panel"
  - ☑ "Retry Status Dashboard"
  - ☑ "Notification Settings"
  - ☑ "Payment Retry History"
  - ☑ "Retry Analytics View"
  - ☑ "Error State & Fallback"
- Small "Add Custom Screen" link at the bottom with a plus icon

Main content — Gallery view:
A responsive 3-column grid of screen cards. Each card is a white rounded container with:
- A large thumbnail preview area (16:10 aspect ratio) showing a generated UI mockup (use placeholder gray/indigo wireframe-style rectangles with layout elements to suggest screens)
- Below the preview: Screen name in bold (e.g., "Retry Configuration Panel")
- A small "PRD Section: Requirements" tag (linked pill)
- Status badge: "Approved" (green), "Draft" (gray), "Generating..." (indigo with a spinner), "Pushed to Figma" (purple with Figma icon)
- "3 variants" badge if applicable (small, muted)
- Row of small icon buttons: Expand (maximize icon), Compare Variants (columns icon), Regenerate (refresh), Push to Figma (Figma icon), Delete (trash)

Show 6 cards: 2 Approved, 2 Draft, 1 Generating, 1 Pushed to Figma.

One card in an "expanded" overlay state — a modal/lightbox showing:
- The design rendered large and zoomable
- Right sidebar in the overlay (300px):
  - "Linked Specs" section with 3 linked spec item pills (e.g., "RetryConfigPanel component", "POST /payments/retry")
  - "Feedback & Comments" section with a comment thread (2 comments shown)
  - "Variants" section: a horizontal thumbnail strip showing 3 variants, with the active one highlighted in indigo border
  - "Regenerate with Feedback" — text input with placeholder "Describe what to change..." and a "Regenerate" button (indigo)
  - Action buttons: "Approve" (green), "Push to Figma" (outline with Figma icon)

Show the sidebar with "Figma Designs" highlighted under PRODUCT.
```

---

## Prompt 5 — Global Backlog & Priority Board

```
Design a Kanban-style priority backlog board for a SaaS product management backoffice. Modern, clean, indigo (#4F46E5) accent, white background.

Top bar: Title "Priority Backlog" with view toggle buttons (Board view active, List view, Table view). Filters row: dropdowns for Domain, RICE Score Range, Status, Assignee, and a search input. A "Compare Selected" button (outline indigo) on the right.

Main content: A horizontal Kanban board with 5 columns, each with a header, item count badge, and colored top border:
- "New" (gray border) — 4 cards
- "Under Review" (yellow border) — 3 cards
- "Approved" (blue border) — 5 cards
- "In Development" (indigo border) — 3 cards
- "Released" (green border) — 2 cards

Each card in the columns shows:
- Idea title (bold, truncated to 1 line)
- Domain tag (small colored pill: "Payments" in blue, "Growth" in green, etc.)
- RICE score badge (circular, indigo background, white text)
- Tiny avatar circles for the assignee(s)
- A priority indicator (flame icon for critical, arrow-up for high)
- Subtle drag handle dots on the left edge

One card should appear "selected" with an indigo border glow, showing a slide-out detail panel on the right (300px) with: the full title, description excerpt, RICE breakdown, status dropdown, "View PRD" link, "View Specs" link, and an activity timeline at the bottom.

Show the sidebar with "Priority Board" highlighted.
```

---

## Prompt 5A — Domain Backlogs & Cross-Idea Comparison

```
Design a Domain Backlogs page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. This is a domain-specific backlog view with a powerful comparison feature.

Domain context bar (top):
- 5 domain tab buttons in a horizontal row, each with a colored left border and an item count badge:
  - "Payments" (blue, active with indigo background, 12 items)
  - "Onboarding" (teal, 8 items)
  - "Risk" (orange, 6 items)
  - "Growth" (green, 15 items)
  - "Platform" (purple, 9 items)
- Below the tabs: 4 inline stat badges for the active domain — "Total: 12", "Avg RICE: 28.4", "In Development: 3", "Awaiting Review: 4"
- View toggle buttons: "Ranked List" (active, indigo), "Board", "Table"
- Filter bar: Status dropdown, RICE Score Range slider, Assignee dropdown, Priority Flag toggle (star icon — "Domain Priority Only" / "All")
- "Compare Selected" button (outline indigo, currently disabled since no items are checked)

Main content — Ranked List view:
A numbered, vertically stacked list of items in priority order. Each row is a white card with subtle shadow:
- Left: Drag handle (6 dots), rank number (#1, #2, etc.), and a checkbox
- Center:
  - Item title (bold, linked): e.g., "Payment Retry Logic"
  - Status badge (green "Approved", yellow "Under Review", etc.)
  - RICE score in a circular indigo badge (e.g., "31.5")
  - Research recommendation pill: "Pursue" (green), "Defer" (yellow), or "Reject" (red)
  - Gold filled star icon for "Domain Priority" flagged items (3 of 8 visible items have this)
- Right: Assignee avatar, target quarter tag ("Q2 2026"), and an expand chevron

One item expanded to show a detail row below it:
- Description excerpt (2 lines, muted text)
- "Domain Notes" — an editable text field with placeholder "Add domain-specific notes..." (one item has notes: "Blocked on Stripe API v3 migration — revisit after May")
- Quick-action buttons: "View PRD" (outline), "View Specs" (outline), "View Research" (outline), "Flag as Domain Priority" (star outline)

Show 8 items total. Items #1 and #3 have the gold Domain Priority star.

Comparison panel (shown as if user selected 3 items and clicked Compare):
A full-width panel overlaying the bottom 60% of the page, with a semi-transparent backdrop. 3 items shown as columns:
- Column headers: Item title + domain tag + RICE badge
- Comparison rows:
  - "RICE Breakdown" — 4 sub-rows (R, I, C, E) with scores and color-coded cells (green for highest, red for lowest among the 3)
  - "RICE Consensus Score" — large numbers: 31.5, 24.0, 27.8 with bar visualization
  - "Research Recommendation" — Pursue (green badge, 78%), Defer (yellow, 45%), Pursue (green, 62%)
  - "Evaluation Score" — star ratings: 4.2, 3.1, 3.8 out of 5
  - "Stakeholder Impact" — Critical (red), Medium (yellow), High (orange)
  - "Effort Estimate" — M, XL, L (t-shirt sizes)
  - "Dependencies" — 2, 5, 1 (with count badges)
  - "Submissions" — 4, 1, 3 (how many stakeholder submissions feed each)
- Bottom "Winner Highlight" row: green background on the cell that wins each dimension
- Top-right of panel: "Close" (X) button and "Export Comparison as PDF" button (outline)

Cross-Domain Summary (collapsible bar at very top of page, above domain tabs, collapsed by default — show it expanded):
- A horizontal grouped bar chart showing item counts per domain, with bars colored by status (New=gray, Under Review=yellow, Approved=blue, In Dev=indigo, Released=green)
- Average RICE score per domain shown as small number badges above each domain group
- "View Global Backlog" link button on the right

Show the sidebar with "Domain Backlogs" highlighted under BACKLOG.
```

---

## Prompt 6 — Quarterly Roadmap

```
Design a quarterly product roadmap view inside a SaaS backoffice. Modern, clean, indigo (#4F46E5) accent.

Top bar: Title "Quarterly Roadmap" with quarter selector tabs: "Q1 2026", "Q2 2026" (active, indigo underline), "Q3 2026", "Q4 2026". Buttons on the right: "Add Item" (solid indigo), "Export" (outline), and a toggle between "Timeline" and "Swimlane" views.

Main content: A Gantt-style horizontal timeline view.
- X-axis: Months within Q2 (April, May, June) divided into weeks with light vertical gridlines
- Y-axis: Grouped by domain swimlanes — "Payments", "Onboarding", "Risk", "Growth", "Platform" — each row labeled on the left with a colored dot

Horizontal bars span across weeks representing each initiative:
- Each bar is colored by its domain color, shows the initiative name inside it, and has a small RICE score badge on the right end
- Bars at different stages have different opacities: planned (50% opacity), in-progress (100% with a progress stripe), completed (100% with checkmark)
- Dependency arrows (thin gray dashed lines) connect some bars
- A red vertical "Today" line at April 15

Below the timeline: A summary row showing resource allocation per month as small stacked bar charts.

Bottom card: "Roadmap Notes" — a collapsible section with editable text for quarterly goals and key decisions.

Show the sidebar with "Quarterly Roadmap" highlighted.
```

---

## Prompt 7 — Tech Handover Package

```
Design a Tech Handover Package page for a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent.

Top: Breadcrumb (Delivery > Tech Handover > Payment Retry Logic). Title "Tech Handover Package" with a status badge "Ready for Handover" (green). A "Download All as ZIP" button (solid indigo) on the right.

Main content: A checklist-style layout with expandable sections, each as a white card:

1. "PRD Document" — checkmark icon (green), subtitle "Last updated Apr 10, 2026". Right side: "View" and "Download" buttons
2. "Speckit Specifications" — checkmark icon (green), subtitle "12 specs generated". Expandable to show a list of spec items with names and status pills
3. "Figma Designs" — checkmark icon (green), subtitle "8 screens, 3 components". Shows a 4-column thumbnail grid preview of the Figma frames (placeholder gray rectangles with frame names below each)
4. "3rd Party Integration Docs" — warning icon (yellow), subtitle "2 of 3 documents uploaded". Shows a file list with: "Stripe API Guide.pdf" (checkmark), "Twilio SMS Docs.pdf" (checkmark), "Risk Engine API" (red "Missing" badge with upload button)
5. "API Contracts" — checkmark icon (green), subtitle "OpenAPI spec attached"
6. "Acceptance Criteria" — checkmark icon (green), subtitle "14 criteria defined"

Right sidebar panel (fixed, 280px): A "Handover Readiness" progress card showing a circular donut chart at 83% complete, with a list of what's done vs. outstanding items. Below it, an "Assign to Engineering" dropdown and a "Send Handover" button (solid indigo).

Show the sidebar with "Tech Handover" highlighted.
```

---

## Prompt 8 — Delivery Tracker

```
Design a Delivery Tracker dashboard inside a SaaS product management backoffice. Modern, clean, indigo (#4F46E5) accent.

Top: Title "Delivery Tracker" with a filter bar: Domain dropdown, Sprint dropdown ("Sprint 14" selected), and status filter toggles (All, On Track, At Risk, Blocked).

Main content — two sections:

Top section: 4 summary metric cards in a row:
- "In Progress" (blue) — count: 7, with mini progress bars
- "On Track" (green) — count: 5
- "At Risk" (yellow) — count: 1, item name shown
- "Blocked" (red) — count: 1, item name shown

Bottom section: A detailed table with columns:
- Item name (linked, bold)
- Domain (colored tag pill)
- Sprint
- Status (colored badge: On Track / At Risk / Blocked / Done)
- Progress bar (percentage filled, colored by status)
- Engineering Lead (avatar + name)
- Target Date
- "Demo Ready" toggle switch
- Actions menu (three-dot icon)

One row is expanded below the table to show a detail panel with: a mini timeline of engineering updates (commit-style log), blockers list, and a "Ready for Demo & UAT" button (solid indigo with a checkmark).

Show the sidebar with "Delivery Tracker" highlighted.
```

---

## Prompt 9 — UAT Testing Screen

```
Design a UAT Testing page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Split layout.

Left panel (55%): "UAT Test Execution" area.
- Header with the item name "Payment Retry Logic" and a badge "UAT In Progress" (orange)
- A list of acceptance criteria as testable checklist items. Each row shows:
  - Checkbox (checked = green, unchecked = gray, failed = red)
  - Criteria text (e.g., "User receives retry notification within 30 seconds")
  - Status dropdown: Pass / Fail / Blocked / Skipped
  - A small "Add Evidence" button (camera icon) for screenshots
- Progress bar at the top showing "9 of 14 criteria tested — 7 passed, 2 failed"
- A "Bug Report" section at the bottom: a collapsible card where testers can log issues with a title, description, severity dropdown, and "Submit Bug" button

Right panel (45%): "AI Test Assistant" chat interface.
- A chat conversation where the AI helps validate requirements:
  - AI: "Based on the PRD, I've identified 3 edge cases that aren't covered by the current test criteria. Would you like me to add them?"
  - User: "Yes, add them"
  - AI: "Added. I also notice that criteria #4 conflicts with the updated spec from April 8th. The timeout was changed from 30s to 45s. Shall I update?"
- Input field at bottom: "Ask the AI about test coverage, requirements, or edge cases..."

Show the sidebar with "UAT Testing" highlighted.
```

---

## Prompt 10 — Release Notes Generator

```
Design a Release Notes page inside a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent.

Top: Title "Release Notes" with a dropdown for the release version ("v2.4.0 — April 2026") and buttons: "Auto-Generate from PRDs" (solid indigo with sparkle icon), "Preview" (outline), "Publish" (green).

Main content: A rich text editor area showing a formatted release notes draft:
- Release header: "Product Hub v2.4.0 — April 2026"
- Sections with icons: "New Features" (rocket icon, 3 bullet items with bold titles and descriptions), "Improvements" (wrench icon, 4 items), "Bug Fixes" (bug icon, 2 items), "Known Issues" (warning icon, 1 item)
- Each item has a small linked reference to its PRD ID (e.g., "PRD-042")
- A formatting toolbar at the top of the editor (bold, italic, headings, lists, links, image insert)

Right sidebar (300px):
- "Audience" section with checkboxes: Internal Stakeholders, External Customers, Engineering Team
- "Distribution" section: checkboxes for Email, Slack, In-App Notification, Confluence
- "Included Items" section: A scrollable list of shipped items that were auto-pulled, each with a checkbox to include/exclude and the item name + domain tag
- "Schedule" section: a date/time picker for scheduled publish

Show the sidebar with "Release Notes" highlighted.
```

---

## Prompt 11 — Success Metrics & Reports

```
Design a Success Metrics dashboard inside a SaaS product management backoffice. Modern, clean, indigo (#4F46E5) accent. Data-rich layout.

Top: Title "Success Metrics" with a date range picker (last 30 / 60 / 90 days / custom), and a domain filter dropdown.

Main content — a dashboard grid layout:

Row 1 (4 cards):
- "Ideas Submitted" — large number (47), trend arrow up +12% vs. last period, tiny sparkline
- "PRDs Generated" — 31, trend up +8%
- "Avg. Time to Ship" — "23 days", trend down -15% (improvement, shown in green)
- "Release Adoption" — "78%", trend up +5%

Row 2 (2 charts side by side):
- Left: A line chart "Submissions to Release Pipeline" showing a funnel-style conversion over time (lines for: Submitted, PRD Created, Approved, In Dev, Released) with a legend
- Right: A horizontal stacked bar chart "Domain Distribution" showing how ideas break down by domain per month

Row 3 (2 panels):
- Left: "Top Performing Releases" — a ranked table with columns: Release, Domain, Adoption Rate, User Satisfaction (star rating), Revenue Impact
- Right: "RICE Score Accuracy" — a scatter plot comparing predicted RICE scores vs. actual impact metrics, with a trend line and R² value displayed

Bottom: A "Generate Report" bar with buttons to export as PDF, PPTX, or email a summary to stakeholders.

Show the sidebar with "Success Metrics" highlighted.
```

---

## Prompt 12 — Admin: LLM Costs & Platform Settings

```
Design an Admin Settings page for a SaaS product management backoffice. Clean, modern, indigo (#4F46E5) accent. Tab-based layout.

Top: Title "Admin Settings" with 3 tabs: "LLM Usage & Costs" (active), "Manage Users", "Platform Settings".

Tab 1 — LLM Usage & Costs:
- Top row: 3 stat cards — "Monthly Spend" ($2,847, with a budget bar showing 71% of $4,000 used), "Total API Calls" (12,430), "Avg Cost per PRD" ($1.24)
- A line chart below: "Daily LLM Spend" over the past 30 days, with a dashed horizontal line for the daily budget threshold
- A breakdown table: columns for Feature (PRD Generator, RICE Scoring, UAT Assistant, Research Bot), API Calls, Tokens Used, Cost, Avg Latency. Each row has a sparkline in the last column
- A "Cost Alerts" section: toggle switches for email alerts at 50%, 75%, 90% budget thresholds
- "Model Configuration" section: dropdowns to select LLM model per feature (e.g., GPT-4o, Claude Sonnet, Gemini Pro) with a "Max tokens" slider

Tab 2 hint (grayed preview): A user management table with roles (Admin, Product Manager, Stakeholder, Viewer), invite button, email whitelist manager.

Tab 3 hint (grayed preview): General settings — organization name, SSO config, default domain categories, notification preferences.

Show the sidebar with "Platform Settings" highlighted under ADMIN.
```

---

## Tips for Using These Prompts in Stitch

1. **Start with Prompt 0** — this establishes the app shell. Then iterate on top of it or start new sessions for each screen.
2. **One prompt at a time** — Stitch generates better output when focused on a single screen.
3. **Refine incrementally** — after each generation, use follow-up prompts like "Make the sidebar icons slightly larger" or "Add a dark mode toggle to the header."
4. **Export to Figma** — use Stitch's Figma paste feature to build a complete design system from the generated screens.
5. **Combine into a prototype** — once all screens are generated, link them in Figma to create a clickable prototype.

# Product Hub — Gap Feature Specifications

> **Document purpose:** This specification covers the six features identified as gaps between the original project requirements and the screens currently covered by the Stitch design prompts. Each section is a self-contained, comprehensive spec ready for design, development, and QA.

---

## Table of Contents

1. [PRD Document Viewer (Multi-Format)](#1-prd-document-viewer-multi-format)
2. [Product Processing & Evaluation](#2-product-processing--evaluation)
3. [PRD Research & Analysis (LLM Bot)](#3-prd-research--analysis-llm-bot)
4. [Speckit Specs Generation](#4-speckit-specs-generation)
5. [Figma Design Generation](#5-figma-design-generation)
6. [Domain Backlogs & Cross-Idea Comparison](#6-domain-backlogs--cross-idea-comparison)

---

## 1. PRD Document Viewer (Multi-Format)

### 1.1 Overview

The PRD Document Viewer is a dedicated screen that lets users view any PRD in multiple rendered formats — Markdown, HTML, PowerPoint-style slide preview, PDF, and embedded images — without leaving the platform. It also supports inline annotations, version history, and one-click export to any format.

**Navigation location:** PRODUCT → PRD Generator → (select a PRD) → "View PRD" action opens this screen.

### 1.2 Problem Statement

Currently the PRD Generator (Prompt 3) shows a limited Markdown/HTML preview in a side panel. Stakeholders, product managers, and engineering leads each prefer different consumption formats. Forcing users to download and open external files creates friction and breaks the review workflow. A unified viewer keeps everyone in-context and reduces the time between generation and approval.

### 1.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| PV-01 | Product Manager | I want to view a PRD in rendered Markdown so I can quickly scan structure and content | Markdown tab renders headings, lists, tables, code blocks, and inline images correctly |
| PV-02 | Stakeholder | I want to view a PRD as a styled HTML page so I can see it as it would appear when shared externally | HTML tab renders a styled, print-ready document with the Product Hub branding header/footer |
| PV-03 | Stakeholder | I want to preview the PRD as a slide deck without downloading it | PPT tab renders a slide-by-slide carousel preview (each major H2 section = 1 slide) |
| PV-04 | Engineering Lead | I want to view the PRD as a PDF inline so I can review it without switching apps | PDF tab renders an embedded PDF viewer with zoom, page navigation, and search |
| PV-05 | Any user | I want to view images and diagrams attached to the PRD in a lightbox gallery | Image tab shows all embedded and attached images in a scrollable gallery with lightbox zoom |
| PV-06 | Product Manager | I want to add inline annotations/comments on any section of the PRD | Clicking any paragraph opens a comment popover; comments are saved and visible to all reviewers |
| PV-07 | Any user | I want to see the version history of a PRD and compare two versions side-by-side | Version History panel lists all saved versions with timestamps; selecting two shows a diff view |
| PV-08 | Any user | I want to export the PRD in any format with one click | Export dropdown offers: .md, .html, .pdf, .pptx, .docx — each triggers a download |

### 1.4 UI Description

**Layout:** Full-width content area (no split panel). Breadcrumb at top: `Product > PRD Generator > PRD-042: Payment Retry Logic > Viewer`.

**Tab bar** across the top of the viewer card with five tabs:
- **Markdown** (default) — rendered Markdown with a table of contents sidebar on the left (auto-generated from headings)
- **HTML Preview** — styled HTML document in an iframe-style container
- **Slide Preview** — horizontal carousel of slides, with left/right arrows and a slide counter (e.g., "3 / 12"), plus a thumbnail filmstrip below
- **PDF** — embedded PDF viewer with toolbar (zoom in/out, fit width, page input, download)
- **Images** — masonry grid of all images/diagrams, click to open lightbox

**Right-side action bar** (sticky, vertical):
- "Export" button (dropdown with format options)
- "Annotate" toggle (enables inline commenting mode)
- "Version History" button (opens a slide-out drawer from the right listing versions)
- "Share Link" button (copies a deep link to this PRD view)
- "Print" button

**Bottom status bar:** Shows PRD metadata — Author, Created date, Last modified, Current status badge, Word count, and linked Submission ID.

### 1.5 Data Model Hints

```
PRDDocument {
  id: UUID
  submission_id: FK → Submission
  title: string
  content_markdown: text          // source of truth
  content_html: text              // generated from markdown
  content_pdf_url: string         // generated PDF stored in object storage
  content_pptx_url: string        // generated PPTX stored in object storage
  images: [{ id, url, caption }]
  annotations: [{ id, user_id, section_anchor, body, created_at, resolved }]
  versions: [{ version_number, content_markdown, created_at, created_by }]
  status: enum (Draft, In Review, Approved, Archived)
  created_at: datetime
  updated_at: datetime
}
```

### 1.6 Integration Points

- **PRD Generator (Prompt 3):** The "View PRD" link in the generator's export bar navigates to this viewer.
- **Tech Handover (Prompt 7):** The "View" button in the PRD Document checklist item opens this viewer.
- **Product Processing & Evaluation (Gap #2):** Reviewers access this viewer from the evaluation screen to read the full PRD.
- **Export engine:** A backend service converts Markdown → HTML, PDF, and PPTX on demand or on save.

### 1.7 Acceptance Criteria (QA)

- [ ] All five tabs render correctly for a PRD with 10+ sections, 5+ images, and 2+ tables
- [ ] Annotations persist across sessions and are visible to other users in real-time
- [ ] Version diff highlights additions (green) and deletions (red) at the paragraph level
- [ ] Export produces valid files that open correctly in their native applications
- [ ] Slide preview auto-generates one slide per H2 section with content summary
- [ ] PDF viewer supports text search within the document
- [ ] Page loads in under 2 seconds for a PRD with 5,000 words

---

## 2. Product Processing & Evaluation

### 2.1 Overview

The Product Processing & Evaluation screen is a structured review workflow where designated reviewers (product leads, domain owners) assess generated PRDs against business criteria, add their evaluation scores, and make approve/reject/revise decisions. This is the gate between PRD generation and backlog entry.

**Navigation location:** PRODUCT → (new nav item) "PRD Evaluation" between PRD Generator and Research & Analysis.

### 2.2 Problem Statement

After a PRD is generated, there is no formalized process to evaluate whether it meets quality standards, aligns with strategic goals, or is complete enough to enter the product backlog. Without this gate, low-quality or misaligned PRDs can pollute the backlog and waste downstream effort (RICE scoring, spec generation, design). This screen introduces a structured, auditable evaluation step.

### 2.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| PE-01 | Product Lead | I want to see a queue of PRDs awaiting evaluation so I can prioritize my review time | Evaluation queue shows all PRDs with status "Pending Review", sorted by submission date, with domain and submitter info |
| PE-02 | Product Lead | I want to score a PRD against evaluation criteria (completeness, strategic fit, feasibility, clarity) | Evaluation form shows 4 criteria with 1–5 star ratings and an optional comment per criterion |
| PE-03 | Domain Owner | I want to approve, reject, or request revisions on a PRD with a written rationale | Decision buttons (Approve / Request Revisions / Reject) each require a rationale text field before submission |
| PE-04 | Product Manager | I want to see the evaluation history and scores for my PRD | PRD detail shows all evaluations with reviewer name, scores, comments, and decision |
| PE-05 | Stakeholder | I want to be notified when my submitted idea's PRD has been evaluated | Email and in-app notification sent to the original submitter when a decision is made |
| PE-06 | Product Lead | I want to assign a PRD to a specific reviewer or domain owner | "Assign Reviewer" dropdown on each PRD in the queue, with notification to the assignee |
| PE-07 | Any user | I want to filter the evaluation queue by domain, status, reviewer, and date range | Filter bar with dropdowns for each dimension; results update in real-time |
| PE-08 | Product Lead | I want to bulk-approve PRDs that meet a minimum auto-score threshold | Checkbox selection on queue items + "Bulk Approve" button, enabled when all selected items have avg score ≥ 4.0 |

### 2.4 UI Description

**Layout:** Standard content area with the evaluation queue as the default view.

**Top bar:** Title "PRD Evaluation" with tab toggles: "Review Queue" (active) | "Completed Reviews" | "My Evaluations". Filter bar below: Domain, Status (Pending / In Review / Revised / Approved / Rejected), Assigned Reviewer, Date Range. Bulk action bar appears when checkboxes are selected.

**Queue view (table):**
Columns: Checkbox, PRD Title (linked), Submission ID, Domain (color pill), Submitter (avatar + name), Submitted Date, Assigned Reviewer, Auto-Score (AI-generated preliminary score as a bar), Status badge, Actions (three-dot menu: Assign, View PRD, Evaluate).

**Evaluation modal/panel (opens on "Evaluate" action):**
A slide-out right panel (500px) containing:
- PRD summary header (title, domain, submitter, word count)
- "Open Full PRD" button → links to the PRD Document Viewer (Gap #1)
- **Evaluation Criteria** — four rows, each with:
  - Criterion name (Completeness, Strategic Alignment, Technical Feasibility, Clarity & Quality)
  - 1–5 star rating (clickable stars)
  - Optional comment text input
- **Overall Assessment** textarea
- **Decision buttons** at the bottom: "Approve" (green), "Request Revisions" (yellow), "Reject" (red) — each click opens a rationale text field that must be filled before confirming
- Previous evaluations (if any) shown in a collapsible "Evaluation History" section at the bottom

**Completed Reviews tab:** Same table but showing PRDs that have been evaluated, with the final decision badge and average score.

### 2.5 Data Model Hints

```
PRDEvaluation {
  id: UUID
  prd_id: FK → PRDDocument
  reviewer_id: FK → User
  assigned_by: FK → User (nullable)
  scores: {
    completeness: int (1-5),
    strategic_alignment: int (1-5),
    technical_feasibility: int (1-5),
    clarity_quality: int (1-5)
  }
  score_comments: {
    completeness: text,
    strategic_alignment: text,
    technical_feasibility: text,
    clarity_quality: text
  }
  overall_assessment: text
  decision: enum (Approved, Revisions Requested, Rejected)
  decision_rationale: text
  created_at: datetime
}
```

### 2.6 Integration Points

- **PRD Generator (Prompt 3):** When a PRD is finalized, its status changes to "Pending Review" and it appears in this queue.
- **PRD Document Viewer (Gap #1):** "Open Full PRD" button navigates to the viewer.
- **RICE Scoring (Prompt 4):** Only PRDs with status "Approved" from this evaluation flow become eligible for RICE scoring.
- **Notifications system:** Triggers email + in-app notifications on assignment and decision events.
- **Submission form (Prompt 2):** The original submitter receives feedback through this evaluation.

### 2.7 Acceptance Criteria (QA)

- [ ] PRDs appear in queue within 5 seconds of being marked "Pending Review"
- [ ] All four criteria must be scored before a decision can be submitted
- [ ] Decision rationale is mandatory (minimum 20 characters)
- [ ] Approved PRDs automatically transition to "Ready for RICE Scoring" status
- [ ] "Request Revisions" sends the PRD back to the generator with reviewer comments attached
- [ ] Bulk approve only enables for items with average auto-score ≥ 4.0
- [ ] Evaluation history is immutable — past evaluations cannot be edited or deleted
- [ ] Notification is sent within 30 seconds of a decision being submitted

---

## 3. PRD Research & Analysis (LLM Bot)

### 3.1 Overview

The Research & Analysis screen provides an AI-powered research assistant that helps product managers investigate a product idea's viability before (or during) prioritization. It conducts market research, competitive analysis, user sentiment analysis, and technical feasibility assessments through a conversational interface, and produces a structured research report.

**Navigation location:** PRODUCT → Research & Analysis (already in the sidebar; this spec defines the screen).

### 3.2 Problem Statement

Product managers currently rely on manual research across multiple tools (Google, industry reports, competitor sites, internal data) to evaluate whether a product idea is worth pursuing. This is time-consuming and inconsistent. An LLM-powered research bot can accelerate this process, provide structured output, and ensure every idea gets a consistent level of analysis before prioritization.

### 3.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| RA-01 | Product Manager | I want to select a PRD and ask the AI to research its market viability | Dropdown to select a PRD; AI reads the PRD content and initiates research context |
| RA-02 | Product Manager | I want the AI to analyze competitors offering similar features | AI produces a competitor comparison table with feature parity, pricing, and market share data |
| RA-03 | Product Manager | I want to see user sentiment analysis for the problem the PRD addresses | AI synthesizes sentiment from configurable sources (support tickets, surveys, public reviews) into a sentiment summary |
| RA-04 | Product Manager | I want the AI to assess technical feasibility and estimate complexity | AI provides a feasibility assessment with risk factors, dependency analysis, and rough t-shirt sizing |
| RA-05 | Product Manager | I want to generate a structured research report I can attach to the PRD | "Generate Report" button produces a formatted report (Markdown + PDF) with all research findings |
| RA-06 | Product Manager | I want to ask follow-up questions to dive deeper into specific findings | Conversational interface supports multi-turn dialogue with context retention |
| RA-07 | Product Lead | I want the research report to include a priority recommendation with confidence level | Report includes a recommendation section: Pursue / Defer / Reject with a confidence percentage and supporting evidence |
| RA-08 | Product Manager | I want to see research history for each PRD | Past research sessions are saved and accessible from the PRD detail view |

### 3.4 UI Description

**Layout:** Split-panel layout (similar to PRD Generator).

**Left panel (55%) — Research Chat:**
- Header: "Research & Analysis" title with sparkle icon, PRD selector dropdown (showing title + ID), and a "Research Mode" toggle with three options: Quick Scan (5-min), Standard (15-min), Deep Dive (30-min)
- **Quick-action buttons** below the header: "Market Analysis", "Competitor Scan", "User Sentiment", "Tech Feasibility", "Full Research" — clicking one sends a pre-formed prompt to the AI
- Chat conversation area with:
  - AI messages containing structured findings (tables, bullet summaries, charts described in text)
  - User messages for follow-up questions and refinements
  - Inline "Source" links on AI claims, expandable to show where the data came from
- Input area: text field with "Ask a research question..." placeholder, send button, and an "Attach Data" button (to upload supplementary files like survey CSVs)

**Right panel (45%) — Research Report:**
- Tab bar: "Live Report" (active) | "Sources" | "History"
- **Live Report tab:** A continuously-updating structured report that builds as the conversation progresses:
  - Executive Summary (auto-generated)
  - Market Landscape section
  - Competitive Analysis section (with comparison table)
  - User Sentiment Summary section
  - Technical Feasibility section
  - Risk Assessment section
  - **Priority Recommendation** — highlighted card with the recommendation (Pursue/Defer/Reject), confidence bar, and key supporting evidence bullets
- **Sources tab:** A list of all sources cited by the AI, with type labels (Web, Internal Data, Survey, Support Tickets), URLs, and relevance scores
- **History tab:** Past research sessions for this PRD, each with date, summary, and "Load" button
- **Bottom action bar:** "Generate PDF Report", "Attach to PRD", "Share with Team", "Export Markdown"

### 3.5 Data Model Hints

```
ResearchSession {
  id: UUID
  prd_id: FK → PRDDocument
  researcher_id: FK → User
  mode: enum (QuickScan, Standard, DeepDive)
  conversation: [{ role, content, sources, timestamp }]
  report: {
    executive_summary: text,
    market_landscape: text,
    competitive_analysis: { competitors: [...], comparison_table: [...] },
    user_sentiment: { summary: text, sentiment_score: float, sources: [...] },
    technical_feasibility: { assessment: text, risks: [...], t_shirt_size: enum },
    risk_assessment: [{ risk, likelihood, impact, mitigation }],
    recommendation: { decision: enum, confidence: float, evidence: [...] }
  }
  sources: [{ id, type, url, title, relevance_score }]
  created_at: datetime
  updated_at: datetime
}
```

### 3.6 Integration Points

- **PRD Generator (Prompt 3):** PRD content is loaded as context for the research bot.
- **PRD Evaluation (Gap #2):** Research reports can be referenced during evaluation to inform the decision.
- **RICE Scoring (Prompt 4):** Research findings (especially feasibility and market data) feed into the RICE agents' assessments.
- **LLM Cost Admin (Prompt 12):** Research Bot usage is tracked as a separate line item in LLM cost reporting (mode affects token usage).
- **PRD Document Viewer (Gap #1):** "Attach to PRD" saves the report as a supplementary document accessible from the viewer.

### 3.7 Acceptance Criteria (QA)

- [ ] AI correctly loads and references PRD content when a PRD is selected
- [ ] Quick-action buttons generate appropriate research prompts
- [ ] Live report updates in real-time as the conversation progresses
- [ ] "Generate PDF Report" produces a well-formatted PDF with all sections
- [ ] "Attach to PRD" links the report to the PRD and it appears in the PRD viewer's supplementary docs
- [ ] Sources are cited with inline links and the Sources tab is populated
- [ ] Research history loads previous sessions with full conversation and report
- [ ] Research mode (Quick/Standard/Deep) affects the depth of AI analysis

---

## 4. Speckit Specs Generation

### 4.1 Overview

The Speckit Specs Generation screen automates the transformation of an approved PRD into detailed, developer-ready technical specifications. It uses AI to break the PRD into discrete spec items (API contracts, data models, UI component specs, integration specs, business logic rules) and presents them in an organized, reviewable format that engineers can consume directly.

**Navigation location:** PRODUCT → Speckit Specs (already in the sidebar; this spec defines the screen).

### 4.2 Problem Statement

The gap between a product requirements document and actionable engineering specs is one of the most error-prone handoffs in product development. Product managers write requirements in business language; engineers need technical precision. Manual spec-writing is slow, inconsistent, and often incomplete. An AI-powered spec generator bridges this gap by producing structured, comprehensive specs directly from the PRD, with human review and editing built in.

### 4.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| SS-01 | Product Manager | I want to select an approved PRD and generate specs from it with one click | "Generate Specs" button triggers AI processing; a progress indicator shows generation status |
| SS-02 | Product Manager | I want to review and edit each generated spec before it's finalized | Each spec item opens in an editable detail view with rich text editing |
| SS-03 | Engineering Lead | I want specs organized by type: API, Data Model, UI Components, Business Logic, Integrations | Spec items are categorized into typed sections with appropriate templates per type |
| SS-04 | Engineering Lead | I want each spec to include acceptance criteria, edge cases, and dependencies | Every spec item template includes these three sections as mandatory fields |
| SS-05 | Product Manager | I want to add or remove spec items manually if the AI missed something or generated extras | "Add Spec Item" button and "Remove" action available on each item |
| SS-06 | Engineering Lead | I want to export all specs as a structured document for my team | Export button produces a Markdown document, PDF, or JSON export of all specs |
| SS-07 | Product Manager | I want to track which specs have been reviewed, approved, or need revision | Each spec item has a status badge: Draft / In Review / Approved / Needs Revision |
| SS-08 | Product Manager | I want to re-generate individual specs if the PRD changes without re-doing the entire set | "Regenerate" button on each spec item re-processes that item against the latest PRD content |
| SS-09 | Any user | I want to see a visual map of how specs relate to each other and to PRD sections | A dependency graph view shows connections between spec items and their source PRD sections |

### 4.4 UI Description

**Layout:** Two-zone layout — spec list on the left, spec detail on the right.

**Top bar:** Breadcrumb: `Product > Speckit Specs > PRD-042: Payment Retry Logic`. Title "Speckit Specifications" with PRD selector dropdown. Status summary: "18 specs generated — 12 approved, 4 in review, 2 draft". Buttons: "Regenerate All" (outline), "Export All" (outline), view toggle for "List" | "Dependency Graph".

**Left zone (40%) — Spec List:**
- Grouped by type with collapsible section headers:
  - **API Contracts** (count badge) — items like "POST /payments/retry", "GET /payments/{id}/status"
  - **Data Models** — items like "RetryPolicy schema", "PaymentEvent schema"
  - **UI Components** — items like "RetryConfigPanel", "RetryStatusBadge"
  - **Business Logic** — items like "Retry backoff algorithm", "Max retry limit enforcement"
  - **Integrations** — items like "Stripe webhook handler", "Notification service trigger"
- Each item shows: title, type icon, status badge (color-coded), and a small progress indicator if AI is still generating
- "Add Spec Item" button at the bottom of each section

**Right zone (60%) — Spec Detail:**
- When a spec item is selected from the list, the detail view shows:
  - Title (editable)
  - Type label
  - Status dropdown (Draft / In Review / Approved / Needs Revision)
  - **Description** — rich text area with the detailed spec content
  - **Acceptance Criteria** — numbered checklist (editable)
  - **Edge Cases** — bulleted list (editable)
  - **Dependencies** — linked list of other spec items and PRD sections this depends on
  - **Source PRD Section** — a collapsible quote showing the PRD paragraph(s) this spec was derived from
  - **AI Confidence** — a small indicator showing how confident the AI was in this generation (High/Medium/Low)
  - Action buttons: "Approve", "Request Revision" (with comment field), "Regenerate", "Delete"

**Dependency Graph view (alternate):**
- A node-graph visualization (like a simplified architecture diagram) where each spec item is a node, colored by type, with edges showing dependencies. PRD sections appear as source nodes on the left. Clicking a node highlights its connections and shows a tooltip with the spec summary.

### 4.5 Data Model Hints

```
SpecItem {
  id: UUID
  prd_id: FK → PRDDocument
  title: string
  type: enum (API, DataModel, UIComponent, BusinessLogic, Integration)
  description: text (rich text)
  acceptance_criteria: [{ id, text, order }]
  edge_cases: [{ id, text }]
  dependencies: [FK → SpecItem]
  source_prd_sections: [{ section_heading, content_excerpt }]
  ai_confidence: enum (High, Medium, Low)
  status: enum (Draft, InReview, Approved, NeedsRevision)
  reviewed_by: FK → User (nullable)
  review_comment: text (nullable)
  version: int
  created_at: datetime
  updated_at: datetime
}
```

### 4.6 Integration Points

- **PRD Generator (Prompt 3) / PRD Viewer (Gap #1):** PRD content is the input; "Generate Specs" reads the current approved PRD version.
- **PRD Evaluation (Gap #2):** Only PRDs with status "Approved" are eligible for spec generation.
- **Tech Handover (Prompt 7):** The "Speckit Specifications" checklist item links to this screen and shows completion status (e.g., "12 of 18 specs approved").
- **Figma Design Generation (Gap #5):** UI Component specs are referenced during design generation.
- **RICE Scoring (Prompt 4):** The Technical Feasibility Agent can reference specs for more accurate effort estimation.
- **Delivery Tracker (Prompt 8):** Individual spec items can be linked to engineering tasks for progress tracking.

### 4.7 Acceptance Criteria (QA)

- [ ] Generating specs from a PRD with 10+ sections produces at least one spec per section
- [ ] All five spec types are represented in the output
- [ ] Each spec includes non-empty acceptance criteria, edge cases, and dependency fields
- [ ] Editing a spec item saves changes and updates the modified timestamp
- [ ] "Regenerate" on a single item only affects that item, not the others
- [ ] Dependency graph renders correctly with up to 30 nodes
- [ ] Export produces a valid document with all specs organized by type
- [ ] Status changes are logged in an audit trail

---

## 5. Figma Design Generation

### 5.1 Overview

The Figma Design Generation screen enables product managers to generate UI design concepts directly from a PRD and its associated specs. It uses AI to produce wireframes and design mockups, presents them for review, and supports pushing approved designs to Figma for the design team to refine. This closes the loop between product requirements and visual design without requiring manual design briefs.

**Navigation location:** PRODUCT → Figma Designs (already in the sidebar; this spec defines the screen).

### 5.2 Problem Statement

Design is often a bottleneck in the product development pipeline because it requires a manual handoff from product to design — typically through briefs, meetings, and iterative feedback. By auto-generating initial UI concepts from the PRD and specs, the platform reduces the time to first design draft from days to minutes. Designers get a head start with AI-generated wireframes they can refine, and product managers get immediate visual validation of their requirements.

### 5.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| FD-01 | Product Manager | I want to generate wireframe concepts from a PRD with one click | "Generate Designs" button creates AI wireframes; progress indicator shows status per screen |
| FD-02 | Product Manager | I want to see all generated screens in a gallery view with thumbnails | Gallery grid shows thumbnails with screen names, click to preview full-size |
| FD-03 | Product Manager | I want to provide feedback on a design and regenerate it | Comment field + "Regenerate with Feedback" button on each screen |
| FD-04 | Designer | I want to push approved designs to Figma as editable frames | "Push to Figma" button sends designs to a specified Figma project via API |
| FD-05 | Product Manager | I want to choose a design style (wireframe, low-fidelity, high-fidelity) before generating | Style selector with three options and a brief preview of each style level |
| FD-06 | Designer | I want to see which PRD sections and specs each screen corresponds to | Each screen card shows linked PRD sections and UI Component specs |
| FD-07 | Product Manager | I want to compare two generated variants of the same screen side by side | "Compare Variants" action opens a split-view with two versions |
| FD-08 | Product Manager | I want to organize generated screens into a user flow sequence | Drag-and-drop ordering of screens into a linear flow, with connecting arrows shown in flow view |
| FD-09 | Designer | I want to annotate designs with design system component mappings | Annotation mode lets designers tag regions of a design with component names from the design system |

### 5.4 UI Description

**Layout:** Gallery-centric layout with a detail panel.

**Top bar:** Breadcrumb: `Product > Figma Designs > PRD-042: Payment Retry Logic`. Title "Design Generation" with PRD selector. Buttons: "Generate Designs" (solid indigo with sparkle), "Push All to Figma" (outline), view toggle: "Gallery" | "Flow View".

**Configuration panel** (collapsible, below top bar):
- **Style selector:** Three cards — "Wireframe" (gray sketch style), "Low-Fidelity" (basic shapes with placeholder text), "High-Fidelity" (polished with the Product Hub design system). Each card has a small preview thumbnail.
- **Screen scope:** Checkboxes to select which PRD sections/user stories to generate screens for. Auto-suggested screens listed (e.g., "Retry Configuration Panel", "Retry Status Dashboard", "Notification Settings").
- "Generate" button starts the process.

**Gallery view (main content):**
- A responsive grid of screen cards (3 columns on desktop). Each card shows:
  - Thumbnail preview of the generated design (rendered image)
  - Screen name (editable)
  - Linked PRD section tag (small pill)
  - Status badge: Generating / Draft / Reviewed / Approved / Pushed to Figma
  - Variant count badge if multiple variants exist (e.g., "3 variants")
  - Action icons: Expand, Compare Variants, Regenerate, Push to Figma, Delete
- Clicking a card opens a full-size preview overlay with:
  - The design rendered large (zoomable)
  - Right sidebar with: linked specs, feedback/comment thread, variant selector (thumbnail strip), and action buttons (Approve, Regenerate with Feedback, Push to Figma)
  - "Regenerate with Feedback" opens a text input: "Describe what to change..."

**Flow view (alternate):**
- Screens arranged horizontally in a user-flow diagram with connecting arrows. Drag-and-drop to reorder. Each screen is a smaller thumbnail with its name below. Click to expand.

### 5.5 Data Model Hints

```
DesignScreen {
  id: UUID
  prd_id: FK → PRDDocument
  screen_name: string
  style: enum (Wireframe, LowFidelity, HighFidelity)
  variants: [{
    id: UUID,
    image_url: string,
    generation_prompt: text,
    feedback: text (nullable),
    created_at: datetime
  }]
  active_variant_id: UUID
  linked_prd_sections: [string]
  linked_spec_ids: [FK → SpecItem]
  flow_order: int
  status: enum (Generating, Draft, Reviewed, Approved, PushedToFigma)
  figma_frame_url: string (nullable)
  annotations: [{ id, region: {x,y,w,h}, component_name, note }]
  created_at: datetime
  updated_at: datetime
}
```

### 5.6 Integration Points

- **PRD Generator / Viewer (Prompt 3, Gap #1):** PRD content and structure drive the screen generation.
- **Speckit Specs (Gap #4):** UI Component specs provide specific requirements for each screen.
- **Tech Handover (Prompt 7):** The "Figma Designs" checklist section pulls from this screen's approved designs and shows thumbnail previews.
- **Figma API:** "Push to Figma" uses the Figma REST API (or plugin) to create frames in a specified Figma file/page.
- **LLM Cost Admin (Prompt 12):** Design generation usage (image generation models) tracked separately.

### 5.7 Acceptance Criteria (QA)

- [ ] Generating designs for a PRD with 6+ user stories produces at least one screen per story
- [ ] All three style levels produce visually distinct outputs
- [ ] "Regenerate with Feedback" produces a new variant that reflects the feedback
- [ ] "Push to Figma" creates editable frames in the target Figma file (requires valid Figma token)
- [ ] Gallery thumbnails load within 1 second; full-size preview within 2 seconds
- [ ] Flow view correctly shows the drag-and-drop ordered sequence with arrows
- [ ] Variant comparison side-by-side renders both variants at equal size
- [ ] Design annotations persist and are visible to other users

---

## 6. Domain Backlogs & Cross-Idea Comparison

### 6.1 Overview

The Domain Backlogs screen provides a domain-specific view of the product backlog, allowing domain owners (e.g., Payments, Onboarding, Risk, Growth, Platform) to manage and prioritize ideas within their domain. It includes a powerful cross-idea comparison feature that helps domain owners make informed prioritization decisions by comparing ideas side-by-side across multiple dimensions.

**Navigation location:** BACKLOG → Domain Backlogs (already in the sidebar; this spec defines the screen).

### 6.2 Problem Statement

The Global Backlog (Prompt 5) provides a cross-domain view, but domain owners need a focused workspace for their specific area. They need to see only the ideas in their domain, compare them against each other on multiple dimensions (RICE score, research findings, stakeholder sentiment, effort), and make prioritization decisions in context. Without this, domain owners must mentally filter the global backlog, and cross-idea comparison requires switching between multiple screens.

### 6.3 User Stories

| ID | Role | Story | Acceptance Criteria |
|----|------|-------|-------------------|
| DB-01 | Domain Owner | I want to see only the backlog items in my domain | Domain selector filters the view to a single domain; default is the user's assigned domain |
| DB-02 | Domain Owner | I want to view my domain backlog as a prioritized list, Kanban board, or table | Three view modes available: Ranked List, Kanban (by status), Table (sortable columns) |
| DB-03 | Domain Owner | I want to select 2–4 ideas and compare them side-by-side | "Compare" mode: select items via checkboxes, click "Compare Selected", opens a comparison panel |
| DB-04 | Domain Owner | I want the comparison to show RICE scores, research summaries, effort estimates, and stakeholder votes | Comparison table shows a row per dimension with color-coded cells for easy visual scanning |
| DB-05 | Domain Owner | I want to drag items to reorder priority within my domain | Ranked List view supports drag-and-drop reordering; changes are saved and logged |
| DB-06 | Product Lead | I want to see how my domain's backlog compares to other domains in resource allocation | A "Cross-Domain Summary" collapsible panel at the top shows item counts and avg RICE scores per domain as a horizontal bar chart |
| DB-07 | Domain Owner | I want to tag items as "Domain Priority" to signal my top picks to the global backlog | "Mark as Domain Priority" toggle on each item; flagged items get a star badge visible in the Global Backlog |
| DB-08 | Domain Owner | I want to add domain-specific notes or context to a backlog item that are separate from the PRD | "Domain Notes" text field on each item's detail panel, visible only in the domain backlog view |
| DB-09 | Product Lead | I want to see a comparison of the same idea across its RICE agent scores, research recommendation, and evaluation score in one view | Comparison card for each item aggregates: RICE consensus score, Research recommendation (Pursue/Defer/Reject), Evaluation avg score, and Stakeholder impact rating |

### 6.4 UI Description

**Layout:** Full content area with a domain context bar.

**Domain context bar (top):**
- Large domain selector tabs: "Payments" (active, blue), "Onboarding" (teal), "Risk" (orange), "Growth" (green), "Platform" (purple) — each with an item count badge
- Below tabs: Summary stats for the active domain — Total Items, Avg RICE Score, Items In Development, Items Awaiting Review
- View toggle buttons: "Ranked List" | "Board" | "Table"
- Filter bar: Status, RICE Score Range, Assignee, Priority Flag (Domain Priority / All)
- "Compare Selected" button (indigo outline, disabled until 2+ items are checked)

**Ranked List view (default):**
- Numbered list of items in priority order. Each row:
  - Drag handle, rank number, checkbox
  - Item title (linked), status badge, RICE score (circular badge)
  - Research recommendation pill (Pursue=green, Defer=yellow, Reject=red)
  - Domain Priority star (filled gold if flagged)
  - Assignee avatar, target quarter tag
  - Expand chevron → shows a detail row with: description excerpt, domain notes field, and quick-action buttons (View PRD, View Specs, View Research)

**Board view:** Kanban layout filtered to this domain only (same as Prompt 5 but scoped).

**Table view:** Full data table with sortable columns: Rank, Title, Status, RICE Score, Research Rec., Evaluation Score, Effort, Domain Priority, Assignee, Target Quarter.

**Comparison panel (opens when "Compare Selected" is clicked):**
- A full-width overlay or slide-up panel showing 2–4 items as columns, with rows for each comparison dimension:
  - **RICE Breakdown** — R, I, C, E individual scores with color coding (green=high, red=low)
  - **RICE Consensus Score** — large number with bar visualization
  - **Research Recommendation** — Pursue/Defer/Reject badge with confidence %
  - **Evaluation Score** — Average of the four evaluation criteria with star display
  - **Stakeholder Impact** — based on submission's estimated impact (Low/Med/High/Critical)
  - **Effort Estimate** — t-shirt size from specs or research
  - **Dependencies** — count of blockers/dependencies
  - **Submissions Count** — how many stakeholder submissions feed this idea
- Each column header has the item title and a "View Full Detail" link
- A "Winner Highlight" row at the bottom that auto-highlights the strongest item per dimension in green
- "Close Comparison" button and "Export Comparison as PDF" button

**Cross-Domain Summary panel (collapsible, top of page):**
- Horizontal stacked bar chart showing item counts per domain, colored by status
- Average RICE score per domain as small badges
- "View Global Backlog" link button

### 6.5 Data Model Hints

```
DomainBacklogItem extends BacklogItem {
  domain: enum (Payments, Onboarding, Risk, Growth, Platform)
  domain_rank: int (per-domain priority order)
  domain_priority_flag: boolean
  domain_notes: text
  comparison_snapshot: {
    rice_score: float,
    research_recommendation: enum,
    research_confidence: float,
    evaluation_avg_score: float,
    effort_estimate: enum (XS, S, M, L, XL),
    dependency_count: int,
    submissions_count: int
  }
}
```

### 6.6 Integration Points

- **Global Backlog (Prompt 5):** Domain Backlog is a filtered subset of the Global Backlog. Changes to item status or priority in either view sync bidirectionally. "Domain Priority" flags surface as star badges in the Global Backlog.
- **RICE Scoring (Prompt 4):** RICE scores are pulled from the scoring results for each item.
- **Research & Analysis (Gap #3):** Research recommendations are pulled from the latest research session for each item.
- **PRD Evaluation (Gap #2):** Evaluation scores are pulled from the completed reviews.
- **Quarterly Roadmap (Prompt 6):** Items flagged as "Domain Priority" can be dragged directly onto the roadmap from this view.
- **Speckit Specs (Gap #4):** Effort estimates are derived from specs when available.

### 6.7 Acceptance Criteria (QA)

- [ ] Domain selector correctly filters to show only items in the selected domain
- [ ] Drag-and-drop reordering persists and updates the domain_rank field
- [ ] "Compare Selected" button enables only when 2–4 items are checked
- [ ] Comparison panel renders all dimension rows with correct data for each item
- [ ] "Domain Priority" flag is visible as a star in both Domain and Global Backlog views
- [ ] Domain Notes are isolated — they do not appear in the Global Backlog or PRD views
- [ ] Cross-Domain Summary chart accurately reflects item counts and scores
- [ ] View toggle between Ranked List, Board, and Table preserves the selected filters
- [ ] Export Comparison as PDF produces a readable document with all dimensions

---

## Appendix: Requirement-to-Screen Traceability Matrix

| Project Requirement | Primary Screen | Supporting Screens |
|---|---|---|
| Admin Area (LLM Cost / Manage Users / Platform Settings) | Prompt 12: Admin Settings | — |
| Register / Login with Whitelisted Email Addresses | Prompt 1: Login & Registration | Prompt 12 (User Management tab) |
| Stakeholder Submission Form with Attachments | Prompt 2: Submission Form | — |
| Stakeholder Request to PRD Generator & Validator with LLM Bot + multi-format viewer | Prompt 3: PRD Generator | **Gap #1: PRD Document Viewer** |
| Product Processing & Evaluation of PRDs | **Gap #2: Product Processing & Evaluation** | Gap #1 (PRD Viewer), Prompt 3 |
| Conduct PRD Research & Analysis to Evaluate Priority with LLM Bot | **Gap #3: PRD Research & Analysis** | Prompt 4 (RICE Scoring) |
| Give the Product Idea a RICE Score with Multiple Agents | Prompt 4: RICE Scoring | Gap #3 (Research feeds into scoring) |
| PRD to Speckit Specs Generation | **Gap #4: Speckit Specs Generation** | Prompt 3, Gap #1 |
| PRD to Figma Design Generation | **Gap #5: Figma Design Generation** | Gap #4 (UI Component specs), Prompt 3 |
| Compare the Product Idea at a Global Backlog Level | Prompt 5: Global Backlog / Priority Board | Gap #6 (Domain Backlog comparison) |
| Compare the Product Idea at a Domain Backlog Level | **Gap #6: Domain Backlogs** | Prompt 5 (Global Backlog) |
| Visualise in the Priority Backlog | Prompt 5: Priority Board | — |
| Visualise in a Quarterly Roadmap | Prompt 6: Quarterly Roadmap | — |
| Tech Handover Package with all assets | Prompt 7: Tech Handover | Gap #1, Gap #4, Gap #5 |
| Monitor Delivery Progress by Engineering | Prompt 8: Delivery Tracker | — |
| UAT Screen & LLM for testing and validation | Prompt 9: UAT Testing | — |
| Release Notes for Stakeholders | Prompt 10: Release Notes | — |
| Reports to monitor Success Metrics | Prompt 11: Success Metrics | — |

---

## Appendix: Updated Navigation Sidebar

The sidebar should be updated to reflect the complete set of screens:

```
MAIN
  Dashboard
  Submissions

PRODUCT
  PRD Generator
  PRD Viewer              ← NEW (Gap #1)
  PRD Evaluation          ← NEW (Gap #2)
  Research & Analysis     ← NEW (Gap #3)
  RICE Scoring
  Speckit Specs           ← NEW (Gap #4)
  Figma Designs           ← NEW (Gap #5)

BACKLOG
  Global Backlog
  Domain Backlogs         ← NEW (Gap #6)
  Priority Board
  Quarterly Roadmap

DELIVERY
  Tech Handover
  Delivery Tracker
  UAT Testing
  Release Notes

INSIGHTS
  Success Metrics
  Reports

ADMIN
  Users
  Platform Settings
  LLM Costs
```

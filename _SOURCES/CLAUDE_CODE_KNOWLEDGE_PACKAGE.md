# Product Hub — Claude Code Knowledge Package

> **Purpose:** This document is a complete handoff from Claude Desktop (Cowork) to Claude Code. It contains everything needed to understand the project, continue development, and build the full-stack application. Drop this into your Claude Code project as `CLAUDE.md` or reference it at the start of any session.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [What Exists Today](#2-what-exists-today)
3. [Design System & Visual Language](#3-design-system--visual-language)
4. [Full Screen Inventory (19 Screens)](#4-full-screen-inventory-19-screens)
5. [Product Specifications — Gap Features (6 Screens)](#5-product-specifications--gap-features)
6. [Data Models](#6-data-models)
7. [Integration Map & Screen Dependencies](#7-integration-map--screen-dependencies)
8. [Stitch MCP Server (Design Generation Tool)](#8-stitch-mcp-server)
9. [Stitch Design Prompts (All 19 Screens)](#9-stitch-design-prompts)
10. [Learnings from the HTML Prototype](#10-learnings-from-the-html-prototype)
11. [Recommended Tech Stack for Production](#11-recommended-tech-stack-for-production)
12. [CLAUDE.md Template for Claude Code](#12-claudemd-template)
13. [Navigation & Sidebar Structure](#13-navigation--sidebar-structure)
14. [Requirement Traceability Matrix](#14-requirement-traceability-matrix)

---

## 1. Project Overview

**Product Hub** is a modern AI-powered SaaS backoffice application for end-to-end product management — from stakeholder idea submission through PRD generation, evaluation, prioritization (RICE scoring), design generation, tech handover, delivery tracking, UAT testing, release notes, and success metrics.

### Core Value Proposition
- **LLM-powered workflows** throughout: PRD generation, research analysis, RICE scoring (multi-agent), UAT test assistance, release note auto-generation
- **Full lifecycle coverage:** Idea → PRD → Evaluation → Research → RICE → Specs → Design → Backlog → Roadmap → Handover → Delivery → UAT → Release → Metrics
- **Multi-agent RICE scoring:** Three AI agents (Market Analyst, Technical Feasibility, Business Strategy) provide independent assessments with consensus scoring

### Target Users
- **Stakeholders** — Submit product ideas, receive notifications on evaluation decisions, view release notes
- **Product Managers** — Generate PRDs, conduct research, manage backlog, create specs
- **Product Leads / Domain Owners** — Evaluate PRDs, manage domain backlogs, set priorities
- **Engineering Leads** — Consume specs, receive tech handover packages, track delivery
- **Designers** — Review generated Figma designs, annotate with design system components
- **Admins** — Manage users, whitelist emails, configure LLM models, monitor costs

---

## 2. What Exists Today

### Files in the Project

| File | Type | Description |
|------|------|-------------|
| `Product_Hub_App.html` | HTML (320KB, minified React bundle) | **Complete working prototype** — a single-file React app with all 19 screens implemented as a clickable prototype with Tailwind CSS, mock data, and full navigation. This is the reference implementation for all UI patterns. |
| `Product_Hub_Gap_Specifications.md` | Markdown (43KB) | **Detailed product specifications** for 6 gap features not originally covered: PRD Viewer, PRD Evaluation, Research & Analysis, Speckit Specs, Figma Design Generation, Domain Backlogs. Each has user stories, UI descriptions, data models, integration points, and QA acceptance criteria. |
| `Stitch_Prompts_Product_Hub_Backoffice.md` | Markdown (37KB) | **19 complete UI design prompts** for Google Stitch AI — each prompt describes one screen in precise detail for design generation. Can be used as a UI specification for any frontend framework. |
| `stitch-mcp-server/` | TypeScript MCP Server | **Custom MCP server** that wraps Google Stitch SDK to enable Claude to generate, edit, and export UI designs via text prompts. Includes batch generation for all 19 screens. |

### State of Development
- **Design phase: COMPLETE** — All 19 screens are specified and prototyped
- **Design generation: READY** — Stitch MCP server is built and ready to generate production designs
- **Production development: NOT STARTED** — No real backend, no database, no authentication, no API layer

---

## 3. Design System & Visual Language

```
Primary Color:    #4F46E5 (Deep Indigo)
Sidebar BG:       #1E1B4B (Dark Navy)
Background:       #FFFFFF (White) / #F9FAFB (Light Gray for page bg)
Border Radius:    8px on all cards and containers
Font:             Inter (or system sans-serif fallback)
Shadows:          Subtle, used on cards
Data Density:     Medium-high (internal productivity tool)
Layout:           Desktop-first (1440px), responsive to tablet
```

### Layout Architecture
- **Persistent left sidebar** (240px expanded, 64px collapsed) — dark navy background
- **Top header bar** (64px) — breadcrumb left, global search center, notifications + user avatar right
- **Main content area** — varies per screen (split panels, full-width, grid layouts)

### Component Patterns Used
- **Cards** with white background, subtle shadows, 8px border radius
- **Status badges** — color-coded pills (Green=Approved, Yellow=In Review, Red=Rejected, Gray=Draft, Blue=In Dev)
- **Domain tags** — colored pills (Payments=Blue, Onboarding=Teal, Risk=Orange, Growth=Green, Platform=Purple)
- **Star ratings** — 1-5 clickable stars for evaluation criteria
- **RICE score badges** — circular indigo badges with white text
- **AI chat interfaces** — split panel with chat on left, live document/report on right
- **Kanban boards** — horizontal columns with draggable cards
- **Gantt charts** — horizontal timeline bars grouped by domain swimlanes
- **Comparison panels** — multi-column overlay for side-by-side idea comparison
- **Slide-out drawers** — right-side panels for evaluation, detail views
- **Three-dot action menus** — on table rows and cards
- **Breadcrumb navigation** — at top of content area

---

## 4. Full Screen Inventory (19 Screens)

### MAIN Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 0 | App Shell & Navigation Sidebar | Prompt 0 | Prototyped |
| 1 | Login & Registration | Prompt 1 | Prototyped |

### PRODUCT Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 2 | Stakeholder Submission Form | Prompt 2 | Prototyped |
| 3 | PRD Generator & Validator (AI Chat) | Prompt 3 | Prototyped |
| 3A | PRD Document Viewer (Multi-Format) | Prompt 3A | Prototyped + Full Spec |
| 3B | Product Processing & Evaluation | Prompt 3B | Prototyped + Full Spec |
| 3C | PRD Research & Analysis (LLM Bot) | Prompt 3C | Prototyped + Full Spec |
| 4 | RICE Scoring with Multiple Agents | Prompt 4 | Prototyped |
| 4A | Speckit Specs Generation | Prompt 4A | Prototyped + Full Spec |
| 4B | Figma Design Generation | Prompt 4B | Prototyped + Full Spec |

### BACKLOG Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 5 | Global Backlog & Priority Board | Prompt 5 | Prototyped |
| 5A | Domain Backlogs & Cross-Idea Comparison | Prompt 5A | Prototyped + Full Spec |
| 6 | Quarterly Roadmap | Prompt 6 | Prototyped |

### DELIVERY Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 7 | Tech Handover Package | Prompt 7 | Prototyped |
| 8 | Delivery Tracker | Prompt 8 | Prototyped |
| 9 | UAT Testing Screen | Prompt 9 | Prototyped |
| 10 | Release Notes Generator | Prompt 10 | Prototyped |

### INSIGHTS Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 11 | Success Metrics & Reports | Prompt 11 | Prototyped |

### ADMIN Section
| # | Screen | Prompt | Status |
|---|--------|--------|--------|
| 12 | Admin: LLM Costs & Platform Settings | Prompt 12 | Prototyped |

---

## 5. Product Specifications — Gap Features

These 6 screens have full product specifications including user stories, detailed UI descriptions, data models, integration points, and QA acceptance criteria. See `Product_Hub_Gap_Specifications.md` for the complete specs.

### Gap #1: PRD Document Viewer (Multi-Format)
**What it does:** Unified viewer for PRDs in 5 formats — Markdown (with TOC sidebar), HTML Preview, Slide Preview (carousel), PDF (embedded viewer), and Images (masonry gallery). Supports inline annotations, version history with diff view, and one-click export to .md/.html/.pdf/.pptx/.docx.

**Key data model: `PRDDocument`**
- `content_markdown` (source of truth), `content_html`, `content_pdf_url`, `content_pptx_url`
- `annotations[]` (user_id, section_anchor, body, resolved)
- `versions[]` (version_number, content_markdown, created_at, created_by)
- Status: Draft → In Review → Approved → Archived

### Gap #2: Product Processing & Evaluation
**What it does:** Structured review workflow where designated reviewers score PRDs on 4 criteria (Completeness, Strategic Alignment, Technical Feasibility, Clarity & Quality) with 1-5 star ratings, then make Approve/Reject/Request Revisions decisions. Queue-based with filtering, assignment, and bulk actions.

**Key data model: `PRDEvaluation`**
- `scores` object with 4 criteria (int 1-5 each)
- `decision` enum: Approved | Revisions Requested | Rejected
- `decision_rationale` (mandatory, min 20 chars)

**Critical flow:** Only PRDs with "Approved" status here become eligible for RICE Scoring.

### Gap #3: PRD Research & Analysis (LLM Bot)
**What it does:** AI research assistant with conversational interface. Conducts market research, competitive analysis, user sentiment analysis, and technical feasibility assessments. Produces a structured live research report with an executive summary, competitive comparison tables, sentiment scores, and a priority recommendation (Pursue/Defer/Reject with confidence %).

**Key data model: `ResearchSession`**
- `mode` enum: QuickScan | Standard | DeepDive
- `report` object with: executive_summary, market_landscape, competitive_analysis, user_sentiment, technical_feasibility, risk_assessment, recommendation (decision + confidence + evidence)
- `sources[]` with type, URL, relevance_score

### Gap #4: Speckit Specs Generation
**What it does:** AI-powered transformation of approved PRDs into developer-ready specs. Breaks PRDs into typed spec items (API Contracts, Data Models, UI Components, Business Logic, Integrations) with acceptance criteria, edge cases, and dependencies per item. Includes a dependency graph visualization.

**Key data model: `SpecItem`**
- `type` enum: API | DataModel | UIComponent | BusinessLogic | Integration
- `acceptance_criteria[]`, `edge_cases[]`, `dependencies[]` (FK → other SpecItems)
- `ai_confidence` enum: High | Medium | Low
- `source_prd_sections[]` with heading and content excerpt

### Gap #5: Figma Design Generation
**What it does:** Generates UI wireframes/mockups from PRDs and specs. Supports three style levels (Wireframe, Low-Fidelity, High-Fidelity). Gallery view with variant comparison, feedback-driven regeneration, and Push to Figma via API. Includes a Flow View for sequencing screens with connecting arrows.

**Key data model: `DesignScreen`**
- `style` enum: Wireframe | LowFidelity | HighFidelity
- `variants[]` with image_url, generation_prompt, feedback
- `linked_spec_ids[]`, `linked_prd_sections[]`
- `figma_frame_url` (after push)
- `annotations[]` with region coordinates and component_name

### Gap #6: Domain Backlogs & Cross-Idea Comparison
**What it does:** Domain-specific backlog views (Payments, Onboarding, Risk, Growth, Platform) with ranked list, Kanban board, and table views. Powerful comparison feature lets domain owners select 2-4 ideas and compare side-by-side across RICE scores, research recommendations, evaluation scores, stakeholder impact, effort estimates, and dependencies. Includes cross-domain summary chart.

**Key data model: `DomainBacklogItem` (extends BacklogItem)**
- `domain_rank` (per-domain priority order, drag-and-drop)
- `domain_priority_flag` (star badge visible in Global Backlog)
- `domain_notes` (domain-specific, not visible globally)
- `comparison_snapshot` aggregating all scoring dimensions

---

## 6. Data Models

### Core Entity Relationships

```
User
  ├── submits → Submission
  ├── reviews → PRDEvaluation
  ├── researches → ResearchSession
  └── manages → DomainBacklogItem

Submission
  └── generates → PRDDocument

PRDDocument
  ├── has → PRDEvaluation[] (must be Approved to proceed)
  ├── has → ResearchSession[]
  ├── has → SpecItem[]
  ├── has → DesignScreen[]
  ├── has → annotations[]
  └── has → versions[]

PRDDocument (Approved)
  └── eligible for → RICE Scoring

BacklogItem
  ├── scored by → RICE Agents (3 agents → consensus)
  ├── appears in → Global Backlog
  ├── appears in → Domain Backlog (filtered)
  ├── placed on → Quarterly Roadmap
  └── packaged in → Tech Handover

Tech Handover
  └── tracked by → Delivery Tracker
      └── tested by → UAT Testing
          └── documented in → Release Notes
              └── measured by → Success Metrics
```

### Key Enums

```
Domains:           Payments | Onboarding | Risk | Growth | Platform
PRD Status:        Draft | In Review | Approved | Archived
Eval Decision:     Approved | Revisions Requested | Rejected
Research Mode:     QuickScan | Standard | DeepDive
Recommendation:    Pursue | Defer | Reject
Spec Type:         API | DataModel | UIComponent | BusinessLogic | Integration
AI Confidence:     High | Medium | Low
Design Style:      Wireframe | LowFidelity | HighFidelity
Design Status:     Generating | Draft | Reviewed | Approved | PushedToFigma
Backlog Status:    New | Under Review | Approved | In Development | Released
Effort Estimate:   XS | S | M | L | XL
Delivery Status:   On Track | At Risk | Blocked | Done
UAT Status:        Pass | Fail | Blocked | Skipped
User Role:         Admin | Product Manager | Stakeholder | Viewer
```

---

## 7. Integration Map & Screen Dependencies

### Data Flow Pipeline

```
[Submission Form] → [PRD Generator] → [PRD Evaluation] → [Research & Analysis]
                                                    ↓
                                            [RICE Scoring (3 agents)]
                                                    ↓
                                    [Speckit Specs] + [Figma Designs]
                                                    ↓
                            [Global Backlog] ←→ [Domain Backlogs]
                                                    ↓
                                        [Quarterly Roadmap]
                                                    ↓
                                        [Tech Handover Package]
                                                    ↓
                                        [Delivery Tracker]
                                                    ↓
                                        [UAT Testing]
                                                    ↓
                                        [Release Notes]
                                                    ↓
                                        [Success Metrics]
```

### Cross-Screen Integration Points

| From Screen | To Screen | Integration |
|---|---|---|
| Submission Form | PRD Generator | Submission data feeds PRD creation |
| PRD Generator | PRD Viewer | "View PRD" opens multi-format viewer |
| PRD Generator | PRD Evaluation | Finalized PRD enters evaluation queue |
| PRD Evaluation | RICE Scoring | Only "Approved" PRDs become RICE-eligible |
| PRD Evaluation | PRD Generator | "Request Revisions" sends PRD back with comments |
| Research & Analysis | PRD Viewer | "Attach to PRD" links research report |
| Research & Analysis | RICE Scoring | Research findings inform agent assessments |
| RICE Scoring | Global Backlog | Scored items appear in backlog |
| Speckit Specs | Tech Handover | Specs are a checklist item in handover |
| Speckit Specs | Delivery Tracker | Spec items linkable to engineering tasks |
| Figma Designs | Tech Handover | Designs are a checklist item in handover |
| Figma Designs | Figma API | Push to Figma creates editable frames |
| Global Backlog | Domain Backlogs | Bidirectional sync; domain priority flags visible globally |
| Domain Backlogs | Quarterly Roadmap | Domain Priority items can be dragged onto roadmap |
| Tech Handover | Delivery Tracker | Handover triggers delivery tracking |
| Delivery Tracker | UAT Testing | "Ready for Demo & UAT" sends to UAT |
| UAT Testing | Release Notes | Passed items eligible for release notes |
| Release Notes | Success Metrics | Released items tracked for adoption metrics |
| All LLM features | Admin LLM Costs | Token usage tracked per feature |
| Admin Users | Login/Registration | Whitelisted emails control access |

---

## 8. Stitch MCP Server

### Overview
A custom TypeScript MCP server (`stitch-mcp-server/`) that wraps Google Stitch SDK to generate UI designs from text prompts. Can be used with Claude Code to generate production-quality designs from the Stitch prompts.

### Setup
```bash
cd stitch-mcp-server
npm install
npm run build
```

### MCP Config (add to `~/.claude/settings.json` or project `.mcp.json`)
```json
{
  "mcpServers": {
    "stitch": {
      "command": "node",
      "args": ["dist/index.js"],
      "cwd": "/path/to/Modern AI Product Hub/stitch-mcp-server",
      "env": {
        "STITCH_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

### Available Tools (11 total)

| Tool | Description |
|------|-------------|
| `stitch_create_project` | Create a new Stitch project container |
| `stitch_list_projects` | List all accessible projects |
| `stitch_generate_screen` | Generate single UI screen from text prompt |
| `stitch_edit_screen` | Refine/edit an existing screen |
| `stitch_generate_variants` | Create design variants (REFINE/EXPLORE/REIMAGINE) |
| `stitch_get_screen_content` | Get HTML + screenshot for a screen |
| `stitch_list_screens` | List all screens in a project |
| `stitch_create_design_system` | Create theme (colors, fonts, border-radius, style) |
| `stitch_apply_design_system` | Apply theme to screens |
| `stitch_batch_generate` | **Generate multiple screens at once** (up to 25) |
| `stitch_diagnostics` | Test API connection |

### Recommended Workflow
1. `stitch_create_project` → "Product Hub Backoffice"
2. `stitch_create_design_system` → indigo #4F46E5, Inter font, 8px radius
3. `stitch_batch_generate` → all 19 prompts from Section 9
4. `stitch_edit_screen` → refine individual screens
5. `stitch_generate_variants` → explore alternatives
6. `stitch_get_screen_content` → export HTML + screenshots

### Architecture
```
stitch-mcp-server/
├── src/
│   ├── index.ts          — MCP server, 11 tool registrations (stdio transport)
│   ├── stitch-client.ts  — Wrapper around @google/stitch-sdk
│   └── constants.ts      — Types: DeviceType, ModelId, CreativeRange, VariantAspect
├── dist/                 — Compiled JS (entry: dist/index.js)
├── .env                  — STITCH_API_KEY (gitignored)
├── mcp-config.json       — Template MCP config
├── package.json          — Node ≥18, deps: @modelcontextprotocol/sdk, @google/stitch-sdk, zod
└── tsconfig.json         — ES2022, Node16 module resolution
```

---

## 9. Stitch Design Prompts

All 19 UI prompts are in `Stitch_Prompts_Product_Hub_Backoffice.md`. Here is the screen-to-prompt mapping for quick reference:

| Screen | Prompt ID | Key UI Pattern |
|--------|-----------|---------------|
| App Shell & Nav Sidebar | Prompt 0 | Collapsible sidebar, 6 nav groups, dashboard with 6 stat cards |
| Login & Registration | Prompt 1 | 50/50 split: gradient panel + login form, Google SSO, whitelist note |
| Submission Form | Prompt 2 | Multi-step stepper (3 steps), dropzone for attachments |
| PRD Generator | Prompt 3 | 55/45 split: AI chat + live PRD preview (Markdown/HTML/Export tabs) |
| PRD Viewer | Prompt 3A | Full-width, 5 format tabs, TOC sidebar, annotation mode, version history |
| PRD Evaluation | Prompt 3B | Queue table + slide-out eval panel, 4 criteria star ratings, 3 decision buttons |
| Research & Analysis | Prompt 3C | 55/45 split: research chat + live report, quick-action pills, recommendation card |
| RICE Scoring | Prompt 4 | 3 agent cards + consensus score, radar chart, manual override |
| Speckit Specs | Prompt 4A | 40/60 split: grouped spec list + detail view, dependency graph toggle |
| Figma Designs | Prompt 4B | Gallery grid (3 cols), config panel, expanded overlay with variant strip |
| Global Backlog | Prompt 5 | Kanban board (5 columns), card with RICE badge + domain tag + priority flame |
| Domain Backlogs | Prompt 5A | Domain tabs, ranked list with drag-drop, comparison panel overlay |
| Quarterly Roadmap | Prompt 6 | Gantt timeline, domain swimlanes, "Today" line, dependency arrows |
| Tech Handover | Prompt 7 | Checklist of 6 items, thumbnail grid, readiness donut chart (83%) |
| Delivery Tracker | Prompt 8 | 4 metric cards + detail table, progress bars, "Demo Ready" toggle |
| UAT Testing | Prompt 9 | 55/45 split: test checklist + AI assistant chat, pass/fail/blocked states |
| Release Notes | Prompt 10 | Rich text editor, audience/distribution sidebar, scheduled publish |
| Success Metrics | Prompt 11 | Dashboard grid: sparklines, funnel chart, domain distribution, scatter plot |
| Admin Settings | Prompt 12 | 3 tabs: LLM Costs (spend chart + model config), Users, Platform Settings |

---

## 10. Learnings from the HTML Prototype

The `Product_Hub_App.html` is a 320KB minified single-file React application. Key insights from analyzing it:

### Tech Stack Used in Prototype
- **React 18** with ReactDOM (bundled, no external CDN)
- **Tailwind CSS** (utility classes compiled inline — no CDN or build step)
- **Three.js** (included but likely for a specific visualization)
- **No router library** — state-based page switching (e.g., `"dashboard"===e`, `"kanban"===e`, `"gallery"===e`, `"flow"===e`)
- **useState hooks** — lightweight state management (only 3 hook instances detected in minified code)

### Screens Confirmed Implemented in Prototype
All 19 screens are present with mock data, including:
- Full sidebar navigation with all groups (MAIN, PRODUCT, BACKLOG, DELIVERY, INSIGHTS, ADMIN)
- AI chat interfaces for PRD Generator, Research & Analysis, and UAT Testing
- RICE Scoring with 3 agent cards (Market Analyst, Technical Feasibility, Business Strategy)
- Kanban board views, Gantt roadmap, comparison panels
- Delivery tracker with progress bars and "Demo Ready" toggles
- Admin panel with LLM cost charts and model configuration

### Mock Data Patterns (Use as Seed Data)
- **Sample PRD:** "Payment Retry Logic" (PRD-042, Submission #SUB-0042)
- **Sample users:** Kurt Carabott, Aisha Patel, David Kim, Emma Larsson
- **Sample domains:** Payments, Onboarding, Risk, Growth, Platform
- **Sample competitors:** Stripe, Adyen, Braintree
- **Sample metrics:** $2,847 monthly LLM spend, 12,430 API calls, $1.24 avg cost per PRD
- **Sample delivery stats:** 7 in progress, 5 on track, 1 at risk, 1 blocked
- **Sample success metrics:** 47 ideas submitted, 31 PRDs generated, 23 days avg time to ship, 78% release adoption

### View Modes Confirmed
- Dashboard: stat cards grid
- Kanban: column-based board
- Gallery: design screen grid
- Flow: user flow with connections
- Timeline/Gantt: roadmap

---

## 11. Recommended Tech Stack for Production

Based on the prototype patterns and requirements, here is the recommended stack for Claude Code development:

### Frontend
```
Framework:        Next.js 14+ (App Router)
UI Framework:     React 18+
Styling:          Tailwind CSS 3+
Component Library: shadcn/ui (already matches the design system patterns)
State Management:  Zustand or React Context (lightweight, fits the prototype's simple state)
Charts:           Recharts (line, bar, radar, scatter) + custom Gantt
Rich Text:        Tiptap or Plate (for PRD editor and release notes)
Drag & Drop:      dnd-kit (for Kanban, backlog reordering, roadmap)
PDF Viewer:       react-pdf
Markdown:         react-markdown + remark-gfm
Diff View:        react-diff-viewer (for PRD version comparison)
Icons:            Lucide React
```

### Backend
```
Runtime:          Node.js 18+
Framework:        Next.js API Routes or tRPC
Database:         PostgreSQL (complex relational data)
ORM:              Prisma or Drizzle
Auth:             NextAuth.js with email whitelist + Google OAuth
File Storage:     S3 or Cloudflare R2 (for PRD exports, design images, attachments)
LLM Integration:  Anthropic Claude API + OpenAI API (configurable per feature)
Queue:            BullMQ or Inngest (for async: spec generation, design generation, research)
Realtime:         Server-Sent Events or WebSockets (for AI chat streaming, live report updates)
```

### External Integrations
```
Figma API:        Push designs as editable frames
Google Stitch:    Design generation (via stitch-mcp-server)
Email:            SendGrid or Resend (notifications)
Search:           Meilisearch or built-in Postgres full-text (for global search)
```

### Suggested File Structure
```
product-hub/
├── src/
│   ├── app/                          # Next.js App Router pages
│   │   ├── (auth)/
│   │   │   ├── login/page.tsx
│   │   │   └── register/page.tsx
│   │   ├── (dashboard)/
│   │   │   ├── layout.tsx            # App shell with sidebar
│   │   │   ├── page.tsx              # Dashboard
│   │   │   ├── submissions/
│   │   │   ├── product/
│   │   │   │   ├── prd-generator/
│   │   │   │   ├── prd-viewer/
│   │   │   │   ├── prd-evaluation/
│   │   │   │   ├── research/
│   │   │   │   ├── rice-scoring/
│   │   │   │   ├── speckit/
│   │   │   │   └── figma-designs/
│   │   │   ├── backlog/
│   │   │   │   ├── global/
│   │   │   │   ├── domain/
│   │   │   │   ├── priority-board/
│   │   │   │   └── roadmap/
│   │   │   ├── delivery/
│   │   │   │   ├── tech-handover/
│   │   │   │   ├── tracker/
│   │   │   │   ├── uat/
│   │   │   │   └── release-notes/
│   │   │   ├── insights/
│   │   │   │   ├── metrics/
│   │   │   │   └── reports/
│   │   │   └── admin/
│   │   │       ├── users/
│   │   │       ├── settings/
│   │   │       └── llm-costs/
│   │   └── api/                      # API routes
│   ├── components/
│   │   ├── ui/                       # shadcn/ui components
│   │   ├── layout/                   # Sidebar, Header, Breadcrumbs
│   │   ├── ai-chat/                  # Reusable AI chat interface
│   │   ├── kanban/                   # Kanban board component
│   │   ├── comparison/               # Side-by-side comparison panel
│   │   └── charts/                   # Chart wrappers
│   ├── lib/
│   │   ├── db/                       # Prisma schema + client
│   │   ├── ai/                       # LLM service layer
│   │   ├── auth/                     # Auth config
│   │   └── utils/                    # Helpers
│   └── types/                        # TypeScript types matching data models
├── prisma/
│   └── schema.prisma                 # Database schema
├── stitch-mcp-server/                # Existing MCP server (kept as-is)
└── public/
```

---

## 12. CLAUDE.md Template for Claude Code

Copy this into your project's `CLAUDE.md` when you start Claude Code:

```markdown
# Product Hub — Claude Code Project

## What is this?
Product Hub is a modern AI-powered SaaS backoffice for end-to-end product management.
Full context is in CLAUDE_CODE_KNOWLEDGE_PACKAGE.md — read it before any major work.

## Tech Stack
- Next.js 14 (App Router), React 18, TypeScript
- Tailwind CSS + shadcn/ui
- PostgreSQL + Prisma
- NextAuth.js (email whitelist + Google OAuth)
- Claude/OpenAI API for LLM features

## Design System
- Primary: #4F46E5 (Deep Indigo), Sidebar: #1E1B4B (Dark Navy)
- Background: #FFFFFF / #F9FAFB, Border radius: 8px, Font: Inter
- Use shadcn/ui components; match the patterns in Product_Hub_App.html

## Key Conventions
- All AI chat interfaces use a split-panel layout (55% chat / 45% preview)
- Status badges are color-coded: Green=Approved, Yellow=In Review, Red=Rejected
- Domain tags use specific colors: Payments=Blue, Onboarding=Teal, Risk=Orange, Growth=Green, Platform=Purple
- RICE scores shown as circular indigo badges
- All screens have breadcrumb navigation

## Important Flows
1. Only PRDs with "Approved" evaluation status can proceed to RICE Scoring
2. RICE Scoring uses 3 AI agents (Market, Technical, Business) with consensus
3. Domain Priority flags in Domain Backlogs are visible in Global Backlog
4. Tech Handover aggregates: PRD + Specs + Designs + Integration Docs + API Contracts + Acceptance Criteria

## Reference Files
- `CLAUDE_CODE_KNOWLEDGE_PACKAGE.md` — Complete project context
- `Product_Hub_Gap_Specifications.md` — Detailed specs for 6 screens
- `Stitch_Prompts_Product_Hub_Backoffice.md` — UI descriptions for all 19 screens
- `Product_Hub_App.html` — Working prototype (open in browser for reference)
- `stitch-mcp-server/` — MCP server for design generation

## Commands
- `npm run dev` — Start development server
- `npm run build` — Build for production
- `npx prisma db push` — Sync database schema
- `npx prisma studio` — Open database GUI
```

---

## 13. Navigation & Sidebar Structure

```
MAIN
  Dashboard                    → /
  Submissions                  → /submissions

PRODUCT
  PRD Generator                → /product/prd-generator
  PRD Viewer                   → /product/prd-viewer/[id]
  PRD Evaluation               → /product/prd-evaluation
  Research & Analysis          → /product/research/[id]
  RICE Scoring                 → /product/rice-scoring/[id]
  Speckit Specs                → /product/speckit/[id]
  Figma Designs                → /product/figma-designs/[id]

BACKLOG
  Global Backlog               → /backlog/global
  Domain Backlogs              → /backlog/domain/[domain]
  Priority Board               → /backlog/priority-board
  Quarterly Roadmap            → /backlog/roadmap

DELIVERY
  Tech Handover                → /delivery/tech-handover/[id]
  Delivery Tracker             → /delivery/tracker
  UAT Testing                  → /delivery/uat/[id]
  Release Notes                → /delivery/release-notes

INSIGHTS
  Success Metrics              → /insights/metrics
  Reports                      → /insights/reports

ADMIN
  Users                        → /admin/users
  Platform Settings            → /admin/settings
  LLM Costs                    → /admin/llm-costs
```

---

## 14. Requirement Traceability Matrix

| Project Requirement | Primary Screen | Supporting Screens |
|---|---|---|
| Admin Area (LLM Cost / Manage Users / Platform Settings) | Admin Settings (Prompt 12) | — |
| Register / Login with Whitelisted Email Addresses | Login & Registration (Prompt 1) | Admin Users tab |
| Stakeholder Submission Form with Attachments | Submission Form (Prompt 2) | — |
| Stakeholder Request → PRD Generator & Validator + Multi-Format Viewer | PRD Generator (Prompt 3) | PRD Viewer (Prompt 3A) |
| Product Processing & Evaluation of PRDs | PRD Evaluation (Prompt 3B) | PRD Viewer, PRD Generator |
| PRD Research & Analysis with LLM Bot | Research & Analysis (Prompt 3C) | RICE Scoring |
| RICE Score with Multiple Agents | RICE Scoring (Prompt 4) | Research feeds into scoring |
| PRD to Speckit Specs Generation | Speckit Specs (Prompt 4A) | PRD Generator, PRD Viewer |
| PRD to Figma Design Generation | Figma Designs (Prompt 4B) | Speckit UI Component specs |
| Compare Ideas at Global Backlog Level | Global Backlog (Prompt 5) | Domain Backlogs |
| Compare Ideas at Domain Backlog Level | Domain Backlogs (Prompt 5A) | Global Backlog |
| Visualise in Priority Backlog | Priority Board (Prompt 5) | — |
| Visualise in Quarterly Roadmap | Quarterly Roadmap (Prompt 6) | — |
| Tech Handover Package | Tech Handover (Prompt 7) | PRD Viewer, Speckit, Figma |
| Monitor Delivery Progress | Delivery Tracker (Prompt 8) | — |
| UAT Screen & LLM Testing | UAT Testing (Prompt 9) | — |
| Release Notes for Stakeholders | Release Notes (Prompt 10) | — |
| Reports to Monitor Success Metrics | Success Metrics (Prompt 11) | — |

---

## Quick Start Guide for Claude Code

1. **Read this document first** — it's your complete context
2. **Open `Product_Hub_App.html`** in a browser — this is your visual reference for every screen
3. **Set up the project:**
   ```bash
   npx create-next-app@latest product-hub --typescript --tailwind --app --src-dir
   cd product-hub
   npx shadcn@latest init
   ```
4. **Copy `CLAUDE_CODE_KNOWLEDGE_PACKAGE.md`** into the project root
5. **Create `CLAUDE.md`** using the template in Section 12
6. **Start building** — recommended order:
   - Phase 1: App Shell + Sidebar + Auth (Prompts 0, 1)
   - Phase 2: Submission Form + PRD Generator (Prompts 2, 3)
   - Phase 3: PRD Viewer + Evaluation (Prompts 3A, 3B)
   - Phase 4: Research + RICE Scoring (Prompts 3C, 4)
   - Phase 5: Speckit + Figma Designs (Prompts 4A, 4B)
   - Phase 6: Backlogs + Roadmap (Prompts 5, 5A, 6)
   - Phase 7: Delivery pipeline (Prompts 7, 8, 9, 10)
   - Phase 8: Insights + Admin (Prompts 11, 12)

---

*Generated from Claude Desktop (Cowork) — April 15, 2026*
*Source files: Product_Hub_App.html, Product_Hub_Gap_Specifications.md, Stitch_Prompts_Product_Hub_Backoffice.md, stitch-mcp-server/*

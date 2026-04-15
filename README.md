# ft-product-hub

> **Modern AI Product Platform** — Built by Product Owners, for Product Management.

A unified platform that brings AI-powered tooling into the daily workflows of Product Managers: from ideation and discovery through roadmapping, prioritisation, and delivery tracking.

---

## Vision

Product Managers spend too much time in context-switching — between discovery notes, roadmap tools, stakeholder updates, and sprint boards. **ft-product-hub** collapses that surface area into a single, AI-augmented workspace that helps PMs think faster, communicate clearer, and ship the right things.

---

## Core Modules

| Module | Description |
|---|---|
| **Discovery** | AI-assisted user research synthesis, interview notes → insight extraction |
| **Ideation** | Opportunity scoring, idea backlog with AI rationale generation |
| **Roadmap** | Visual roadmap builder with AI-assisted prioritisation (RICE, WSJF, MoSCoW) |
| **Stakeholder Comms** | Auto-drafted release notes, status updates, and PRD generation |
| **Metrics** | Goal-setting (OKR/KPI), outcome tracking, and anomaly surfacing |
| **AI Assistant** | Cross-module conversational agent with full product context |

---

## Architecture

```
ft-product-hub/
├── apps/
│   ├── web/          # Next.js frontend — product dashboard & workspace
│   └── api/          # Node.js API — business logic, AI orchestration
├── packages/
│   ├── ai-core/      # Shared AI primitives (prompts, chains, agents)
│   ├── shared-types/ # TypeScript types shared across apps
│   └── ui/           # Shared component library
├── docs/
│   └── adr/          # Architecture Decision Records
└── .github/
    └── workflows/    # CI/CD pipelines
```

---

## Tech Stack

- **Frontend**: Next.js 15 (App Router), TypeScript, Tailwind CSS, shadcn/ui
- **Backend**: Node.js + Express / Hono, Prisma ORM, PostgreSQL
- **AI Layer**: Anthropic Claude API (claude-sonnet-4-6), LangChain/LangGraph
- **Auth**: Clerk
- **Infra**: Vercel (web), Railway / Fly.io (api), Neon (database)
- **Monorepo**: pnpm workspaces + Turborepo

---

## Getting Started

```bash
# Install dependencies
pnpm install

# Copy environment variables
cp .env.example .env.local

# Start all apps in dev mode
pnpm dev
```

---

## Documentation

- [Architecture Decision Records](./docs/adr/)
- [Contributing Guide](./CONTRIBUTING.md)

---

## Status

> **Phase 0 — Foundation** — Repository scaffolding, architecture decisions, and core infrastructure setup.

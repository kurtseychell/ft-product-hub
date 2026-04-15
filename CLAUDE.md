# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**ft-product-hub** is a Modern AI Product Platform — built by Product Owners, for Product Management. It is a unified, AI-augmented workspace targeting Product Managers: from discovery and ideation through roadmapping, stakeholder communications, and delivery metrics.

This is an early-stage project. No application code exists yet. When building begins, decisions about stack, structure, and conventions should be made collaboratively with the user before scaffolding.

## Planned Core Modules

- **Discovery** — AI-assisted user research synthesis and insight extraction
- **Ideation** — Opportunity scoring and idea backlog
- **Roadmap** — Visual roadmap builder with AI-assisted prioritisation (RICE, WSJF, MoSCoW)
- **Stakeholder Comms** — Auto-drafted release notes, status updates, PRDs
- **Metrics** — OKR/KPI goal-setting and outcome tracking
- **AI Assistant** — Cross-module conversational agent with full product context

## Working Conventions

- Do not scaffold, generate boilerplate, or add files speculatively. Build only what is explicitly requested.
- When architecture decisions arise (stack choice, folder structure, data model), surface the trade-offs and confirm before implementing.
- Prefer a monorepo layout (`apps/`, `packages/`) if/when multiple apps or shared packages emerge.
- The AI layer should use the Anthropic Claude API (`claude-sonnet-4-6` as default, `claude-haiku-4-5` for high-volume low-complexity tasks) with prompt caching enabled for long-context operations.

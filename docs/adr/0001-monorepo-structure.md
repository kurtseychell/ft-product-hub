# ADR 0001: Monorepo Structure with pnpm + Turborepo

**Date:** 2026-04-15  
**Status:** Accepted

## Context

The platform spans a Next.js frontend, a Node.js API, shared AI primitives, and a shared component library. These evolve together and share types, making a monorepo the natural fit.

## Decision

Use **pnpm workspaces** for package management with **Turborepo** for task orchestration and caching.

- `apps/web` — Next.js frontend
- `apps/api` — Node.js API
- `packages/ai-core` — Shared AI primitives (Claude prompts, chains, agents)
- `packages/shared-types` — TypeScript types shared across apps
- `packages/ui` — Shared Tailwind/shadcn component library

## Consequences

- Single `pnpm install` at root installs all dependencies
- `turbo run dev` starts all apps with dependency-aware ordering
- Build caching means only changed packages rebuild on CI
- All apps share the same TypeScript version and lint config

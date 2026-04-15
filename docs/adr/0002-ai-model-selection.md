# ADR 0002: AI Model — Anthropic Claude (claude-sonnet-4-6)

**Date:** 2026-04-15  
**Status:** Accepted

## Context

The platform's core value proposition is AI-assisted product management workflows. Model selection directly impacts quality of insight extraction, PRD generation, and roadmap reasoning.

## Decision

Use **Anthropic Claude claude-sonnet-4-6** as the primary model via the Anthropic SDK with **prompt caching** enabled for long-context operations (e.g. user research synthesis, PRD drafts).

## Rationale

- Best-in-class instruction following and structured output for product artefacts
- Extended context window handles full PRDs, research repos, and sprint histories
- Prompt caching significantly reduces cost and latency for repeated context (e.g. product context loaded on every message)
- Tool use / function calling enables the AI assistant to query live roadmap data

## Consequences

- All AI calls route through `packages/ai-core` — no direct SDK calls in app code
- Prompt templates are versioned in `packages/ai-core/src/prompts/`
- Fallback to `claude-haiku-4-5` for high-volume, low-complexity tasks (e.g. tagging, classification)

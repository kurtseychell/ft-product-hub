# Product Hub — Build-Ready Specifications

> **Purpose.** Engineer-consumable suite that closes every open loop from `../User_Journey_Flow.md` §9.2 and every blocking item from `../Component_Data_Architecture.md` §8.4. After reading this suite, an engineering team should be able to scaffold the platform end-to-end without additional clarification on data, algorithms, contracts, security, or deployment.
>
> **Source hierarchy.** The canonical UI lives in `../../screens/` (Product Hub reference) and `../../sportsbook-hub-case-study/` (applied walk-through). The canonical product decisions live in `../User_Journey_Flow.md`. The component data wiring lives in `../Component_Data_Architecture.md`. **This build-specs suite is the implementation spec.**

---

## Reading order

Read files in this order — each builds on the last.

| # | File | What it covers | Read time |
|---|---|---|---|
| 00 | `00_README.md` | This index | 5 min |
| 01 | `01_Algorithms.md` | Submission Score · Bug Severity · RICE Consensus · Transformation Velocity (closes OL-5, OL-B3, OL-B6) | 15 min |
| 02 | `02_Bug_Pipeline_Specification.md` | Full Stage B-Bug pipeline: RSD flow, replication mechanism, triage agent, data model (closes OL-B2, OL-B4, OL-B7) | 20 min |
| 03 | `03_Brief_Lifecycle_Policy.md` | Lock semantics, v(N+1) supersession UX, affordance UI (closes OL-B1, OL-B8) | 10 min |
| 04 | `04_Database_Schema.sql` | Full Postgres DDL with indexes, RLS, triggers | 30 min |
| 05 | `05_API_and_Events.md` | REST contract (all endpoints) + event bus schema (all 22 events) | 45 min |
| 06 | `06_RBAC_Security_Observability.md` | Role × action matrix, threat model, PII handling, metrics/logs/traces/alerts | 30 min |
| 07 | `07_Deployment_Testing_Phasing.md` | Infra plan, v1→v2 migration path, test strategy across unit/integration/E2E/load/chaos | 30 min |

Total: **~3 hours** to absorb the full suite.

---

## What's decided vs. still ambiguous

### Decided and frozen (safe to build against)
- All of §6 Per-Screen Wiring in `Component_Data_Architecture.md`
- Data model (§3 in architecture doc; formalised as DDL in `04_Database_Schema.sql` here)
- All 22 event types (§4.3 in architecture doc; schemas formalised in `05_API_and_Events.md` here)
- Algorithm specs in `01_Algorithms.md` (proposed; see note below)
- RBAC matrix in `06_RBAC_Security_Observability.md`
- v1 scope: 20 canonical screens + 4 Bug pipeline screens. Notification Settings / Manage Users / Platform Settings deferred to v2 (OL-3, OL-4)

### Proposed — confirm before build (but safe defaults)
- **Submission Score weighting** — default 60/20/10/10 across completeness/depth/specificity/AI-confidence-avg. Adjustable via platform config.
- **Bug Severity formula** — default `S × min(Reach/1000, 10)` where S ∈ {1,2,3,5,8}. Calibration left to platform config.
- **RICE consensus weighting** — equal weights for the 3 council agents; max-confidence-range span of 2 dimensions before review flag.

### Outside v1 scope (documented but not implemented)
- OL-3 Notification Settings screen
- OL-4 Manage Users + Platform Settings screens
- Multi-tenancy (v1 is single-tenant per deployment)
- Mobile clients (v1 is desktop web only)

---

## How to use this suite when building

**For a backend engineer starting greenfield:**
1. Read `04_Database_Schema.sql` and apply to a Postgres 16 instance
2. Scaffold services per `05_API_and_Events.md` §3 (one service per bullet)
3. Wire `LLMCostSvc` and `AuditSvc` first — they're dependencies for everything else
4. Implement `IdentitySvc` + auth middleware
5. Implement remaining services in dependency order (see `05_API_and_Events.md` §2 service dependency graph)

**For a frontend engineer:**
1. Read `../Component_Data_Architecture.md` §5 (component catalog) to inventory primitives to build
2. Read `../Component_Data_Architecture.md` §6 per-screen to understand data contracts
3. The existing HTML prototypes in `../../screens/` are your visual source-of-truth

**For a data engineer:**
1. Read `04_Database_Schema.sql` for OLTP
2. Read `06_RBAC_Security_Observability.md` for telemetry schemas
3. Read `05_API_and_Events.md` event bus schema for stream consumers

**For a security / compliance reviewer:**
- Read `06_RBAC_Security_Observability.md` top-to-bottom
- Cross-check against `04_Database_Schema.sql` RLS policies

**For a product manager / QA:**
- Read `../User_Journey_Flow.md` + `02_Bug_Pipeline_Specification.md`
- Acceptance criteria for each feature derive from the per-screen wiring in `../Component_Data_Architecture.md` §6

---

## Canonical change process

Any change that contradicts a spec here MUST:
1. Be captured as an ADR (Architecture Decision Record) in `_SOURCES/ADRs/`
2. Update the affected spec file and the `User_Journey_Flow.md` naming/decision tables
3. Be versioned — specs carry semantic versions at the top (added on first amendment)

Anything stated here that turns out wrong in implementation: open a PR that updates this suite **first**, then change code. The docs are source of truth.

---

*Version 1.0 — generated 2026-04-20. No amendments yet.*

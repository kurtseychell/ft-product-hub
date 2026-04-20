# Deployment, Testing & Phasing

How to ship and sustain Product Hub in production.

---

## 1. Deployment Model

### 1.1 Environments

| Env | Purpose | Data | Scale |
|---|---|---|---|
| `dev` | Engineer sandboxes | Seeded + local | Single-pod / dev-cluster |
| `staging` | Integration + acceptance | Daily-masked copy of prod | 50% of prod scale |
| `canary` | Progressive rollout testing | Prod data; serves 5% of real traffic | Prod-class |
| `prod` | Live | Real | Scale targets below |

### 1.2 Infrastructure components (v1 baseline, cloud-agnostic)

```
                       ┌─────────────────────┐
                       │  CDN (CloudFront)   │
                       └──────────┬──────────┘
                                  │
                       ┌──────────▼──────────┐
                       │  Web / API Gateway  │
                       └──────────┬──────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
         ┌────────▼──────┐  ┌────▼─────┐  ┌──────▼────────┐
         │ Frontend (SPA)│  │  Services│  │  SSE/WS Edge  │
         │  served static │  │ (k8s pods)│  │  Gateway      │
         └───────────────┘  └─────┬─────┘  └───────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
  ┌───────▼────────┐      ┌──────▼──────┐      ┌─────────▼──────┐
  │   Postgres 16   │      │    Redis    │      │     Kafka      │
  │  (primary +     │      │  (cache,    │      │  (event bus)   │
  │   read replicas)│      │   locks,    │      │                │
  └────────────────┘      │   sessions) │      └───────┬────────┘
  ┌────────────────┐      └──────────────┘              │
  │   OpenSearch   │                                    │
  │   (search)     │◄───── event-driven updates ───────┤
  └────────────────┘                                    │
  ┌────────────────┐                                    │
  │   ClickHouse   │◄─── event-driven rollups ─────────┤
  │  (analytics +  │                                    │
  │  time-series)  │                                    │
  └────────────────┘                                    │
  ┌────────────────┐                                    │
  │  Object Store  │                                    │
  │     (S3)       │                                    │
  └────────────────┘                                    │
  ┌────────────────┐                                    │
  │  LLM Provider  │◄─────── AI agents ─────────────────┘
  │   (Anthropic)  │
  └────────────────┘
```

### 1.3 Containerisation & orchestration

- **Containers**: distroless base images; no shell, no package manager in runtime
- **Orchestration**: Kubernetes (EKS / GKE / AKS); one deployment per service
- **Pod shape**: 2 replicas minimum, HPA on CPU/RPS; rolling updates with max surge 25%
- **Service mesh** (optional for v1): Istio or Linkerd for mTLS, traffic shifting, retry policies
- **Ingress**: NGINX or cloud-native (ALB/GCP LB); TLS termination at the edge
- **Cron/scheduled jobs**: Kubernetes CronJobs for nightly aggregations, retention sweeps, budget threshold checks

### 1.4 Scale targets (v1)

Designed for **~500 users × ~5k active requests/year × ~50k PRDs lifetime**.

| Component | Target |
|---|---|
| API pods | 4 pods × 0.5 CPU, 512MB — scales to 16 pods on 1k req/min |
| Postgres | 4 vCPU, 16GB RAM, 500GB SSD, 1 read replica |
| Redis | 1 shard, 4GB, HA pair |
| Kafka | 3 brokers, 3 replicas per topic |
| OpenSearch | 3 data nodes, 8GB heap each |
| ClickHouse | 1 node, 8 vCPU — shardable later |
| Object storage | No practical cap |

At these targets, expected cost ~$3–6k/month infra + $1–3k/month LLM (depends on usage; monitor `[Z01]`).

### 1.5 CI/CD

- **Build**: trunk-based; all PRs require passing CI
- **Tests** (see §3): unit + integration + contract + E2E smoke on every PR
- **Security scan**: SCA (Snyk) + container scan (Trivy) + SAST (CodeQL)
- **Deploy to dev**: on merge to main, automatic
- **Deploy to staging**: nightly + on-demand
- **Deploy to prod**:
  - Automatic to canary (5% traffic) after staging passes; 30 min observation window
  - Automatic promotion to full prod if canary SLOs hold
  - Automated rollback on p95 latency +50% OR error rate +5% sustained 5 min

### 1.6 Configuration

- All config via env vars (12-factor)
- Secrets from KMS-backed store (§06 §2.4)
- Platform settings editable at runtime (via admin UI → `platform_settings` table); changes emit `AlgorithmConfigChangedEvt` and reload affected services

### 1.7 Data migrations

- Migrations managed by **Flyway** (Postgres) with version-numbered SQL files
- Zero-downtime rules:
  1. Additive schema changes first (add column, add table)
  2. Deploy app that can use old OR new schema
  3. Backfill
  4. Deploy app that requires new schema
  5. Remove old schema in subsequent release
- Breaking migrations must have a rollback plan documented in the PR

### 1.8 DR & backups

- Postgres: continuous WAL archiving to S3; point-in-time recovery within 7 days
- Object storage: cross-region replication
- Kafka: retention 30 days on durable topics; 7 days on ephemeral
- Runbook for full-region failover: documented; tested quarterly
- RTO: 4 hours; RPO: 15 min

---

## 2. Phasing Plan

Ship increments that are individually valuable and defer complexity. Don't build everything before shipping anything.

### 2.1 v1.0 — Minimum viable product (target: 16 weeks)

**In scope (end-to-end path for Features):**
- All 20 canonical screens A01–Z01 (outliers re-skinned per `../../_HANDOFF_CLAUDE_DESIGN/Regeneration_Prompts.md`)
- Services: Identity, Submission, PRD, Research, RICE, Spec, Design (with Figma push), Backlog, Domain Backlog, Roadmap, Handover, Delivery, UAT, Release Notes, Admin, LLM Cost, Metrics, Audit, Search (basic, no similarity), Notifications (defaults on for everyone)
- All algorithms (`01_Algorithms.md`)
- Event bus with 22 documented events
- RBAC + RLS + MFA
- Observability: metrics + logs + traces + basic dashboards + alerts

**Explicitly NOT in v1.0:**
- Bug pipeline screens (Bug Workspace, Manual Replication, Triage) — but RSDSvc + BugReplicationSvc services CAN be built
- SimilaritySvc (duplicate detection) — deferred to v1.1
- Notification Settings UI (v2)
- Manage Users UI, Platform Settings UI (v2) — admin edits via direct DB / CLI for v1
- Mobile clients
- Multi-tenancy

**Feature flags for graceful rollout:**
- `flag.bug_pipeline_enabled` (false in v1.0)
- `flag.similarity_suggestions` (false in v1.0)
- `flag.auto_generate_release_notes` (true for `Admin` role only initially)
- `flag.ai_test_agent` (true; disable if cost spikes)

### 2.2 v1.1 — Bug pipeline (target: +6 weeks)

**Adds:**
- Bug Workspace, Bug Replication Result, Manual Replication, Bug Triage Queue screens (per `../../_HANDOFF_CLAUDE_DESIGN/Regeneration_Prompts.md` §2)
- `BugReplicationSvc` wired to tier 1 (log query) + tier 3 (test harness) + tier 5 (LLM inference). Tier 2 (trace replay) and tier 4 (sandbox) behind cost-cap flag for gradual rollout.
- Bug Severity algorithm live; scoring surfaces on D01/D02 for Type=Bug rows
- `SimilaritySvc` with bug duplicate detection in Triage

### 2.3 v1.2 — UX polish + v2 scope starts (target: +8 weeks)

**Adds:**
- Notification Settings screen (OL-3)
- Similarity suggestions for PRDs on `[B05]`
- Live comparison panel improvements + Recent Comparisons (if feedback demands)
- Brief supersession UX refinements based on real-world data

### 2.4 v2.0 — Admin & scale (target: +12 weeks)

**Adds:**
- Manage Users full UI (OL-4)
- Platform Settings full UI (OL-4)
- Multi-tenancy scaffolding (separate deployments remain default; optional tenant isolation via RLS tenant_id column)
- Advanced metrics (custom dashboards)
- API for external integrations (webhooks out)

### 2.5 Feature flags matrix

| Flag | v1.0 | v1.1 | v1.2 | v2.0 |
|---|---|---|---|---|
| `bug_pipeline` | off | **on** | on | on |
| `similarity` | off | bug-only | on | on |
| `notification_settings_ui` | off | off | **on** | on |
| `platform_settings_ui` | off | off | off | **on** |
| `multi_tenancy` | off | off | off | beta |

### 2.6 Migration path & data back-compat

- Every spec here is versioned; v1.0 is baseline, no migration to run
- v1.1 adds tables (rsds, replication_attempts, bug_reports already in v1 schema — just unused)
- v1.2 adds `notification_prefs` rows as users opt in (schema already present)
- v2.0 adds `tenant_id` columns — migration runs in 3 phases per §1.7

---

## 3. Testing Strategy

### 3.1 Pyramid

```
             ┌──────────┐
             │   E2E    │  ← ~50 scripted journeys
             ├──────────┤
             │ Contract │  ← ~20 service-to-service contracts
             ├──────────┤
             │Integration│  ← ~200 service-level tests with real DB
             ├──────────┤
             │   Unit   │  ← thousands
             └──────────┘
```

### 3.2 Unit tests

- Per-service, per-module
- Pure functions (algorithms, validators, formatters)
- Mock external dependencies; don't test through them
- Target: every public function has at least one happy path + one edge test
- Coverage threshold in CI: **80% line coverage minimum**, 90% for algorithms

### 3.3 Integration tests

- Per service, real Postgres (testcontainers) + real Redis + real Kafka
- Test the full service API including RLS
- Test events are emitted correctly; test subscribers react correctly
- Seed data per suite; clean between tests
- Target: every endpoint has happy path + 1–2 error paths

### 3.4 Contract tests

- Producer tests: service emits events matching the schema
- Consumer tests: service handles every event version it subscribes to
- Run on every PR — producer + consumer must both still pass
- Tool: Pact or equivalent

### 3.5 End-to-end tests

Playwright scripts running real browser against a full staging environment. Cover:

| # | Journey | Personas |
|---|---|---|
| 1 | Happy-path Feature: submit → PRD → RICE → approve → backlog → sprint → UAT → release | Stakeholder, PM, PL, EL, QA |
| 2 | PRD Evaluation cycle with revisions | Stakeholder, PM, PL |
| 3 | Bug happy-path: submit → AI replicates → triage → dev → UAT → release (v1.1+) | Stakeholder, QA, EL |
| 4 | Bug AI-fail fallback: submit → AI fails → QA manual → triage (v1.1+) | Stakeholder, QA |
| 5 | Brief supersession: v1 in review, Stakeholder submits v2, supersedes | Stakeholder, PM |
| 6 | Brief supersession deferred: v1 in review, Stakeholder submits v2, chooses Keep | Stakeholder, PM |
| 7 | RICE manual override with audit | PL |
| 8 | Figma push round-trip | PM |
| 9 | Release notes generation + publish with multi-channel | PM |
| 10 | Admin LLM budget threshold reached (simulated) | Admin |
| 11 | Cross-domain comparison → commit to sprint | Domain Owners |

Each E2E is tagged `@smoke` (runs on every PR), `@nightly`, or `@weekly`.

### 3.6 Load testing

- Weekly load test in staging
- Scenarios:
  - 500 concurrent users browsing backlog + comparing
  - 50 concurrent PRD Builder sessions with AI (cost-capped)
  - Release publish broadcasting to 500 stakeholders
- Tool: k6 or Gatling
- Targets: p95 < 500ms for non-AI endpoints; p95 < 5s for AI endpoints

### 3.7 Chaos testing

- Monthly chaos exercises in staging
- Scenarios:
  - Postgres primary failover (RTO check)
  - One Kafka broker down
  - LLM provider returning 503
  - Redis down (sessions + caches)
  - S3 slow (uploads should degrade gracefully)
- Tool: Chaos Mesh or custom fault-injection scripts

### 3.8 Security testing

- SAST on every PR
- DAST (OWASP ZAP baseline) weekly against staging
- Penetration test annually (external)
- Red-team exercise after any new privilege boundary added (e.g., tenant isolation in v2.0)

### 3.9 AI-specific testing

Unique to this platform (AI agents are first-class):
- **Prompt regression**: golden conversations per agent replayed weekly; diffs surfaced for review. If `AI.PRD` output shape/quality drifts after a model/prompt change, we catch it.
- **Cost regression**: each agent's average cost per invocation tracked; alert on +30% shift
- **Refusal/safety tests**: inject unsafe requests; verify agents decline appropriately
- **Determinism-where-required**: algorithms in §01 are deterministic; test vectors committed to repo

### 3.10 Acceptance testing
- Every user story (per SpecKit spec) has acceptance criteria → becomes UAT criteria (see `[E02]`)
- PM signs off on acceptance before release

### 3.11 Test data

- Synthetic generators per entity (Faker-based)
- Shared seed: 1 admin, 3 PMs, 2 PLs, 3 Domain Owners, 2 Engineers, 2 QA, 10 Stakeholders, 50 Requests across types, 30 PRDs at various stages, 15 Bugs
- Personas have fixed emails (admin@test.local, etc.) for consistency

---

## 4. Release process

1. **PR merged to main** → CI runs → deploys to `dev`
2. **Nightly staging deploy** → runs full E2E suite + load tests
3. **Release cut**: weekly on Wednesdays; tag `v1.x.y`; builds immutable artifact
4. **Canary deploy**: 5% of prod traffic; 30-min observation
5. **Full rollout**: automatic if SLOs hold; manual stop button available
6. **Release notes published**: automatically drafted by `AI.RLN` and reviewed by release manager before `[E03]` publish
7. **Post-release**: 48h monitoring window with elevated alert sensitivity

Hotfix process: bypass nightly; deploy straight from hotfix branch after fast-track CI; retroactive release notes.

---

## 5. Dependencies & procurement

Before build begins, confirm access to:
- Cloud provider (AWS / GCP / Azure) with budget approval
- LLM provider account (Anthropic preferred; fallback OpenAI/Vertex for resilience) — API key provisioned
- Figma enterprise with API token scope
- SSO provider (Okta / Azure AD / Google Workspace)
- Email provider (SendGrid / SES)
- Slack workspace for notifications (for internal users)
- Confluence (for release notes distribution)
- Error monitoring (Sentry or equivalent)
- Status page provider (e.g., Statuspage)

Contract terms to secure:
- LLM provider: committed capacity for expected load; SLA for latency
- Figma: enterprise plan with API access (non-Enterprise doesn't support Code Connect)
- Cloud: budget alerts matching LLM cost alert thresholds

---

## 6. Team shape & responsibilities (recommendation)

Not prescriptive, but useful anchor for the 16-week v1.0 delivery:

| Role | Count | Focus |
|---|---|---|
| Tech lead / architect | 1 | Architecture decisions, cross-service contracts, ADRs |
| Backend engineer | 3 | Services; one pair per "thematic cluster" (Identity+Submission+PRD; Research+RICE+Spec+Design; Backlog+Delivery+UAT+ReleaseNotes) |
| Data engineer | 1 | Schema evolution, MetricsSvc, SearchSvc, SimilaritySvc |
| Frontend engineer | 2 | 20 screens; design system extraction; real-time (SSE/WS) |
| ML/prompt engineer | 0.5 | Prompt tuning per agent; cost optimisation; prompt regression suite |
| DevOps / SRE | 1 | Infra, CI/CD, observability, security tooling |
| QA engineer | 1 | E2E suite, UAT automation, acceptance tracking |
| Product manager | 1 | Prioritisation, acceptance, release |
| Designer | 0.5 | Polish, Claude Design handoff review |

Total: ~10 people × 16 weeks = ~40 person-months for v1.0. Plus ongoing run-rate of ~6 FTE after launch.

---

## 7. Success criteria for v1.0

**Technical:**
- SLO 99.5% availability sustained over 30 days
- p95 API latency < 500ms (non-AI); < 5s (AI)
- Zero S1 security incidents in first 90 days
- Auto-rollback triggered < 3 times in first 90 days

**Product:**
- 80%+ of submitted Requests reach the Backlog Approved stage (or earlier decisive outcome) — measures pipeline flow
- Avg time from Submission → Final PRD < 5 business days (measured via `[E04]` KPI)
- RICE accuracy R² ≥ 0.6 after 3 months of post-release measurement
- Stakeholder NPS ≥ 40 after 90 days

**Operational:**
- LLM cost per completed PRD < $10 (averaging across all agents involved)
- Total infra + LLM cost < $15k/month at baseline scale
- On-call paging volume < 2 pages/week sustained

If any of these consistently miss, the phasing plan adjusts — v1.1 scope is reduced, reliability work prioritised.

---

*See `04_Database_Schema.sql` for DDL, `05_API_and_Events.md` for contracts, `06_RBAC_Security_Observability.md` for operational policies. `00_README.md` is the master index.*

# Product Hub — Component Data Architecture

> **Purpose.** Build-ready specification of every component on every screen, with each component's data provenance (source, generator, editor, storage), service dependencies, cross-component connections, and governance requirements. This is the document a backend engineer uses to scaffold the platform and a data engineer uses to design the schema.
>
> **How to read.** §2–§5 define shared vocabulary (actors, services, data, events, reusable components). §6 applies that vocabulary per screen. §7 covers cross-cutting concerns that apply to every component. §8 provides summary matrices for fast lookup.
>
> **Conventions.**
> - `Svc` suffix = domain service (e.g., `PRDSvc`)
> - `Evt` suffix = domain event (e.g., `PRDMarkedFinalEvt`)
> - Actor shorthand: `[H]` = human persona, `[AI]` = PM-BOT agent, `[S]` = system actor (scheduler, webhook, etc.), `[X]` = external party
> - `r/o` = read-only
> - `*` = decision pending (links to an open loop in Journey doc §9.2)
>
> **Source:** derived from the 20 canonical screens (`/screens/A01.html`–`/screens/Z01.html`) and the canonical journey (`_SOURCES/User_Journey_Flow.md`). Where the two disagree, the screens win.

---

## 1. Document map

| Section | What it covers | Audience |
|---|---|---|
| **§2 Actors** | Human personas + PM-BOT agents + system actors + external parties | Everyone |
| **§3 Data Layer** | Persistence tiers (OLTP / object store / search / cache / events / time-series / vector) + core entities | Data engineer, backend engineer |
| **§4 Service Layer** | Domain services with responsibilities, owned entities, emitted/consumed events | Backend engineer, architect |
| **§5 Component Catalog** | Reusable UI primitives with data contracts | Frontend engineer, backend engineer (for API shapes) |
| **§6 Per-Screen Wiring** | All 20 screens; every on-screen component mapped to the 8 governance dimensions | All engineers, QA, data governance |
| **§7 Cross-cutting** | Auth / audit / versioning / notifications / cost accounting / filtering | All engineers, security, compliance |
| **§8 Summary matrices** | Component×Service, Entity×Screen, Event×Subscriber — fast lookups | Architect, refactor planning |

---

## 2. Actors

Every piece of data on every screen has an **origin actor** (who generated it) and **editor actors** (who can mutate it). Screens also have **viewer actors** (who can read it).

### 2.1 Human personas (from Journey doc §1)

| Code | Persona | Key capabilities (data-level) |
|---|---|---|
| `H.STK` | Stakeholder | Create `Request`, edit own Brief drafts, read own Requests, comment on own Requests |
| `H.PM` | Product Manager | Edit assigned PRDs, drive AI-assisted workflows, commit Handover, publish Release Notes |
| `H.PL` | Product Lead / Domain Owner | Evaluate PRDs, score RICE overrides, prioritize Domain Backlog, commit Sprints |
| `H.EL` | Engineering Lead | Receive Handover, run Delivery, mark UAT-ready |
| `H.QA` | QA / Tester | Execute UAT criteria, file bugs, perform manual bug replication |
| `H.AD` | Admin | Manage users, configure LLM budgets, set platform settings |
| `H.EX` | Executive / Analyst | Read-only consumer of metrics and dashboards |

### 2.2 PM-BOT specialist agents (system actors)

Each is a callable with its own prompt template, context window, cost profile, and audit trail.

| Code | Agent | Called from | Produces | Cost profile |
|---|---|---|---|---|
| `AI.PRD` | PM-BOT · PRD Agent | `[B02]` | PRD section text, Submission Score components, clarifying questions | Medium (sustained conversation) |
| `AI.RSD` | PM-BOT · PRD Agent (Bug-Triage variant) | Bug Workspace (TBD) | RSD section text | Medium |
| `AI.BREP` | PM-BOT · Bug Replication Agent | Bug Workspace (TBD) | Replication attempt log, pass/fail artifact | High (may spin up sandbox)* |
| `AI.RES` | PM-BOT · Research Agent | `[C01]` | Research report sections, recommendation + confidence, source list | Medium–High (web fetches) |
| `AI.RICE.M` | Market Analyst (council) | `[C02]` | R/I/C/E numerics + commentary per dimension | Low |
| `AI.RICE.T` | Technical Feasibility (council) | `[C02]` | R/I/C/E numerics + commentary | Low |
| `AI.RICE.B` | Business Strategy (council) | `[C02]` | R/I/C/E numerics + commentary | Low |
| `AI.SPEC` | PM-BOT · Spec Agent | `[C03]` | User stories, acceptance criteria, AI Confidence per spec | Medium |
| `AI.DSG` | PM-BOT · Design Agent | `[C04]` | Design variants (images + HTML/React refs) | High (image generation) |
| `AI.TST` | PM-BOT · Test Agent | `[E02]` | Edge-case proposals, spec-conflict detections | Low |
| `AI.RLN` | PM-BOT · Release Notes Agent | `[E03]` | Draft release-note sections referencing PRD IDs | Low |

All AI calls go through `LLMCostSvc` for accounting. Every invocation creates an `AuditSvc` entry.

### 2.3 System actors (non-human, non-AI)

| Code | Actor | Function |
|---|---|---|
| `S.SCHED` | Scheduler | Fires cron triggers for digest notifications, retention sweeps, budget threshold checks |
| `S.EVT` | Event Bus | Dispatches domain events to subscribers (see §4.3) |
| `S.NTF` | Notification Dispatcher | Consumes notification events, routes to channel providers |
| `S.SYN` | Sync Workers | Figma push, Stripe webhooks, etc. |
| `S.AGG` | Aggregator | Rolls up time-series for `[A02]` Dashboard and `[E04]` Success Metrics |
| `S.AUD` | Audit Writer | Consumes all mutation events, writes immutable audit log |

### 2.4 External parties

| Code | External | Consumed by |
|---|---|---|
| `X.IDP` | OIDC / SAML IdP | `IdentitySvc` for SSO |
| `X.FIGMA` | Figma REST API | `DesignSvc` for "Push to Figma" |
| `X.LLM` | LLM providers (Anthropic primary) | All AI agents via `LLMCostSvc` |
| `X.SMTP` | Email provider | `S.NTF` |
| `X.SLACK` | Slack API | `S.NTF` |
| `X.CONF` | Confluence API | `S.NTF` for release notes distribution |
| `X.STRIPE` | Stripe (used as example PRD in screens; not platform itself) | n/a — illustrative only |

---

## 3. Data Layer

### 3.1 Persistence tiers

| Tier | Technology (recommended) | Use | Data |
|---|---|---|---|
| **OLTP** | PostgreSQL 16 (with RLS for domain isolation) | Transactional writes; version history tables | All core entities |
| **Object storage** | S3 or equivalent | PRD PDFs / PPTXs, design images + variants, attachments, RSD evidence (screenshots, videos, logs) | Binary / large text |
| **Search index** | OpenSearch / Elasticsearch | Full-text search across PRDs, specs, backlog items, research reports | Denormalised read models |
| **Cache** | Redis | Session state, live PRD draft state, transient Submission Score, comparison panel selections (ephemeral per OL-6) | Short-lived k/v |
| **Event bus** | Kafka or equivalent (Kafka recommended for replay) | Domain events (see §4.3) | Event log |
| **Time-series** | ClickHouse OR Postgres + TimescaleDB | Metrics for `[E04]` Success Metrics, LLM cost ledger for `[Z01]`, Submission Score history | Aggregable observations |
| **Vector store** | pgvector (on Postgres) OR Pinecone | Embeddings for "find similar PRDs / bugs / research" | Embeddings + metadata |
| **Blob archive** | Glacier / S3-IA (tier of object storage) | Archived artifacts (PRDs Archived, Released bugs closed >1yr) | Cold archive |

### 3.2 Core entities (OLTP tables)

Versioned entities carry `version_number` (integer, monotonic) + `content_snapshot` (immutable JSONB of the version's state) in a companion `*_versions` table. Current state lives in the primary table.

| Entity | Primary table | Versions table | Key columns | Owned by |
|---|---|---|---|---|
| User | `users` | — | `id`, `email`, `role`, `domain`, `status`, `last_active` | `IdentitySvc` |
| Request | `requests` | — | `id`, `submitter_id`, `type`, `title`, `status`, `created_at` | `SubmissionSvc` |
| Brief | `briefs` | `brief_versions` | `id`, `request_id`, `current_version`, `lock_status` (`Editable`/`Submitted`/`LockedForReview`), `content_md` | `SubmissionSvc` |
| PRD Document | `prds` | `prd_versions` | `id`, `request_id`, `current_version`, `status`, `submission_score`, `final_version` | `PRDSvc` |
| Reproduction Steps Doc | `rsds` | `rsd_versions` | `id`, `request_id`, `current_version`, `status` (`Draft`/`InAIReplication`/`ReplicatedByAI`/`ReplicationFailed`/`InManualReplication`/`Reproduced`/`CannotReproduce`/`Triaged`) | `RSDSvc` |
| PRD Evaluation | `prd_evaluations` | — (immutable) | `id`, `prd_id`, `prd_version`, `reviewer_id`, `scores_jsonb`, `decision`, `rationale` | `PRDSvc` |
| Research Session | `research_sessions` | — | `id`, `prd_id`, `mode`, `conversation_jsonb`, `report_jsonb`, `recommendation` | `ResearchSvc` |
| RICE Assessment | `rice_assessments` | `rice_override_history` | `id`, `prd_id`, `agent_results_jsonb` (per-council), `consensus`, `confidence_range`, `manual_override_jsonb` | `RICESvc` |
| Spec Item | `spec_items` | `spec_item_versions` | `id`, `prd_id`, `type`, `title`, `content_rich`, `status`, `ai_confidence`, `dependencies[]` | `SpecSvc` |
| Design Screen | `design_screens` | — (variants are sibling rows) | `id`, `prd_id`, `name`, `linked_prd_section`, `status`, `figma_frame_url` | `DesignSvc` |
| Design Variant | `design_variants` | — | `id`, `design_screen_id`, `style`, `image_url`, `prompt`, `active` | `DesignSvc` |
| Backlog Item | `backlog_items` | — | `id`, `prd_id`/`rsd_id`, `type` (`Feature`/`Bug`), `status`, `rice_score`, `bug_severity_score`, `domain`, `domain_priority` | `BacklogSvc` |
| Domain Priority Flag | `domain_flags` | — | `id`, `backlog_item_id`, `domain`, `ranked_position`, `flagged_at` | `DomainBacklogSvc` |
| Sprint Commitment | `sprint_commitments` | — | `id`, `sprint_id`, `backlog_item_ids[]`, `committed_by`, `committed_at`, `rationale` | `DomainBacklogSvc` |
| Roadmap Item | `roadmap_items` | — | `id`, `backlog_item_id`, `quarter`, `domain`, `start_week`, `end_week`, `status` | `RoadmapSvc` |
| Handover Package | `handover_packages` | — | `id`, `backlog_item_id`, `checklist_jsonb`, `readiness_pct`, `tech_lead_id`, `sent_at` | `HandoverSvc` |
| Sprint Task | `sprint_tasks` | — | `id`, `backlog_item_id`, `sprint_id`, `lead_id`, `progress_pct`, `state` (`OnTrack`/`AtRisk`/`Blocked`) | `DeliverySvc` |
| UAT Run | `uat_runs` | — | `id`, `backlog_item_id`, `tester_id`, `criteria_results_jsonb`, `started_at`, `finished_at` | `UATSvc` |
| Bug Report | `bug_reports` | — | `id`, `uat_run_id`, `title`, `severity`, `description`, `created_rsd_id` | `UATSvc` |
| Release Note | `release_notes` | `release_note_versions` | `id`, `version_label`, `body_md`, `included_prd_ids[]`, `status` (`Draft`/`Scheduled`/`Published`), `audiences[]`, `channels[]` | `ReleaseNotesSvc` |
| Comment / Annotation | `comments` | — | `id`, `entity_type`, `entity_id`, `author_id`, `body`, `anchor_jsonb` (for section-anchored) | universal |
| Notification | `notifications` | — | `id`, `user_id`, `kind`, `payload_jsonb`, `read_at` | `NotificationSvc` |
| Notification Preference | `notification_prefs` | — | `user_id`, `event_type`, `channel`, `enabled`, `digest_schedule` | `NotificationSvc` (v2)* |
| Domain | `domains` | — | `id`, `name`, `color_token`, `owner_id`, `active` | `AdminSvc` |
| LLM Cost Ledger | `llm_cost_entries` | — (append-only) | `id`, `feature`, `agent_code`, `model`, `tokens_in`, `tokens_out`, `cost_cents`, `caller_id`, `entity_ref`, `ts` | `LLMCostSvc` |
| LLM Budget | `llm_budgets` | — | `month`, `budget_cents`, `alert_thresholds_jsonb`, `current_spend_cents` | `LLMCostSvc` |
| Audit Log | `audit_log` | — (append-only) | `id`, `actor`, `action`, `entity_type`, `entity_id`, `before_jsonb`, `after_jsonb`, `ts` | `AuditSvc` |
| Comparison Session | `comparison_sessions` (Redis, TTL 24h) | — | `session_id`, `user_id`, `selected_ids`, `cached_data`, `last_saved` | `DomainBacklogSvc` (ephemeral per OL-6) |

### 3.3 Governance per entity type

| Entity class | Retention | PII? | Audit | Versioned |
|---|---|---|---|---|
| Requests / Briefs / PRDs / RSDs / Specs / Designs | Indefinite (can Archive) | No (business data) | Every mutation | Yes |
| Evaluations / RICE / UAT Runs | Indefinite (immutable after submit) | No | On create/submit only (no mutation allowed) | No (append-only) |
| Backlog / Handover / Sprint tasks | Indefinite | No | Every status change | No |
| Comments / Annotations | Indefinite; soft-delete on user removal | Minimal (author) | On create + edit | Yes (edit history) |
| Users / Notification Prefs | Until user deletion + 30d retention | Yes (email, name) | Sensitive actions only (role changes) | No |
| Release Notes | Indefinite | No | Publish events | Yes |
| LLM Cost Ledger | 7 years (financial audit) | No | Append-only | No |
| Audit Log | 7 years minimum (compliance) | Minimal (actor refs) | N/A (self-referential) | No |
| Comparison Sessions | 24h TTL (Redis) | No | Not audited (ephemeral) | No |

---

## 4. Service Layer

Each service owns a set of entities, exposes an API (REST or GraphQL), emits events, and may consume events from other services.

### 4.1 Service catalog

| Service | Owns | Responsibilities | Calls | Notes |
|---|---|---|---|---|
| `IdentitySvc` | `users`, `sessions`, role definitions | Auth (SSO + MFA), RBAC checks, user directory | `X.IDP` | RLS predicates rely on this |
| `NotificationSvc` | `notifications`, `notification_prefs` | Produce in-app notifications; fan out to channels via `S.NTF` | `S.NTF` | v1 default prefs only; v2 screens per OL-3 |
| `SubmissionSvc` | `requests`, `briefs`, `brief_versions` | Intake + Brief lifecycle; routes by request type | `PRDSvc` / `RSDSvc` | Locks brief on PM review start |
| `PRDSvc` | `prds`, `prd_versions`, `prd_evaluations` | PRD drafting session state, version immutability, Submission Score algo, evaluation queue | `AI.PRD`, `LLMCostSvc`, `AuditSvc` | Score algo per OL-5 is a build task |
| `RSDSvc` | `rsds`, `rsd_versions` | RSD drafting, orchestrate replication flow | `AI.RSD`, `BugReplicationSvc` | See `BugReplicationSvc` for attempt orchestration |
| `BugReplicationSvc` | `replication_attempts` (sub-table of rsds) | Orchestrate AI → human fallback; cost-cap enforcement | `AI.BREP`, `LLMCostSvc` | Mechanism per OL-B2 is TBD |
| `ResearchSvc` | `research_sessions` | Multi-turn research conversations, live report building, source tracking | `AI.RES`, `LLMCostSvc` | Attaches to PRD via `PRDSvc` |
| `RICESvc` | `rice_assessments`, `rice_override_history` | Invoke 3 council agents in parallel; compute consensus + confidence | `AI.RICE.M`, `AI.RICE.T`, `AI.RICE.B`, `LLMCostSvc` | Bugs use different scoring — per OL-B3 |
| `SpecSvc` | `spec_items`, `spec_item_versions` | Generate + edit specs; compute transformation velocity | `AI.SPEC`, `LLMCostSvc` | Dependency graph queryable |
| `DesignSvc` | `design_screens`, `design_variants` | Generate variants; Figma sync | `AI.DSG`, `X.FIGMA`, `LLMCostSvc` | Variants stored as S3 image + prompt |
| `BacklogSvc` | `backlog_items` | Kanban state machine; cross-cutting attributes | `RICESvc` (r/o) | Both Features and Bugs live here |
| `DomainBacklogSvc` | `domain_flags`, `sprint_commitments`, `comparison_sessions` | Domain-scoped views, comparisons (ephemeral), sprint commitments | `BacklogSvc` (r/o) | Comparisons live in Redis (OL-6) |
| `RoadmapSvc` | `roadmap_items` | Gantt layout, resource allocation planning | `BacklogSvc`, `DomainBacklogSvc` (r/o) | Time-axis quarter views |
| `HandoverSvc` | `handover_packages` | Assemble bundles; track readiness completeness | `PRDSvc`, `SpecSvc`, `DesignSvc` (all r/o) | Triggers H6 handoff |
| `DeliverySvc` | `sprint_tasks`, sprints (implicit) | Track progress per task; sprint scope management | `BacklogSvc` (r/o) | Marks items UAT-ready |
| `UATSvc` | `uat_runs`, `bug_reports` | Criteria-level pass/fail tracking; bug submission | `AI.TST`, `LLMCostSvc`, `RSDSvc` (to create RSDs from bugs) | Loops back to Delivery on fail |
| `ReleaseNotesSvc` | `release_notes`, `release_note_versions` | Draft + publish release notes; audience targeting | `AI.RLN`, `LLMCostSvc`, `NotificationSvc` | Publish triggers H9 |
| `AdminSvc` | `domains`, platform settings (v2)* | Org-level config; domain taxonomy | `IdentitySvc` | Most screens v2 per OL-4 |
| `LLMCostSvc` | `llm_cost_entries`, `llm_budgets` | Cost accounting across all AI calls; alerting on thresholds | — | Append-only ledger; required by every AI agent |
| `MetricsSvc` | aggregated time-series (read-only) | Roll up pipeline KPIs for Dashboard + Success Metrics | all Svcs via event subscriptions | Uses `S.AGG` |
| `AuditSvc` | `audit_log` | Immutable audit trail for every mutation | — | Subscribed to all domain events |
| `SearchSvc` | search index (denormalised) | Full-text search + filters across entities | all Svcs via event subscriptions | Maintained reactively from events |
| `SimilaritySvc` | vector embeddings | "Find similar PRDs / bugs / research" | `X.LLM` for embeddings | Used by duplicate detection in `[B05]` and Bug Triage |

### 4.2 API shapes (sketches)

Not exhaustive. Shapes convey patterns; exact signatures TBD.

```
POST   /api/requests                           → Request + Brief v1 created
GET    /api/requests/{id}                      → Request lifecycle view
PATCH  /api/briefs/{id}/submit                 → Brief v → Submitted
POST   /api/briefs/{id}/versions               → Stakeholder forks v(N+1)

POST   /api/prds/{id}/messages                 → Append chat turn, trigger AI.PRD
GET    /api/prds/{id}                          → PRD current state + score
POST   /api/prds/{id}/finalize                 → Mark Final, enqueue for evaluation
POST   /api/prds/{id}/evaluations              → Submit evaluation (immutable)

POST   /api/research-sessions                  → Start; selects PRD + mode
POST   /api/research-sessions/{id}/actions     → Invoke quick-action (Market / Competitor / etc.)
POST   /api/research-sessions/{id}/attach-prd  → Attach report to PRD

POST   /api/rice/{prd_id}/run                  → Invoke 3 council agents in parallel
PATCH  /api/rice/{prd_id}/override             → Manual override with audit

POST   /api/specs                              → Generate spec set from PRD
PATCH  /api/specs/{id}                         → Edit spec
POST   /api/specs/{id}/regenerate              → Per-item regenerate

POST   /api/designs                            → Generate designs from PRD + UI specs
POST   /api/designs/{id}/variants              → Add variant
POST   /api/designs/{id}/push-figma            → Sync to Figma

GET    /api/backlog?domain={d}&status={s}      → Filtered backlog
PATCH  /api/backlog/{id}/status                → Move across Kanban
POST   /api/domain-backlog/{domain}/compare    → Start ephemeral comparison (Redis)
POST   /api/sprint-commitments                 → Persist decision; discards comparison

POST   /api/handover-packages                  → Assemble package
POST   /api/handover-packages/{id}/send        → Trigger handover

PATCH  /api/sprint-tasks/{id}                  → Update progress
POST   /api/sprint-tasks/{id}/ready-for-uat    → Promote

POST   /api/uat-runs                           → Start UAT execution
PATCH  /api/uat-runs/{id}/criteria/{idx}       → Mark Pass/Fail/Blocked/Skipped
POST   /api/uat-runs/{id}/bugs                 → File bug (creates RSD)

POST   /api/release-notes                      → Create draft
POST   /api/release-notes/{id}/generate        → AI.RLN draft content
POST   /api/release-notes/{id}/publish         → Publish, fan out notifications

GET    /api/metrics/pipeline?range={r}         → KPI roll-ups for Dashboard + Success
GET    /api/llm-costs?feature={f}&range={r}    → Cost breakdown for Z01
```

### 4.3 Events (domain event bus)

Events are fire-and-forget; every mutation produces one. Subscribers update their own read models, trigger notifications, refresh search indexes, or emit cascading effects.

| Event | Producer | Key subscribers | Payload gist |
|---|---|---|---|
| `RequestSubmittedEvt` | `SubmissionSvc` | `NotificationSvc`, `SearchSvc`, `MetricsSvc`, `AuditSvc`, `PRDSvc` (if Feature) OR `RSDSvc` (if Bug) | `request_id, type, submitter, title` |
| `BriefLockedEvt` | `SubmissionSvc` | `NotificationSvc` (notify Stakeholder), `AuditSvc` | `brief_id, version, reason: "PRD Review started"` |
| `BriefSupersededEvt` | `SubmissionSvc` | `PRDSvc` (close open reviews), `AuditSvc` | `request_id, old_version, new_version` (per OL-B1) |
| `PRDVersionCreatedEvt` | `PRDSvc` | `SearchSvc`, `AuditSvc` | `prd_id, version, trigger (AI/User edit)` |
| `SubmissionScoreUpdatedEvt` | `PRDSvc` | `NotificationSvc` (at thresholds), `MetricsSvc` | `prd_id, score, delta` |
| `PRDMarkedFinalEvt` | `PRDSvc` | `NotificationSvc`, `SearchSvc`, `PRDEvaluationQueueView` | `prd_id, version, score` |
| `PRDEvaluatedEvt` | `PRDSvc` | `NotificationSvc` (to submitter, PM), `BacklogSvc` (on Approve), `AuditSvc` | `prd_id, reviewer_id, decision, rationale` |
| `ResearchSessionCompletedEvt` | `ResearchSvc` | `NotificationSvc`, `SimilaritySvc` (embed report) | `session_id, prd_id, recommendation` |
| `RICEScoredEvt` | `RICESvc` | `BacklogSvc` (update score), `MetricsSvc` | `prd_id, consensus, confidence_range` |
| `SpecItemStatusChangedEvt` | `SpecSvc` | `HandoverSvc` (refresh readiness), `SearchSvc` | `spec_id, new_status` |
| `DesignApprovedEvt` | `DesignSvc` | `HandoverSvc`, `NotificationSvc` | `design_id, prd_id, variant_id` |
| `BacklogItemCreatedEvt` | `BacklogSvc` | `SearchSvc`, `DomainBacklogSvc` (route to domain) | `item_id, type, prd_id?, rsd_id?, domain` |
| `BacklogItemStatusChangedEvt` | `BacklogSvc` | `MetricsSvc`, `NotificationSvc`, `DeliverySvc` (if enters In Dev) | `item_id, new_status` |
| `SprintCommittedEvt` | `DomainBacklogSvc` | `RoadmapSvc`, `NotificationSvc`, `AuditSvc` | `sprint_id, item_ids[], rationale` |
| `HandoverSentEvt` | `HandoverSvc` | `NotificationSvc`, `DeliverySvc` | `package_id, backlog_item_id, tech_lead_id` |
| `SprintTaskProgressEvt` | `DeliverySvc` | `MetricsSvc` | `task_id, progress, state` |
| `UATRunCompletedEvt` | `UATSvc` | `DeliverySvc`, `ReleaseNotesSvc` (eligible for release), `BacklogSvc` | `run_id, backlog_item_id, all_pass` |
| `BugReportFiledEvt` | `UATSvc` | `RSDSvc` (create RSD), `NotificationSvc` | `bug_id, rsd_id, uat_run_id` |
| `BugReplicationResultEvt` | `BugReplicationSvc` | `RSDSvc` (update status), `NotificationSvc`, `LLMCostSvc` (already has entry, this is meta) | `rsd_id, result: "AI"/"Failed", evidence_refs[]` |
| `ReleasePublishedEvt` | `ReleaseNotesSvc` | `NotificationSvc` (fan out to every Stakeholder of included Requests), `MetricsSvc` | `release_id, version, prd_ids[], channels[], audiences[]` |
| `LLMInvocationEvt` | every AI agent (via `LLMCostSvc`) | `LLMCostSvc` (write entry), `AuditSvc`, budget alerts | `agent_code, feature, tokens_in, tokens_out, cost_cents, entity_ref` |
| `LLMBudgetThresholdEvt` | `LLMCostSvc` | `NotificationSvc` (admin alert), `AuditSvc` | `threshold_pct, current_spend, budget` |
| `AuditEntryWrittenEvt` | `AuditSvc` | — (terminal; optionally exports to SIEM) | full entry |

---

## 5. Component Catalog (reusable primitives)

Every screen is an assembly of these primitives. Documenting them once here lets §6 stay compact — per-screen tables just reference the primitive type plus any overrides.

Each catalog entry uses a compact form:
- **Purpose** — what it is
- **Data in** — what it reads
- **Data out / writes** — what actions it emits
- **Editable by** — RBAC
- **Cross-refs** — which other components couple to it

### 5.1 Chrome primitives

- **Sidebar Navigation.** Purpose: top-level nav. Data in: current route, `IdentitySvc` for role-gated items. Writes: nothing (link-only). Editable: static per role. Cross-refs: every screen.
- **Top App Bar.** Purpose: page breadcrumbs + quick search + notifications bell + user menu. Data in: route, `NotificationSvc` for unread count, `IdentitySvc` for avatar. Writes: navigation. Cross-refs: every screen.
- **Breadcrumb.** Purpose: parent-path nav. Data in: route hierarchy. Writes: nav.
- **Global Search.** Purpose: universal search. Data in: `SearchSvc`. Writes: query events (to `MetricsSvc` for query analytics).
- **Notifications Bell + Popover.** Purpose: unread count + recent list. Data in: `NotificationSvc` (user-scoped). Writes: `markRead`.
- **User Menu Avatar.** Purpose: user identity + logout. Data in: `IdentitySvc`. Writes: logout event.
- **Page Header Card.** Purpose: page title + key meta + primary CTA. Varies per screen.

### 5.2 Stat / KPI primitives

- **Stat Card.** Purpose: one number + label + trend. Data in: `MetricsSvc` query. Writes: nothing. Editable by: —. Cross-refs: Dashboard, Success Metrics, LLM Costs.
- **Sparkline Mini-chart.** Purpose: compact trend. Data in: time-series query (last N periods). Cross-refs: Stat Card.
- **Trend Badge.** Purpose: delta indicator (↑12.5% / ↓15%). Data in: pre-computed delta.
- **Progress Bar.** Purpose: completion vs. target. Data in: pair of numbers.
- **Circle Badge.** Purpose: metric in a circle (e.g., RICE dimensions). Data in: scalar + threshold config.
- **Radar Chart.** Purpose: multi-dimensional comparison. Data in: array of dimensions + values. Cross-refs: `[C02]`.
- **Gauge / Donut.** Purpose: % completion. Data in: scalar. Cross-refs: `[D04]`, `[Z01]`.

### 5.3 List / table primitives

- **Data Table.** Purpose: tabular view with sortable columns. Data in: paginated query with filter/sort. Writes: sort/filter → URL state. Cross-refs: `[B05]`, `[E01]`, `[Z01]` breakdown.
- **Row with Action Menu.** Purpose: table row with 3-dot menu for contextual actions. Writes: action events.
- **Checkbox Column + Bulk Actions Bar.** Purpose: multi-select. Writes: bulk action event.
- **Filter Bar.** Purpose: typed filters (dropdowns, date ranges, search). Writes: filter query state.
- **Pagination.** Purpose: page navigation. Writes: offset query state.

### 5.4 Card / content primitives

- **Content Card.** Purpose: bounded surface with title + body. Varies.
- **Bento Grid.** Purpose: asymmetric card grid (A02 Dashboard). Data in: multiple MetricsSvc queries.
- **Feature Card (hover + CTA).** Purpose: link target with hero content.
- **Status Banner.** Purpose: info/warn/error callout.
- **Activity Timeline.** Purpose: vertical list of events. Data in: `audit_log` filtered by entity_id. Editable: —.
- **Comment Thread.** Purpose: threaded discussion anchored to entity/section. Data in: `comments` table. Writes: new comment / edit / delete (soft).

### 5.5 Form primitives

- **Text Input.** Purpose: single-line text. Writes: on blur / submit.
- **Textarea.** Purpose: multi-line text.
- **Rich Text Editor.** Purpose: formatted content (bold, lists, links, images). Data in/out: HTML or Markdown.
- **Dropdown / Select.** Purpose: single choice.
- **Multi-select with Tags.** Purpose: N choices. Writes: array.
- **Radio Group.** Purpose: mutually exclusive single choice.
- **Toggle Switch.** Purpose: binary.
- **Slider.** Purpose: numeric range.
- **File Upload (Dropzone).** Purpose: one or many file upload. Data out: S3 object refs (via signed upload URL).
- **Star Rating.** Purpose: 1–5 rating. Writes: integer.
- **Type-select Cards (B01).** Purpose: radio-equivalent styled as cards.

### 5.6 Status / identity primitives

- **Status Pill.** Purpose: coloured badge (emerald/amber/red/slate/blue/purple). Data in: enum value + colour mapping. Used everywhere.
- **Version Badge.** Purpose: "v3", "v9 Final". Data in: integer version + final flag.
- **Domain Pill.** Purpose: coloured domain chip. Data in: `domains` table for colour token.
- **Priority Star.** Purpose: Domain Priority flag. Data in: `domain_flags` boolean.
- **Severity Badge.** Purpose: Bug severity (Low/Med/High/Critical). Colour-coded.
- **Request Type Tag.** Purpose: New Idea / Change Request / Bug.
- **Avatar.** Purpose: user image circle. Data in: `IdentitySvc`.
- **Avatar Stack.** Purpose: overlapping avatars for multi-assignee.

### 5.7 AI-specific primitives

- **AI Chat Panel.** Purpose: conversational interface with an agent. Data in: conversation state. Writes: new turns → agent invocation → `LLMCostSvc` + `AuditSvc`. Cross-refs: `[B02]`, `[C01]`, `[C03]`, `[E02]`, Bug Workspace (TBD).
- **AI Quick-Action Chips.** Purpose: pre-shaped prompts as buttons (e.g., "Market Analysis" in C01). Writes: structured prompt invocations.
- **AI Suggestion Card.** Purpose: agent-produced recommendation with confidence %. Data in: agent output.
- **RICE Agent Card.** Purpose: one council agent's R/I/C/E + commentary. Data in: `rice_assessments` jsonb.
- **AI Confidence Badge.** Purpose: Spec Definition-of-Ready signal. Data in: `spec_items.ai_confidence`.
- **Submission Score Gauge.** Purpose: 0–100 readiness gauge. Data in: `prds.submission_score` (live).
- **AI Generating Indicator.** Purpose: "Generating…" with spinner. Data in: streaming state from agent.
- **Auto-Generate CTA.** Purpose: one-click agent invocation (e.g., "Auto-Generate from PRDs" in E03). Writes: agent invocation.
- **Transformation Velocity Bar.** Purpose: accuracy-to-PRD %. Data in: `SpecSvc` computed metric.

### 5.8 Document / artifact primitives

- **Document Viewer (5-tab).** Purpose: render PRD in MD/HTML/Slides/PDF/Images. Data in: `prds` + rendered assets (S3). Cross-refs: `[B04]`.
- **TOC Sidebar.** Purpose: auto-generated from headings. Data in: document structure.
- **Version History Drawer.** Purpose: list + diff versions. Data in: `prd_versions`. Writes: view event.
- **Diff View.** Purpose: side-by-side version compare. Data in: two version snapshots.
- **Annotation Popover.** Purpose: section-anchored comment. Data in/out: `comments` with anchor.
- **Export Dropdown.** Purpose: download in .md/.html/.pdf/.pptx/.docx. Writes: export job; download event.
- **Slide Carousel.** Purpose: paginated slide preview. Data in: rendered slides.
- **Image Gallery / Lightbox.** Purpose: visual browse. Data in: S3 refs.

### 5.9 Workflow-specific primitives

- **Lifecycle Pipeline (horizontal stepper).** Purpose: show artifact progress across stages. Data in: `requests.status`. Cross-refs: `[B03]`.
- **Kanban Column + Card.** Purpose: status-based swimlane. Data in: `backlog_items` grouped by status. Writes: drag → `BacklogSvc.updateStatus`. Cross-refs: `[D01]`.
- **Comparison Overlay.** Purpose: side-by-side across dimensions. Data in: Redis-cached `comparison_sessions` (ephemeral). Cross-refs: `[D02]`.
- **Gantt Bar / Row.** Purpose: time-axis initiative marker. Data in: `roadmap_items`. Cross-refs: `[D03]`.
- **Handover Checklist.** Purpose: artifact readiness tracker. Data in: `handover_packages.checklist_jsonb`. Cross-refs: `[D04]`.
- **Sprint Row (delivery table).** Purpose: initiative-level delivery state. Data in: `sprint_tasks`. Cross-refs: `[E01]`.
- **UAT Criterion Row.** Purpose: acceptance-criterion-level pass/fail. Data in: `uat_runs.criteria_results`. Cross-refs: `[E02]`.
- **Bug Report Form.** Purpose: in-UAT bug filing. Writes: `UATSvc.fileBug` → creates Bug Report + RSD.
- **Distribution Picker.** Purpose: channel + audience selection. Data in: `notification_prefs` + audience registry. Cross-refs: `[E03]`.

### 5.10 Admin-specific primitives

- **Budget Gauge.** Purpose: current spend vs. budget. Data in: `llm_budgets`.
- **Per-feature Cost Row.** Purpose: cost breakdown by feature. Data in: `llm_cost_entries` grouped by feature.
- **Model Config Row.** Purpose: per-feature model + max-tokens config. Data in: settings table. Writes: `AdminSvc.updateModelConfig`.
- **Alert Threshold Toggle.** Purpose: enable/disable budget alerts at thresholds. Data in: `llm_budgets.alert_thresholds_jsonb`.
- **Whitelist Tag Input.** Purpose: email domain whitelist. Data in/out: platform settings (v2).
- **Role Assignment Dropdown.** Purpose: change user role. Writes: sensitive action — audit required.

---

## 6. Per-Screen Component Wiring

For each screen, a **components table** with these columns:
- **Component** — primitive type (§5) + local name
- **Data from** — source (entity + service)
- **Generator** — who/what creates the data (actor code)
- **Editor** — who/what can mutate it (actor code)
- **Storage** — tier + table
- **Services / Events** — service calls + events emitted/consumed
- **Connections** — which other screens / components this couples to
- **Governance / Filtering** — retention, audit, index, special handling

Where a component is 100% catalog-standard with no screen-specific variation, the row is compressed.

---

### 6.1 `[A01]` Login

Purpose: entry gate for whitelisted-email users; OIDC/SAML SSO + optional email/password fallback.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Brand panel (hero, trust proof) | Static + optional aggregate ("Trusted by 500+ teams") | `[S]` content config; `MetricsSvc` for count | `[H.AD]` for content copy | Static assets (S3 or bundled) | — | — | Static refresh |
| Email input | User keyboard | `[H]` | `[H]` | Ephemeral form state | `IdentitySvc.beginSignIn` | → dashboard on success | No PII stored until auth; audit failed attempts |
| Password input (fallback) | User keyboard | `[H]` | `[H]` | Ephemeral | `IdentitySvc.password` | — | Rate-limit on failure; audit |
| "Sign in with Google / SSO" CTA | User click → IdP redirect | `[H]` | `[H]` | — | `IdentitySvc` ↔ `X.IDP` | — | Standard OIDC flow |
| Remember-me toggle | User choice | `[H]` | `[H]` | `sessions` (longer TTL) | `IdentitySvc.createSession` | — | Session cookie policy |
| Forgot-password link | Static | — | — | — | `IdentitySvc.requestReset` → SMTP via `S.NTF` | → reset flow | Audit reset requests |
| "Request access" link (not whitelisted) | — | — | — | — | Creates an access-request ticket via `AdminSvc`* | Emails admin | v2 |
| Whitelist-restricted notice | Static | — | — | — | — | — | — |
| Footer: privacy / TOS | Static | — | — | — | — | — | — |

Events emitted: `LoginAttemptedEvt` (success/fail), `SessionStartedEvt`.

---

### 6.2 `[A02]` Dashboard

Purpose: role-aware pipeline overview with KPIs, velocity chart, team capacity, quick CTA.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Welcome banner ("Welcome back, Alex") | `IdentitySvc.getUser` + pipeline summary text | `[S.AGG]` | — | users + aggregated KPIs | `IdentitySvc`, `MetricsSvc.getDashboardSummary` | — | — |
| Stat Card × 6 (Total Submissions, Active PRDs, In Backlog, In Development, Ready for UAT, Released This Quarter) | Each maps to an aggregate query | `[S.AGG]` | — | Time-series (ClickHouse); source entities for exact counts | `MetricsSvc.getPipelineCounts(range)` | Click → filtered list on target screen (e.g., `[D01]` filtered to In Dev) | Cache 5–15m; refresh on relevant events |
| Trend Badge per Stat Card | Derived from period-over-period comparison | `[S.AGG]` | — | Time-series | `MetricsSvc` | — | — |
| "Development Velocity" bar chart | Weekly counts of status transitions | `[S.AGG]` consuming `BacklogItemStatusChangedEvt` | — | Time-series | `MetricsSvc.getVelocity(window)` | — | Rollup job (daily) |
| "Last 30 Days" filter button | User input | `[H]` | `[H]` | Ephemeral (URL / local state) | `MetricsSvc.getVelocity(range)` | — | — |
| Quick Action: "New Product Entry" | User click | `[H]` | `[H]` | — | Routes to `[B01]` | → `[B01]` | Gated by role (not available to `H.EX`) |
| "Team Capacity" widget | Sprint capacity pull | `[S.AGG]` | — | Sprint data | `DeliverySvc.getTeamCapacity(sprint)` | → `[E01]` link | — |
| Avatar stack + "+12" | `IdentitySvc.getActiveTeamMembers` | `[S]` | — | users | `IdentitySvc.listActive` | — | Soft-masking for departed users |
| Notifications bell | Chrome primitive | — | — | — | — | — | — |

Events emitted: `DashboardViewedEvt` (to `MetricsSvc` for engagement stats).

---

### 6.3 `[B01]` Submit Request

Purpose: minimal Stakeholder intake (Title + Brief + optional Attachments + request type).

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Request Type Cards (New Idea / Change Request / Bug) | Static taxonomy | `[S]` config | `[H]` selects | `requests.type` on submit | — | Routes on submit: Idea/Change → `[B02]`; Bug → Bug Workspace (TBD) | Taxonomy owned by `AdminSvc` (v2 may expose editor) |
| Title input (120 char cap) | User | `[H.STK]` | `[H.STK]` until submit | `requests.title` | — | — | Max length enforced server-side |
| Brief textarea ("source of truth") | User | `[H.STK]` | `[H.STK]` until Brief locks | `briefs.content_md` + `brief_versions` | `SubmissionSvc.createBrief` | Feeds `[B02]` left panel; seeds `AI.PRD` or `AI.RSD` | Versioned per OL-1; no PII expected (business content) |
| Attachment Dropzone (PDF/DOCX/PNG ≤10MB) | User | `[H.STK]` | `[H.STK]` until submit | S3 + `attachments` table (ref to entity) | `SubmissionSvc.uploadAttachment` → pre-signed URL | Attached to Request + surfaced in `[B02]` | Virus scan on upload; ACL per request viewers |
| "Saved as v1" + "Status: Request Review" footer indicator | Computed | `[S]` | — | `briefs.lock_status` | — | Mirrors to `[B03]` lifecycle | Visible confirmation of lock (per OL-B8) |
| "Submit & Open PRD Builder" CTA | User click | `[H.STK]` | `[H.STK]` | — | `SubmissionSvc.submitRequest` → `RequestSubmittedEvt`; routes to `[B02]` (Feature) or Bug Workspace (Bug) | `[B02]` / Bug Workspace | Emits event; once submitted, Brief is `Submitted` (locks on review start, not submit) |
| Cancel button | User | `[H]` | `[H]` | Discards ephemeral state | — | Back to `[A02]` | — |
| Info callout ("Brief saved as v1 in PRD Builder") | Static helper text | `[S]` | — | — | — | — | — |

Events emitted: `RequestSubmittedEvt` (payload includes type, routes subsequent service). Duplicate detection: `SimilaritySvc.findSimilarRequests(brief_embedding)` runs async and surfaces in `[B05]` as "possibly duplicate".

---

### 6.4 `[B02]` PRD Builder

Purpose: 3-panel AI-assisted PRD drafting workspace (Brief source-of-truth | PM-BOT · PRD Agent chat | live PRD viewer).

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Breadcrumb: Submissions > SUB-XXXX > PRD Builder | Route + `requests` | `[S]` | — | — | `SubmissionSvc.getRequest` | — | — |
| Submission Score mini-gauge (header) | Live from `PRDSvc` | `[S]` (recomputed on every PRD change) | — | `prds.submission_score` (authoritative) + Redis live cache | `PRDSvc.getScore`, subscribes to `SubmissionScoreUpdatedEvt` | — | Algorithm TBD per OL-5; show inputs in tooltip |
| "Save Draft" / "Mark as Final" CTAs | User click | `[H.PM]` | `[H.PM]` | `prds.status` transition | `PRDSvc.finalize` → `PRDMarkedFinalEvt` | `[B05]` (queue entry appears on finalise) | "Mark as Final" gated on Score ≥ threshold (configurable; default 80) per user chat intent |
| **Left panel: Source of Truth** | | | | | | | |
| ↳ Version badge (e.g., "v3") | `briefs.current_version` | `[S]` | — | briefs | `SubmissionSvc.getBrief` | `[B03]` shows same badge | Immutable per version |
| ↳ Title + Brief display (read-only when locked) | `briefs.content_md` | `[H.STK]` | `[H.STK]` if not `LockedForReview` | briefs + versions | — | — | Lock badge visible (OL-B8 requirement) |
| ↳ Submitter avatar + timestamp | `requests.submitter_id` + ts | `[S]` | — | — | `IdentitySvc.getUser`, `requests` | — | — |
| ↳ Attachments list | `attachments` filtered | `[H.STK]` at submit | `[H.PM]` may add more | S3 + `attachments` | `SubmissionSvc.listAttachments` | — | Signed URL delivery |
| ↳ "Version Intelligence" info panel | Static hint | — | — | — | — | — | Plus a nudge to create v2 if Brief needs change |
| **Middle panel: PM-BOT · PRD Agent chat** | | | | | | | |
| ↳ Agent header (PM-BOT sparkle + sub-role label) | Static | — | — | — | — | — | Branding |
| ↳ Chat conversation area | `prds.conversation_jsonb` (append-only per turn) | `[H.PM]` (user msgs) + `[AI.PRD]` (assistant msgs) | — (append-only after commit) | prds | `PRDSvc.appendTurn` → triggers `AI.PRD` → `LLMInvocationEvt` | — | Every turn audited; full convo retained per PRD |
| ↳ Typing / Generating indicator | Streaming state | `[AI.PRD]` (stream) | — | Ephemeral | Streaming over SSE/WS from `PRDSvc` | — | — |
| ↳ Quick-action chips (Regenerate Section / View SpecKit Guide) | Agent-suggested | `[AI.PRD]` | `[H.PM]` activates | — | `PRDSvc.agentAction(type)` | — | — |
| ↳ Composer textarea + send | User | `[H.PM]` | `[H.PM]` | Redis draft then persisted on send | `PRDSvc.appendTurn` | — | — |
| **Right panel: Working Folder / PRD document** | | | | | | | |
| ↳ Version pill (e.g., "v7") + "Updated: Just now" | `prds.current_version` | `[S]` | — | prds | — | — | New version created on non-trivial edits |
| ↳ "% Complete" progress bar | Derived from Submission Score / completeness | `[S]` | — | prds | `PRDSvc.getCompleteness` | — | — |
| ↳ Tabs (Document / Sections / Changelog) | Doc view mode | `[H.PM]` | `[H.PM]` | Ephemeral | — | — | — |
| ↳ Rendered sections (01. Problem Statement, 02. Target Users, …) | `prd_versions.content_snapshot` | `[AI.PRD]` + `[H.PM]` edits | `[H.PM]` | prds + versions | `PRDSvc.renderDocument` | `[B04]` Viewer reads same source | Snapshot per version |
| ↳ Active-generation highlight (animated) | Streaming state for current section | `[AI.PRD]` | — | Ephemeral | — | — | — |
| ↳ Greyed placeholders for future sections | Template | `[S]` config | — | — | — | — | — |
| ↳ Projection ("+8 likely after §4, +12 after §7") | Score model projection | `[S]` (algorithm from OL-5) | — | Computed | `PRDSvc.projectScore` | — | — |

Events emitted: `PRDVersionCreatedEvt` (per non-trivial change), `SubmissionScoreUpdatedEvt` (on every change), `PRDMarkedFinalEvt` (on finalize), `LLMInvocationEvt` (per AI turn).

---

### 6.5 `[B03]` Request Tracking

Purpose: Stakeholder-facing progress page for one Request, showing lifecycle, PRD summary, activity feed, and comments.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Page Header Card (title + badges + submitter meta) | `requests` | `[H.STK]` (title); `[S]` (badges) | `[H.STK]` title only while in Draft | requests | `SubmissionSvc.getRequest` | → `[B04]` via "View Full PRD" | — |
| Status pill ("PRD Review") | `requests.status` | `[S]` | — | — | — | Syncs with Lifecycle Pipeline | — |
| Request Lifecycle Pipeline (7 stepper) | `requests.status` + history | `[S]` | — | `audit_log` filtered for status transitions | `SubmissionSvc.getLifecycle` | All downstream screens | For Bug type, pipeline substitutes RSD / Replication steps per OL-2 |
| Lifecycle current-step callout ("PRD under review by Sarah Chen") | `PRDSvc` assignment + `IdentitySvc` | `[S]` | — | — | `PRDSvc.getAssignedReviewer` | → `[B05]` | — |
| PRD Summary card (TOC + Status badge + Submission Score) | `prds` (current Final version) | `[AI.PRD]` + `[H.PM]` | — (read-only here) | prds | `PRDSvc.getPRDSummary` | → `[B04]` | — |
| TOC list (7 sections with ✓ icons) | Parsed headings | `[S]` | — | Computed | — | — | — |
| View Full PRD / Download PDF / Download DOCX CTAs | User click | `[H.STK]` | — | — | `PRDSvc.exportPDF / exportDOCX` (async job) | → `[B04]` | Signed download URL |
| Activity Timeline | `audit_log` for this request | `[S.AUD]` (consumes events) | — (immutable) | audit_log | `AuditSvc.getEntityTimeline(request_id)` | — | Immutable |
| Subscribe button | Notification prefs per entity | `[H.STK]` | `[H.STK]` | `notification_prefs` (v2) / Stakeholder follows by default | `NotificationSvc.subscribe` | — | Default: submitter auto-subscribed |
| Comment thread + composer | `comments` filtered | `[H.STK]` or `[H.PL]` | authors only | comments | `CommentSvc` (universal primitive) | Mentions trigger notifications | Mention parsing; PII light |
| Share Link button | Generates deep link with auth | `[H.STK]` | — | — | `SubmissionSvc.generateShareLink` | — | Short-lived signed link; audit access |
| Bottom release-notification info banner | Static + user settings | `[S]` | — | — | — | — | — |

Events consumed: `SubmissionScoreUpdatedEvt`, `PRDEvaluatedEvt`, `BacklogItemStatusChangedEvt`, `SprintCommittedEvt`, `ReleasePublishedEvt` — each updates the lifecycle pipeline live.

---

### 6.6 `[B04]` PRD Viewer

Purpose: full-width document viewer for one PRD with 5 format tabs, TOC, annotations, version history.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Breadcrumb | — | — | — | — | — | — | — |
| Title + Status badge ("Approved") | `prds.status` | `[S]` | — | prds | `PRDSvc.getPRD` | — | — |
| Description excerpt | `prds` (Overview section excerpt) | `[AI.PRD]` or `[H.PM]` | — | — | — | — | — |
| Share Link · Print · Export dropdown | Actions | `[H]` | — | — | `PRDSvc.exportAs(format)` | — | Signed URLs; audit exports |
| Tab bar (Markdown / HTML / Slides / PDF / Images) | Rendered assets | `[AI.PRD]` initial gen + nightly refresh | — | S3 (for PDF / PPTX), rendered on-demand for MD / HTML / Slides | `PRDSvc.renderMD`, `renderHTML`, `renderSlides`, `renderPDF`, `renderPPTX` | — | Rendering is deterministic per version |
| TOC Sidebar | Parsed H2/H3 from MD | `[S]` | — | Computed | — | — | — |
| Rendered MD document | `prd_versions.content_snapshot` | `[AI.PRD]` + `[H.PM]` | — | prds | — | — | — |
| Slide Preview carousel | Rendered slides (one per H2) | `[AI.PRD]` auto-split | — | Cached | `PRDSvc.renderSlides` | — | — |
| PDF inline viewer | S3 asset | `[S]` generator job | — | S3 | `PRDSvc.renderPDF` (cached) | — | — |
| Image gallery / lightbox | Embedded images + attachments | `[H.STK]` (attachments), `[AI.PRD]` (embedded) | — | S3 | — | — | — |
| Sticky action rail: Annotate · Version History · Comments | User actions | `[H]` | `[H]` | — | `AnnotationSvc`, `PRDSvc.listVersions`, `CommentSvc` | — | — |
| Annotation popover (section-anchored comment) | `comments` with anchor | `[H]` | author | comments | `CommentSvc.createAnnotation` | Notifies mentioned users | Anchor persisted as section + offset |
| Version History drawer | `prd_versions` list | — | — | versions | `PRDSvc.listVersions` | — | All versions retained |
| Diff view (v(N-1) vs v(N)) | Two snapshots | `[S]` | — | versions | `PRDSvc.diffVersions(a, b)` | — | Rendered as coloured diff |
| Bottom status bar (Author / Modified / Word count / Submission ID) | `prds` meta + computed | `[S]` | — | prds | — | — | — |

Events emitted: `PRDViewedEvt` (to `MetricsSvc`), `AnnotationCreatedEvt`, `ExportGeneratedEvt`.

---

### 6.7 `[B05]` PRD Evaluation

Purpose: reviewer queue + slide-out evaluation panel with 4 criteria stars + decision.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Top tabs (Review Queue / Completed / My Evaluations) | Ephemeral filter | `[H.PL]` | `[H.PL]` | URL state | `PRDSvc.listEvalQueue(filter)` | — | — |
| Top-right actions (Export CSV · Run Auto-Score) | Bulk ops | `[H.PL]` | `[H.PL]` | — | `PRDSvc.exportCSV`, `PRDSvc.runAutoScoreBatch` | — | Audit bulk actions |
| Filter Bar (Domain / Status / Reviewer / Date / Search) | User | `[H.PL]` | `[H.PL]` | URL state | `PRDSvc.listEvalQueue(filter)` | — | — |
| Data Table (8 columns: checkbox, title, ID, domain, submitter, submitted, reviewer, auto-score, status, actions) | `prds` JOIN `users` + domain + latest `prd_evaluations` | `[H.PM]` finalizes → `[AI.PRD]` auto-score → `[H.PL]` evaluates | `[H.PL]` within this screen | prds, users, evaluations | `PRDSvc.listEvalQueue` | Row click → slide-out; Title click → `[B04]` | — |
| Auto-Score cell | Computed at PRD finalize or auto-score batch | `[AI.PRD]` | — | `prds.auto_score` | `PRDSvc.computeAutoScore(prd_id)` | — | Distinct from Submission Score; pre-evaluation quality estimator |
| Bulk Approve action bar | Appears when selection present + all avg auto-score ≥ 4.0 | `[H.PL]` | `[H.PL]` | — | `PRDSvc.bulkApprove(ids)` → multiple `PRDEvaluatedEvt` | → `[C02]` RICE | Audit each approval individually |
| Evaluation slide-out panel (500px right) | | | | | | | |
| ↳ PRD header (title, domain, submitter) | prds + users + domains | — | — | — | — | → "Open Full PRD" → `[B04]` | — |
| ↳ 4 Criteria rows (Completeness / Strategic Alignment / Technical Feasibility / Clarity & Quality) | Stars + per-criterion comment | `[H.PL]` | `[H.PL]` until submit | `prd_evaluations.scores_jsonb` + `score_comments_jsonb` | `PRDSvc.draftEvaluation` (optimistic in Redis) | — | Decision requires all 4 scored |
| ↳ Overall Assessment textarea | User | `[H.PL]` | `[H.PL]` until submit | `prd_evaluations.overall_assessment` | — | — | — |
| ↳ Decision buttons (Approve green / Request Revisions amber / Reject red) | Click | `[H.PL]` | `[H.PL]` | `prd_evaluations.decision` | `PRDSvc.submitEvaluation` → `PRDEvaluatedEvt` | Approve → `[C02]` queue; Revisions → `[B02]` with reviewer comments; Reject → terminates | Rationale mandatory (≥20 chars) |
| ↳ Decision Rationale textarea | User | `[H.PL]` | `[H.PL]` | `prd_evaluations.decision_rationale` | — | — | Immutable on submit |
| ↳ Evaluation History collapsible | Prior evaluations (if resubmission) | — | — | prd_evaluations | `PRDSvc.listEvaluations(prd_id)` | — | Immutable |
| ↳ Submit button | — | `[H.PL]` | `[H.PL]` | — | `PRDSvc.submitEvaluation` | — | Atomic: evaluation row + PRD status update + event emission |

Similarity / Duplicate hint: `SimilaritySvc.findSimilarPRDs(this_id)` may surface a banner if near-duplicates exist (threshold configurable). Surfaced to reduce duplicate review effort.

Events emitted: `PRDEvaluatedEvt`, optional `LLMInvocationEvt` (Auto-Score batch).

---

### 6.8 `[C01]` Research & Analysis

Purpose: AI-assisted research workspace with chat + live report + sources + history.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| PRD selector dropdown | `prds` approved for research | — | `[H.PM]` selects | — | `ResearchSvc.listEligiblePRDs` | Selection loads PRD context for agent | — |
| Research Mode toggle (Quick / Standard / Deep) | User | `[H.PM]` | `[H.PM]` | `research_sessions.mode` | `ResearchSvc.startSession` | Affects cost + depth | Mode caps tokens per session |
| Quick-action chips (Market Analysis / Competitor / Sentiment / Tech Feasibility / Full) | Click | `[H.PM]` | `[H.PM]` | Ephemeral | `ResearchSvc.invokeAction(type)` → `AI.RES` | — | Each action pre-templated |
| Chat conversation | `research_sessions.conversation_jsonb` | `[H.PM]` + `[AI.RES]` | append-only | research_sessions | `ResearchSvc.appendTurn` → `AI.RES` | — | Audit each turn; LLM cost ledger entry |
| Inline source links ("[3 sources]") | Agent output | `[AI.RES]` | — | `research_sessions.sources[]` | `ResearchSvc.getSources` | Click → Sources tab | Source URLs retained; relevance score stored |
| Competitor Comparison inline table | Agent-structured output | `[AI.RES]` | `[H.PM]` can edit | `report_jsonb.competitive_analysis` | — | — | — |
| Sentiment bar with negative/neutral/positive | Agent output | `[AI.RES]` | — | `report_jsonb.user_sentiment` | — | — | — |
| **Right panel: Live Report** | | | | | | | |
| ↳ Exec Summary → Market → Competitive → Sentiment → Feasibility → Risk → **Recommendation** | `report_jsonb` sections | `[AI.RES]` | `[H.PM]` | research_sessions | `ResearchSvc.getReport(session_id)` | — | Versioned by session turns |
| ↳ Priority Recommendation card (Pursue / Defer / Reject + confidence %) | Agent output | `[AI.RES]` | `[H.PM]` override | `report_jsonb.recommendation` | — | Consumed by `[C02]` as context + surfaced in `[D01]` / `[D02]` | Confidence stored with rationale |
| Sources tab | `research_sessions.sources` | `[AI.RES]` | — | research_sessions | — | — | Type-classified (Web / Internal / Survey / Tickets) |
| History tab | Past sessions for this PRD | — | — | research_sessions | `ResearchSvc.listSessions(prd_id)` | — | All retained |
| Action bar (Generate PDF / Attach to PRD / Share / Export MD) | Click | `[H.PM]` | `[H.PM]` | Export asset stored in S3 | `ResearchSvc.exportReport(format)`, `ResearchSvc.attachToPRD` | Attach writes supplementary link to `prds.supplementary_refs[]` | — |

Events emitted: `ResearchSessionCompletedEvt` (on "Attach to PRD"), `LLMInvocationEvt` per turn.

---

### 6.9 `[C02]` RICE Scoring

Purpose: 3 named council agents auto-score R/I/C/E, with aggregate + radar + manual override.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Top bar: PRD title + "PRD Approved" pill | prds + latest evaluation | — | — | prds | `PRDSvc.getPRD` | — | — |
| R/I/C/E circle badges strip (4 values) | Aggregate consensus | `[S]` | — | `rice_assessments.consensus` | `RICESvc.getAssessment(prd_id)` | Radar + override panel | — |
| **Left col: 3 Agent Assessment cards** | | | | | | | |
| ↳ Market Analyst Agent card | Agent output | `[AI.RICE.M]` | — | `rice_assessments.agent_results_jsonb[market]` | `RICESvc.runMarketAgent` | — | Per-agent LLM cost; audit invocation |
| ↳ Technical Feasibility Agent card | Agent output | `[AI.RICE.T]` | — | `rice_assessments.agent_results_jsonb[technical]` | `RICESvc.runTechAgent` | — | — |
| ↳ Business Strategy Agent card | Agent output | `[AI.RICE.B]` | — | `rice_assessments.agent_results_jsonb[business]` | `RICESvc.runBusinessAgent` | — | — |
| Per-agent R/I/C/E badges | From respective agent result | Each agent | — | — | — | — | — |
| Per-agent commentary | Agent output | Each agent | — | — | — | — | — |
| "View full analysis" expand | Click | `[H.PL]` | — | — | — | Opens full agent response | — |
| **Aggregate RICE Score banner** (31.5 / 100) | Weighted consensus | `[S]` | — | `rice_assessments.consensus` | `RICESvc.computeConsensus` | Feeds `[D01]` card badge | Weighting config in `AdminSvc`* |
| Confidence Range bar (78–85%) | Derived | `[S]` | — | `rice_assessments.confidence_range` | — | — | — |
| **Right col: Radar chart** (4 axes) | Aggregate numerics | `[S]` | — | — | — | — | — |
| Compare button | — | `[H.PL]` | — | — | `RICESvc.compareWith(other_prd_id)` | — | Opens comparison view |
| Score History timeline | `rice_override_history` + initial | — | — | history table | `RICESvc.getHistory(prd_id)` | — | Append-only |
| **Manual Override card** | | | | | | | |
| ↳ R/I/C/E numeric inputs | User | `[H.PL]` | `[H.PL]` | Pending save | — | — | — |
| ↳ Audit Note textarea | User | `[H.PL]` | `[H.PL]` | `rice_override_history.audit_note` | — | — | Mandatory on override |
| ↳ "Save Manual Override" CTA | Click | `[H.PL]` | `[H.PL]` | Appends to `rice_override_history`; updates `rice_assessments.manual_override` | `RICESvc.override` → `RICEScoredEvt` (with override flag) | `[D01]` / `[D02]` | Every override audited |

Events emitted: `RICEScoredEvt`, `LLMInvocationEvt` × 3.

---

### 6.10 `[C03]` SpecKit

Purpose: AI-generated engineering specs broken into User Stories + Acceptance Criteria, per spec type.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Breadcrumb + page title ("Smart Notifications Engine" + "Drafting User Stories from PRD v2.4") | prds ref | — | — | prds | — | → `[B04]` | — |
| Status pill ("User Stories Drafted") | `spec_items` aggregate status | `[S]` | — | spec_items | `SpecSvc.getStatus(prd_id)` | — | — |
| "Submit for PM Review" CTA | Bulk action | `[H.PM]` | `[H.PM]` | Updates all Draft → In Review | `SpecSvc.submitSet(prd_id)` → `SpecItemStatusChangedEvt` × N | → `[D04]` Handover checklist | Atomic |
| **Left col: Source PRD** (compact) | prds current Final version | — | — | prds | `PRDSvc.getPRD` (r/o) | → `[B04]` via "View Full" | — |
| **Right col: AI workspace toolbar** | | | | | | | |
| ↳ "Add more detail" action | Click | `[H.PM]` | `[H.PM]` | — | `SpecSvc.requestDetail(story_id)` → `AI.SPEC` | — | — |
| ↳ "Ensure accessibility" action | Click | `[H.PM]` | `[H.PM]` | — | `SpecSvc.enhanceA11y(story_id)` → `AI.SPEC` | — | — |
| ↳ "Generate Acceptance Criteria" action | Click | `[H.PM]` | `[H.PM]` | Updates story | `SpecSvc.generateAC(story_id)` → `AI.SPEC` | — | — |
| **Story cards (US-101, US-102, …)** | | | | | | | |
| ↳ Story ID + Title | Agent-proposed | `[AI.SPEC]` | `[H.PM]` | `spec_items.title` | — | — | Versioned |
| ↳ User-story body ("As a X, I want Y, so that Z") | Agent output | `[AI.SPEC]` | `[H.PM]` | `spec_items.content_rich` | — | — | — |
| ↳ Acceptance Criteria list | Agent output | `[AI.SPEC]` | `[H.PM]` | `spec_items.acceptance_criteria_jsonb` | — | → `[E02]` UAT criteria (pre-populated) | — |
| ↳ Edit / Copy / Delete icons | Click | `[H.PM]` | `[H.PM]` | — | `SpecSvc.editStory`, `SpecSvc.deleteStory` | — | Delete soft (spec_item_versions retains) |
| ↳ Regenerate action | Click | `[H.PM]` | `[H.PM]` | New version | `SpecSvc.regenerate(story_id)` → `AI.SPEC` | — | — |
| ↳ AI Confidence badge (High / Med / Low) | Agent output | `[AI.SPEC]` | — | `spec_items.ai_confidence` | — | Gates "Ready for planning" per OL-7 | Definition-of-Ready signal |
| ↳ Empty-state "Generate More Stories" | — | — | `[H.PM]` | — | `SpecSvc.generateMore(prd_id)` → `AI.SPEC` | — | — |
| Transformation Velocity bar (82% Accurate to PRD) | Derived metric | `[S]` | — | Computed | `SpecSvc.getTransformationVelocity(prd_id)` | — | Algorithm: coverage of PRD sections by specs |
| Compare Versions / Finalize Stories CTAs | Click | `[H.PM]` | `[H.PM]` | — | `SpecSvc.compareVersions`, `SpecSvc.finalize` | — | — |
| Dependency graph view (alternate) | `spec_items.dependencies[]` | `[AI.SPEC]` + `[H.PM]` | — | spec_items | `SpecSvc.getGraph(prd_id)` | — | — |

Events emitted: `SpecItemStatusChangedEvt`, `SpecItemVersionCreatedEvt`, `LLMInvocationEvt` per action.

---

### 6.11 `[C04]` Figma Design Generation

Purpose: AI design variant gallery with style selector + per-screen lightbox + Figma push.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Breadcrumb + page title "Design Generation" + PRD selector | prds ref | — | `[H.PM]` selects | prds | — | → `[B04]` | — |
| View toggle (Gallery / Flow View) | Ephemeral | `[H.PM]` | `[H.PM]` | URL state | — | — | — |
| Push All to Figma CTA | Bulk action | `[H.PM]` | `[H.PM]` | — | `DesignSvc.pushAllToFigma(prd_id)` → `X.FIGMA` | Figma file | Requires Figma token scope |
| Generate Designs CTA | Starts gen job | `[H.PM]` | `[H.PM]` | — | `DesignSvc.generate(prd_id, style, scope)` → `AI.DSG` (async) | — | Long-running; stream progress |
| **Configuration panel** | | | | | | | |
| ↳ Design Style selector (Wireframe / Low-Fi / High-Fi) | User | `[H.PM]` | `[H.PM]` | `design_screens.style` (per gen) | — | — | — |
| ↳ Screens-to-Generate checklist (auto-suggested from UI Component specs) | `spec_items` of type `UIComponent` | `[AI.SPEC]` suggests | `[H.PM]` | — | `DesignSvc.suggestScreens(prd_id)` | — | — |
| **Gallery (3-col grid of screen cards)** | | | | | | | |
| ↳ Screen card (thumbnail + name + PRD section tag + status badge + variant count) | `design_screens` + `design_variants` | `[AI.DSG]` generates | `[H.PM]` renames | design_screens | `DesignSvc.listScreens(prd_id)` | — | Thumbnails in S3 |
| ↳ Status badge (Generating / Draft / Reviewed / Approved / Pushed) | `design_screens.status` | `[S]` on gen; `[H.PM]` on review | `[H.PM]` | — | — | — | Event on each transition |
| ↳ Variant count ("3 variants") | `design_variants` count | `[AI.DSG]` | — | design_variants | — | — | — |
| ↳ Actions (Expand / Compare Variants / Regenerate / Push to Figma / Delete) | Click | `[H.PM]` | `[H.PM]` | — | `DesignSvc.*` | — | Delete soft |
| **Lightbox (full-size preview)** | | | | | | | |
| ↳ Render area + zoom controls | `design_variants.image_url` | `[AI.DSG]` | — | S3 | — | — | — |
| ↳ Variants strip | `design_variants` siblings | `[AI.DSG]` | `[H.PM]` set active | design_variants | — | — | One active per screen |
| ↳ Linked Specs panel | `design_screens.linked_spec_ids` | `[H.PM]` + `[AI.DSG]` | `[H.PM]` | — | `SpecSvc.getByIds` | → `[C03]` | — |
| ↳ Feedback & Comments thread | `comments` scoped to design_screen_id | authors | authors | comments | `CommentSvc` | — | — |
| ↳ Refine & Regenerate textarea + send | User | `[H.PM]` | `[H.PM]` | Creates new variant | `DesignSvc.regenerateWithFeedback` → `AI.DSG` | — | — |
| ↳ Footer actions (Figma / Approve) | Click | `[H.PM]` | `[H.PM]` | — | `DesignSvc.pushToFigma(variant_id)` → `X.FIGMA`, `DesignSvc.approve(variant_id)` → `DesignApprovedEvt` | `[D04]` Handover checklist refresh | — |
| Flow View (alternate) | `design_screens.flow_order` | `[H.PM]` sets via drag | `[H.PM]` | design_screens | `DesignSvc.updateFlowOrder` | — | — |

Events emitted: `DesignVariantCreatedEvt`, `DesignApprovedEvt`, `DesignPushedToFigmaEvt`, `LLMInvocationEvt` per generation.

---

### 6.12 `[D01]` Backlog (Kanban)

Purpose: cross-domain Kanban of all backlog items (Features + Bugs).

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| View toggle (Board / List / Table) | Ephemeral | `[H.PL]` | `[H.PL]` | URL state | `BacklogSvc.listItems(filter, view)` | — | — |
| Search + Filter Bar (Domain / RICE Range / Status / Priority / Type) | User | `[H.PL]` | `[H.PL]` | URL state | — | — | — |
| Compare Selected button | Bulk op | `[H.PL]` | `[H.PL]` | Ephemeral → Redis session | `DomainBacklogSvc.startComparison(ids)` | → Comparison Overlay (like `[D02]`) | — |
| Create Task CTA | Admin-only path | `[H.PL]` | `[H.PL]` | `backlog_items` manual insert | `BacklogSvc.createManual` | — | — |
| **Kanban columns × 5** (New / Under Review / Approved / In Development / Released) | `backlog_items` grouped by status | — | — | backlog_items | `BacklogSvc.listByStatus` | — | — |
| Column header (count pill) | Group count | `[S]` | — | — | — | — | — |
| **Card** (per backlog item) | | | | | | | |
| ↳ Type tag ("Core Engine" / Security / etc.) | `backlog_items.domain` | — | — | — | — | — | — |
| ↳ Title | `backlog_items.title` | `[H.PM]` at PRD | `[H.PM]` | — | — | Click → `[B04]` or RSD viewer | — |
| ↳ Drag handle | UI | `[H.PL]` | `[H.PL]` | `backlog_items.status` update + reorder | `BacklogSvc.moveItem(id, new_status)` → `BacklogItemStatusChangedEvt` | — | Validates allowed transitions |
| ↳ RICE score badge (or Bug Severity for Type=Bug) | `backlog_items.rice_score` OR `bug_severity_score` | `[AI.RICE.*]` or `[AI.BREP]` | `[H.PL]` override | rice_assessments / rsds | `BacklogSvc` | — | — |
| ↳ Assignee avatars | `backlog_items.assignees[]` | `[H.PL]` | `[H.PL]` | — | `IdentitySvc.getUsers` | — | — |
| ↳ Priority flag ("fire" icon) | Derived (top-N by RICE) | `[S]` | — | Computed | — | — | — |
| "+ Add Task" button per column | — | `[H.PL]` | `[H.PL]` | `backlog_items` insert | `BacklogSvc.createManual` | — | — |
| **Slide-out task panel** (right, 380px) | | | | | | | |
| ↳ Status pill | `backlog_items.status` | `[S]` | — | — | — | — | — |
| ↳ Title + Assignee + Role | — | — | — | — | `IdentitySvc` | — | — |
| ↳ RICE Breakdown card (R, I, C, E numerics + aggregate) | `rice_assessments` | `[AI.RICE.*]` | `[H.PL]` via `[C02]` | rice_assessments | `RICESvc.getAssessment` | → `[C02]` via "View Full" | — |
| ↳ Description | `prds` excerpt or `rsds` excerpt | — | — | — | `PRDSvc.getSummary` / `RSDSvc.getSummary` | — | — |
| ↳ Links: View PRD / View Specs / View Research | — | — | — | — | respective services | → `[B04]` / `[C03]` / `[C01]` | — |
| ↳ Activity Timeline | `audit_log` scoped | `[S.AUD]` | — | audit_log | `AuditSvc.getEntityTimeline` | — | — |
| ↳ Footer: Start Development CTA | — | `[H.PL]` | `[H.PL]` | Status transition Approved → In Development | `BacklogSvc.moveItem` | → `[E01]` | — |

Events emitted: `BacklogItemStatusChangedEvt`, `BacklogItemAssignedEvt`.

---

### 6.13 `[D02]` Domain Backlogs

Purpose: domain-scoped view (Payments / Onboarding / Risk / Growth / Platform) with cross-domain summary + comparison panel.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Cross-Domain Summary (5 domain cards with stacked status bars + avg RICE) | `backlog_items` grouped by domain + status | `[S.AGG]` | — | backlog_items (denormalised summary) | `DomainBacklogSvc.getSummary` | — | Refresh on `BacklogItemStatusChangedEvt` |
| Domain tabs (Payments active / Onboarding / …) | `domains` | `[H.AD]` maintains list | `[H.PL]` selects | domains | `AdminSvc.listDomains`, `DomainBacklogSvc.listItems(domain)` | — | — |
| Domain stats strip (Total / Avg RICE / In Dev / Awaiting) | Per-domain aggregates | `[S.AGG]` | — | — | `DomainBacklogSvc.getDomainStats` | — | — |
| View toggle (Ranked List / Board / Table) | Ephemeral | `[H.PL]` | `[H.PL]` | URL state | — | — | — |
| Filter chips (Status / RICE Range / Assignee / Priority) | User | `[H.PL]` | `[H.PL]` | URL state | — | — | — |
| "Compare Selected" button (enabled 2–4) | User selection | `[H.PL]` | `[H.PL]` | Ephemeral → Redis | `DomainBacklogSvc.startComparison(ids)` | Opens Comparison Overlay | — |
| **Ranked List rows** | | | | | | | |
| ↳ Drag handle + rank number | User | `[H.PL]` | `[H.PL]` | `domain_flags.ranked_position` | `DomainBacklogSvc.reorder` | — | — |
| ↳ Checkbox | Selection | `[H.PL]` | `[H.PL]` | Ephemeral | — | — | — |
| ↳ Title + status pill | backlog_items | — | — | — | — | Click → `[D01]` slide-out or direct to artifact | — |
| ↳ Research rec. pill (Pursue / Defer / Reject) | `research_sessions.recommendation` | `[AI.RES]` | `[H.PL]` override via research session | research_sessions | `ResearchSvc.getLatestRec(prd_id)` | — | — |
| ↳ Domain Priority star (filled if flagged) | `domain_flags.flagged_at` | `[H.PL]` | `[H.PL]` | domain_flags | `DomainBacklogSvc.toggleFlag` | Visible in `[D01]` as star | — |
| ↳ RICE circular score | rice_assessments | `[AI.RICE.*]` + override | — | — | — | → `[C02]` | — |
| ↳ Assignee + target quarter | users + `backlog_items.target_quarter` | `[H.PL]` | `[H.PL]` | — | — | — | — |
| ↳ Expand chevron → detail row (desc excerpt, domain notes, quick actions) | backlog + domain_flags.domain_notes | `[H.PL]` (notes) | `[H.PL]` | domain_flags | `DomainBacklogSvc.updateNotes` | View PRD/Specs/Research | Domain notes are domain-scoped, not in `[D01]` |
| **Comparison Panel Overlay** (full width) | | | | | | | |
| ↳ Columns per item (2–4) + dimension rows (RICE Breakdown / Consensus / Research Rec / Evaluation Score / Impact / Effort / Dependencies / Submissions Count) | Joins across rice_assessments, research_sessions, prd_evaluations, backlog_items | `[S]` | — | — | `DomainBacklogSvc.getComparisonData` | — | Comparison itself ephemeral (OL-6) |
| ↳ Winner Highlight row | Per-dim max | `[S]` | — | Computed | — | — | — |
| ↳ Commit To Next Sprint Cycle CTA | Click | `[H.PL]` | `[H.PL]` | `sprint_commitments` insert | `DomainBacklogSvc.commitSprint(sprint_id, items, rationale)` → `SprintCommittedEvt` | → `[E01]` eventually | Audit; this IS the persisted decision (per OL-B5 acknowledgement) |
| ↳ Export Comparison as PDF | Click | `[H.PL]` | — | Export to S3 | `DomainBacklogSvc.exportComparisonPDF` | — | Export audited (ephemeral export, not a stored comparison) |

Events emitted: `DomainPriorityFlaggedEvt`, `SprintCommittedEvt`.

Note on OL-B5: Comparisons themselves are ephemeral, but `SprintCommittedEvt` writes a durable decision record including the rationale text. That's where the "decision audit trail" lives.

---

### 6.14 `[D03]` Quarterly Roadmap

Purpose: time-axis Gantt of initiatives per domain with resource allocation.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Quarter tabs (Q1 … Q4) | Calendar | `[S]` | — | — | `RoadmapSvc.listQuarters` | — | — |
| View toggle (Timeline / Swimlane) | Ephemeral | `[H.PL]` | `[H.PL]` | URL state | — | — | — |
| Export / Add Item buttons | — | `[H.PL]` | `[H.PL]` | `roadmap_items` insert | `RoadmapSvc.createItem`, `RoadmapSvc.export` | — | Export audited |
| Timeline header (months + weeks) | Calendar | `[S]` | — | — | — | — | — |
| TODAY indicator line | Computed | `[S]` | — | — | — | — | — |
| **Domain rows** × 5 | `domains` | — | — | — | `AdminSvc.listDomains` | — | — |
| **Initiative bars** (per row) | `roadmap_items` JOIN `backlog_items` | `[H.PL]` drags/creates | `[H.PL]` | roadmap_items | `RoadmapSvc.listItems(quarter)` | → backlog item detail | Drag changes persist |
| ↳ Bar style (Completed solid / In Progress hatched / Planned faded) | Status | `[S]` | — | `backlog_items.status` mirrored | — | — | — |
| ↳ RICE badge on bar | `backlog_items.rice_score` | — | — | — | — | — | — |
| ↳ Dependency arrow (dashed) | `roadmap_items.depends_on[]` | `[H.PL]` | `[H.PL]` | roadmap_items | — | — | — |
| **Monthly Resource Allocation chart** (Dev / QA / Product) | Sprint capacity aggregates | `[S.AGG]` | — | — | `DeliverySvc.getCapacityByMonth` | → `[E01]` | — |
| Strategic Capacity panel (Headcount 24/28, Budget $420k/$600k) | Settings + sprints | `[H.AD]` config | `[H.AD]` | settings + derived | `AdminSvc.getCapacity`, `DeliverySvc.getUtilization` | — | — |
| Strategic Note callout ("Velocity +12% due to new CI/CD") | Free-text note | `[H.PL]` | `[H.PL]` | roadmap_notes | `RoadmapSvc.updateNotes(quarter)` | — | — |
| Collapsible Roadmap Notes (Objectives / Resource Shifting) | Free-form | `[H.PL]` | `[H.PL]` | roadmap_notes | — | — | — |

Events emitted: `RoadmapItemScheduledEvt`, `RoadmapItemMovedEvt`.

---

### 6.15 `[D04]` Tech Handover Package

Purpose: assemble bundle from PRD + Specs + Designs + Integration Docs + APIs + Acceptance; track readiness.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Breadcrumb + title + "Ready for Handover" pill | `handover_packages.readiness_pct` + status | `[S]` | — | handover_packages | `HandoverSvc.getPackage(backlog_id)` | — | — |
| Download All as ZIP CTA | Click | `[H.PM]` | — | Export to S3 | `HandoverSvc.exportZip` | — | Export audited |
| **Section: PRD Document** | `prds` Final | `[AI.PRD]` + `[H.PM]` | — (read-only) | prds | `PRDSvc.getFinal` | → `[B04]` | — |
| **Section: Speckit Specifications** | `spec_items` Approved | `[AI.SPEC]` + `[H.PM]` | — | spec_items | `SpecSvc.listApproved(prd_id)` | → `[C03]` | — |
| ↳ Spec chip grid (per item title + DRAFTED/APPROVED badge) | — | — | — | — | — | — | — |
| **Section: Figma Designs** | `design_screens` Approved | `[AI.DSG]` + `[H.PM]` | — | design_screens | `DesignSvc.listApproved(prd_id)` | → `[C04]` | — |
| ↳ Thumbnail grid (4 screens with hover overlay) | S3 thumbnails | — | — | S3 | — | — | Signed URLs |
| **Section: 3rd Party Integration Docs** (amber warning if incomplete) | `handover_packages.integration_docs[]` | `[H.PM]` uploads | `[H.PM]` | S3 + refs in handover_packages | `HandoverSvc.uploadIntegrationDoc` | — | Virus scan; retention |
| ↳ Per-doc row (filename + check/missing + upload action) | — | — | — | — | — | — | — |
| **Section: API Contracts** | OpenAPI spec asset | `[H.EL]` or `[H.PM]` | editors | S3 | `HandoverSvc.getAPIContract` | — | Version-pinned per handover |
| **Section: Acceptance Criteria** | Aggregated from `spec_items.acceptance_criteria_jsonb` | `[AI.SPEC]` + `[H.PM]` | — | — | `SpecSvc.aggregateAC(prd_id)` | → `[E02]` (pre-populates UAT run) | — |
| **Right sidebar: Handover Readiness** | | | | | | | |
| ↳ 83% donut | `handover_packages.readiness_pct` | `[S]` | — | — | `HandoverSvc.computeReadiness` | — | — |
| ↳ Done / Outstanding counts | — | `[S]` | — | — | — | — | — |
| ↳ Assign to Engineering dropdown | `teams` | `[H.AD]` | `[H.PM]` selects | `handover_packages.assigned_team` | — | — | — |
| ↳ Tech Lead card (name + role) | `IdentitySvc` lookup | `[H.AD]` assigns team lead | — | — | — | — | — |
| ↳ Send Handover CTA | Click | `[H.PM]` | `[H.PM]` | `handover_packages.sent_at` | `HandoverSvc.send` → `HandoverSentEvt` | `[E01]` eligible | Must be ≥ threshold (configurable, e.g., 90%) |

Events emitted: `HandoverPackageUpdatedEvt`, `HandoverSentEvt`.

---

### 6.16 `[E01]` Delivery

Purpose: sprint-scoped dashboard of initiatives in flight with progress + blockers + UAT readiness.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Top nav tabs (Domain: All / Sprint: Active) | Filters | `[H.EL]` | `[H.EL]` | URL state | `DeliverySvc.listTasks(filter)` | — | — |
| Sprint selector dropdown | `sprints` | `[S]` | `[H.EL]` | sprints | `DeliverySvc.listSprints` | — | — |
| Domain filter dropdown | `domains` | `[H.AD]` | `[H.EL]` | — | — | — | — |
| View toggle (All / On Track / At Risk / Blocked) | Filter | `[H.EL]` | `[H.EL]` | URL state | — | — | — |
| **Metric Summary cards × 4** (In Progress / On Track / At Risk / Blocked) | `sprint_tasks` aggregates | `[S.AGG]` | — | sprint_tasks | `DeliverySvc.getMetrics(sprint)` | Click → filter table | Refresh on `SprintTaskProgressEvt` |
| **Delivery Table** | `sprint_tasks` JOIN `backlog_items` | — | — | sprint_tasks | `DeliverySvc.listTasks(sprint)` | — | — |
| ↳ Item Name (linked) | `backlog_items.title` | — | — | — | — | Click → `[D01]` slide-out or RSD viewer | — |
| ↳ Domain pill | — | — | — | — | — | — | — |
| ↳ Sprint | — | — | — | — | — | — | — |
| ↳ Status pill (On Track / At Risk / Blocked) | `sprint_tasks.state` | `[H.EL]` | `[H.EL]` | sprint_tasks | `DeliverySvc.updateState(task_id, state)` | → `SprintTaskProgressEvt` | Audit each transition |
| ↳ Progress bar (%) | `sprint_tasks.progress_pct` | `[H.EL]` | `[H.EL]` | sprint_tasks | `DeliverySvc.updateProgress` | — | — |
| ↳ Lead avatar + name | `sprint_tasks.lead_id` | `[H.EL]` assigns | `[H.EL]` | — | `IdentitySvc` | — | — |
| ↳ Target date | `sprint_tasks.target_date` | `[H.EL]` | `[H.EL]` | — | — | — | — |
| ↳ Demo toggle | `sprint_tasks.demo_ready` | `[H.EL]` | `[H.EL]` | — | — | — | — |
| ↳ Actions menu | — | `[H.EL]` | `[H.EL]` | — | — | — | — |
| ↳ Expansion row: Commit Log + Critical Blockers + Ready-for-UAT CTA | — | — | — | — | — | — | — |
| **Commit Log timeline** (expansion) | `audit_log` + VCS webhook ingestion | `[S.SYN]` (via VCS webhook) | — | audit_log | `DeliverySvc.getCommits(task_id)` | — | — |
| **Critical Blockers card** | `sprint_tasks.blockers[]` | `[H.EL]` | `[H.EL]` | — | `DeliverySvc.addBlocker` | — | — |
| **"Ready for Demo & UAT" CTA** | Click | `[H.EL]` | `[H.EL]` | Status transition | `DeliverySvc.markUATReady(task_id)` → `BacklogItemStatusChangedEvt` | → `[E02]` (eligible) | Gated by progress ≥ 100% or override |

Events emitted: `SprintTaskProgressEvt`, `SprintTaskBlockerAddedEvt`, `SprintTaskUATReadyEvt`.

---

### 6.17 `[E02]` UAT Testing

Purpose: criterion-level pass/fail execution + AI edge-case proposals + bug filing.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Page header (item title + "UAT In Progress" pill + Started time + ID) | `uat_runs` | `[H.QA]` starts | — | uat_runs | `UATSvc.getRun(run_id)` | — | — |
| Share Report button | — | `[H.QA]` | — | — | `UATSvc.exportReport` | — | — |
| **Execution Progress card** (9 of 14, 7 passed / 2 failed, 64%) | Aggregates of criteria results | `[S]` | — | uat_runs | `UATSvc.getProgress(run_id)` | — | — |
| **Acceptance Criteria list** (rows × N) | `spec_items.acceptance_criteria_jsonb` flattened for this item | `[AI.SPEC]` at spec gen; `[H.PM]` edits | — (pre-pop from specs) | uat_runs.criteria_results_jsonb | `UATSvc.listCriteria(run_id)` | Source from `[C03]` | Per-criterion immutable once set |
| ↳ Pass/Fail/Blocked/Skipped dropdown per row | User | `[H.QA]` | `[H.QA]` until run closed | criteria_results | `UATSvc.updateCriterion(run_id, idx, result)` | — | Audit each change |
| ↳ Photo / screenshot capture button | User | `[H.QA]` | `[H.QA]` | S3 | `UATSvc.attachEvidence` | — | Evidence linked to criterion |
| **Bug Report form (collapsible)** | | | | | | | |
| ↳ Title / Description / Severity | User | `[H.QA]` | `[H.QA]` | bug_reports | `UATSvc.fileBug` → creates RSD via `RSDSvc.createFromBug` | Routes into Stage B-Bug pipeline | Severity gates escalation |
| ↳ Submit Bug CTA | Click | `[H.QA]` | — | — | `UATSvc.fileBug` → `BugReportFiledEvt` | → Bug Workspace (TBD) | — |
| **Right: AI Test Assistant panel** | | | | | | | |
| ↳ Chat with PM-BOT · Test Agent | User + agent | `[AI.TST]` | append-only | uat_runs.ai_conversation_jsonb | `UATSvc.testAgentTurn` → `AI.TST` | — | LLM cost + audit |
| ↳ Edge-case suggestion pills | Agent output | `[AI.TST]` | `[H.QA]` dismisses | — | — | — | — |
| ↳ Spec conflict detection card | Agent detects divergence from spec | `[AI.TST]` | — | — | `SpecSvc.checkConflict(criterion, spec)` | Updates spec draft if accepted | — |
| ↳ "Update spec" CTA | Click | `[H.QA]` | `[H.QA]` | Creates spec item version | `SpecSvc.updateFromUAT` → `SpecItemVersionCreatedEvt` | → `[C03]` | Audit |
| Floating Priority Tray (Recent Executions) | `uat_runs` history for user | — | — | uat_runs | `UATSvc.listRuns(user_id)` | — | — |

Events emitted: `UATCriterionResultEvt`, `BugReportFiledEvt`, `UATRunCompletedEvt`, `LLMInvocationEvt` per agent turn.

---

### 6.18 `[E03]` Release Notes Editor

Purpose: compose release notes with AI drafting, audience targeting, channel selection, scheduling.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Release version selector (v2.4.0 — April 2026) | `release_notes` | `[H.PM]` | `[H.PM]` | release_notes | `ReleaseNotesSvc.listReleases` | — | — |
| Auto-Generate from PRDs CTA | Click | `[H.PM]` | — | — | `ReleaseNotesSvc.autoGenerate(release_id, prd_ids)` → `AI.RLN` | — | LLM cost |
| Preview button | Click | `[H.PM]` | — | — | `ReleaseNotesSvc.preview(release_id)` | — | — |
| Publish button | Click | `[H.PM]` | `[H.PM]` | Status → Published | `ReleaseNotesSvc.publish` → `ReleasePublishedEvt` | Stakeholders of included PRDs via `NotificationSvc` | Atomic; audit |
| Save Draft button | Click | `[H.PM]` | `[H.PM]` | — | `ReleaseNotesSvc.saveDraft` | — | — |
| **Rich-Text Editor** with toolbar (B, I, H1, H2, list, link, image) | `release_notes.body_md` (or richer) | `[AI.RLN]` + `[H.PM]` | `[H.PM]` | release_notes + S3 for images | `ReleaseNotesSvc.updateBody` | — | Versioned on save |
| **Sections** (New Features / Improvements / Bug Fixes / Known Issues) with PRD-ID tags | Parsed from body + `release_notes.included_prd_ids[]` | `[AI.RLN]` | `[H.PM]` | — | `ReleaseNotesSvc.parseSections` | Links back to `[B04]` | — |
| **Right sidebar: Audience** | `release_notes.audiences[]` | `[H.PM]` | `[H.PM]` | — | — | — | — |
| ↳ Checkboxes (Internal / External / Engineering) | User | `[H.PM]` | `[H.PM]` | — | — | — | — |
| **Right sidebar: Distribution Channels** | `release_notes.channels[]` | `[H.PM]` | `[H.PM]` | — | `NotificationSvc.supportedChannels` | — | — |
| ↳ Channel tiles (Email / Slack / In-App / Confluence) | User | `[H.PM]` | `[H.PM]` | — | — | — | — |
| **Included PRD Items** picker | `prds` eligible for release | `[H.PM]` | `[H.PM]` | release_notes.included_prd_ids | `ReleaseNotesSvc.listEligiblePRDs` | — | — |
| **Schedule** date + time inputs | User | `[H.PM]` | `[H.PM]` | release_notes.scheduled_at | — | Triggers `S.SCHED` at release time | — |
| Auto-Generate button (sidebar shortcut) | Click | `[H.PM]` | — | — | `ReleaseNotesSvc.autoGenerate` | — | — |

Events emitted: `ReleaseNoteDraftedEvt`, `ReleaseNoteScheduledEvt`, `ReleasePublishedEvt`, `LLMInvocationEvt` per generation.

---

### 6.19 `[E04]` Success Metrics

Purpose: executive-facing KPIs + pipeline funnel + domain distribution + top releases + RICE accuracy.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| Date Range filter (Last 30 / 60 / 90 / Custom) | User | `[H.EX]` | `[H.EX]` | URL state | `MetricsSvc.setRange` | — | — |
| Domain filter | User | `[H.EX]` | `[H.EX]` | URL state | `MetricsSvc.setDomain` | — | — |
| **KPI Cards × 4** (Ideas Submitted / PRDs Generated / Avg Time to Ship / Release Adoption) | Time-series aggregates | `[S.AGG]` | — | Time-series | `MetricsSvc.getKPIs(range)` | — | Cached 15m |
| Per-card sparkline | Trend series | `[S.AGG]` | — | Time-series | — | — | — |
| **Submissions to Release Pipeline chart** | Funnel counts per stage over time | `[S.AGG]` consuming `BacklogItemStatusChangedEvt` | — | Time-series | `MetricsSvc.getFunnel(range)` | — | — |
| **Domain Distribution chart** | `backlog_items` grouped by domain | `[S.AGG]` | — | — | `MetricsSvc.getDomainDistribution(range)` | — | — |
| **Top Performing Releases table** | `release_notes` + adoption/satisfaction metrics | `[S.AGG]` + `NotificationSvc` (for adoption signals) | — | aggregations | `MetricsSvc.getTopReleases(range)` | — | Adoption: requires opening rate / feature uptake hooks |
| **RICE Score Accuracy scatter plot** (R² = 0.84) | Predicted RICE (at scoring time) vs. Actual Impact (measured post-release) | `[S.AGG]` comparing `rice_assessments.consensus` with post-release metrics | — | — | `MetricsSvc.getRICEAccuracy(range)` | — | Actual Impact definition per metric; may be feedback loop for calibrating `AI.RICE.*` |
| Generate Report link | Click | `[H.EX]` | — | S3 | `MetricsSvc.exportReport(format)` | — | Audit exports |
| Email Stakeholders CTA | Bulk notify | `[H.EX]` | — | — | `NotificationSvc.broadcast` | — | Audit |

Events emitted: — (mostly read-only; some `ReportExportedEvt`, `BroadcastSentEvt`).

---

### 6.20 `[Z01]` LLM Usage & Costs

Purpose: admin view of LLM API spend, per-feature configuration, alert thresholds, cost breakdown.

| Component | Data from | Generator | Editor | Storage | Services / Events | Connections | Governance |
|---|---|---|---|---|---|---|---|
| **Stat cards × 3** (Monthly Spend / Total API Calls / Avg Cost per PRD) | `llm_cost_entries` aggregates | `[S.AGG]` | — | llm_cost_entries | `LLMCostSvc.getMonthlyStats` | — | 7-year retention for financial audit |
| Monthly Spend budget bar | `llm_budgets.current_spend_cents` vs. `budget_cents` | `[S.AGG]` | — | llm_budgets | `LLMCostSvc.getBudget(month)` | — | — |
| **Daily LLM Spend chart** (30-day bar chart with budget threshold line) | Time-series of daily spend | `[S.AGG]` consuming `LLMInvocationEvt` | — | Time-series | `LLMCostSvc.getDailySpend(range)` | — | — |
| **Model Configuration card** | `model_configs` | `[H.AD]` | `[H.AD]` | platform settings | `AdminSvc.getModelConfig(feature)`, `AdminSvc.updateModelConfig` | — | Change audited; gates which models each agent invokes |
| ↳ Per-feature dropdown (PRD Generator / Research Bot / …) | Feature list | `[S]` config | `[H.AD]` | — | — | — | — |
| ↳ Max-tokens slider | User | `[H.AD]` | `[H.AD]` | — | — | Affects per-invocation cost cap | — |
| ↳ Save Configurations CTA | Click | `[H.AD]` | — | — | `AdminSvc.saveModelConfig` → `ModelConfigUpdatedEvt` | All agents reload on event | Audit |
| **Cost Alerts card** | `llm_budgets.alert_thresholds_jsonb` | `[H.AD]` | `[H.AD]` | llm_budgets | `LLMCostSvc.setThreshold(pct, recipients)` | `LLMBudgetThresholdEvt` → `NotificationSvc` | — |
| ↳ Per-threshold toggle (50% / 75% / 90%) | User | `[H.AD]` | `[H.AD]` | — | — | — | — |
| **Cost & Usage Breakdown table** | `llm_cost_entries` grouped by feature | `[S.AGG]` | — | — | `LLMCostSvc.breakdownByFeature(range)` | — | — |
| ↳ Per-feature rows (PRD Generator / RICE / UAT / Research) with API calls, tokens, cost, latency, sparkline | — | — | — | — | — | — | — |
| Greyed-out tabs (Manage Users / Platform Settings) | v2 placeholders (OL-4) | — | — | — | — | — | Not implemented v1 |

Events emitted: `ModelConfigUpdatedEvt`, `LLMBudgetThresholdEvt`.

---

### 6.21 Bug pipeline screens (TBD; specifications from OL-2 resolution + §6.4/§6.17 patterns)

Three screens specified here in outline since they don't exist yet. Generation prompts are in `_HANDOFF_CLAUDE_DESIGN/Regeneration_Prompts.md` §2.

**Bug Workspace** (analog of `[B02]` for Type=Bug):
- Left: Bug Brief (read-only once locked) + Attachments + "Environment" expanded
- Middle: `AI.RSD` chat drafting RSD
- Right: Live RSD document with sections (Environment / Expected / Actual / Repro Steps / Severity)
- Header action: "Mark for AI Replication" triggers `AI.BREP`
- Data: `rsds`, `brief`, `AI.RSD` conversation
- Services: `RSDSvc`, `BugReplicationSvc`, `LLMCostSvc`, `AuditSvc`

**Bug Replication Result** (intermediate state):
- Two visual states (Replicated by AI / Replication Failed)
- Evidence section pulling from S3 (screenshots, videos, logs)
- "Continue to Triage" or "Hand to QA for Manual Replication" CTAs
- Data: `rsds.replication_attempts`, S3 evidence refs
- Services: `BugReplicationSvc`, `RSDSvc`

**Manual Bug Replication** (analog of `[E02]` for human replication fallback):
- Left: RSD reference + AI attempt log + Replication Outcome radio + Findings rich text + Evidence upload
- Right: `AI.TST` chat (shared with UAT) for diagnostic suggestions
- CTAs: "Update RSD" and "Submit & Triage"
- Submit → `BacklogSvc.createManual(type=Bug)` with bug severity score
- Data: `rsds`, `bug_reports`
- Services: `RSDSvc`, `BugReplicationSvc`, `UATSvc` (shared agent), `AI.TST`

**Bug Triage Queue** (analog of `[B05]` for bug inbox):
- Table of bugs with severity, AI replication result, status
- Right slide-out with Promote to Backlog / Reassign / Close as Cannot Reproduce CTAs
- Data: `rsds`, `bug_reports`, `backlog_items` (Type=Bug rows)
- Services: `RSDSvc`, `BacklogSvc`

---

### 6.22 v2 screens (OL-3, OL-4 — placeholders only in v1)

**Notification Settings** (per user):
- Toggles per event type × channel (Email/In-App/Slack/SMS)
- Digest schedule selector (Real-time / Daily 9am / Weekly Monday)
- Data: `notification_prefs`
- Services: `NotificationSvc`

**Manage Users** (admin):
- Users table + role assignment + email whitelist manager
- Data: `users`, whitelist config
- Services: `IdentitySvc`, `AdminSvc`

**Platform Settings** (admin):
- Org / Branding / SSO / Default LLM Models / Integrations / Feature Flags sections
- Data: platform settings table
- Services: `AdminSvc`

---

## 7. Cross-cutting concerns

Every component inherits these.

### 7.1 Authentication & Authorization
- All API calls require a valid session from `IdentitySvc`
- RBAC gates per-screen and per-action (e.g., `[B05]` requires `PRODUCT_LEAD` or `DOMAIN_OWNER`; `[Z01]` requires `ADMIN`)
- Row-Level Security (Postgres RLS) enforces domain isolation — Domain Owners only see their domain's backlog items unless their role grants cross-domain read
- Sensitive actions (role changes, budget edits, large exports) require a fresh MFA challenge within the session

### 7.2 Audit logging
- `AuditSvc` subscribes to every domain event and writes an immutable entry
- Every mutation surfaces in relevant Activity Timelines (scoped per entity)
- 7-year retention; SIEM export optional
- Every AI agent invocation produces one LLM cost entry + one audit entry (paired)

### 7.3 Versioning
- Brief, PRD, RSD, Spec Items, Release Notes are first-class versioned artifacts with immutable snapshot per version
- Version badges visible in UI (canonical primitive — see §5.6)
- Diff views available at `[B04]` and analogously for Spec Items
- Version transitions are events; subscribers (search index, audit) react

### 7.4 Notifications
- v1: default channels (email + in-app) enabled for every user
- v2: per-event × per-channel preferences via Notification Settings screen (OL-3)
- Mentioned users in comments receive a targeted notification
- Release publishes fan out to every Stakeholder of every included Request

### 7.5 LLM cost accounting
- Every AI agent call is wrapped in `LLMCostSvc` → writes to `llm_cost_entries` + emits `LLMInvocationEvt`
- Budgets per month; thresholds at 50/75/90% emit `LLMBudgetThresholdEvt` → admin notifications
- Model config per feature allows cost optimisation (use smaller model for high-volume low-complexity, e.g., RICE scoring)

### 7.6 Filtering & search
- `SearchSvc` maintains denormalised indices for: PRDs (by title, body, tags), Specs (by title, type), Backlog Items (by title, domain, status, type), Research reports (by content, sources), Bug Reports (by title, severity)
- Every search query logged to `MetricsSvc` for query analytics
- Filters on every list screen: domain, status, assignee, date range, type, severity (for bugs), RICE range
- `SimilaritySvc` produces vector embeddings to support:
  - Duplicate detection on `[B05]` PRD Evaluation ("this looks like PRD-035")
  - Duplicate Bug detection on Bug Triage ("this looks like BUG-0042")
  - Related Research suggestions on `[C01]`

### 7.7 Data capture & retention
- All entity mutations generate events → durable log (Kafka) → SearchSvc, AuditSvc, SimilaritySvc subscribers
- Time-series metrics rolled up nightly (`S.AGG`) for `[A02]` Dashboard, `[E04]` Success Metrics, `[Z01]` LLM Costs
- Cold archival tier for >1-year-old Released items + Archived PRDs
- GDPR erasure path: User deletion soft-tombstones identity refs; business artifacts retain anonymised author refs

### 7.8 Concurrency & optimistic locking
- Versioned artifacts use optimistic locking via `version_number`
- Concurrent PRD edits: conflict → user prompt to merge or fork v(N+1)
- Brief v(N+1) supersession (OL-B1) uses explicit UX prompt, not auto-merge

### 7.9 Error & fallback patterns
- AI agent failures (timeout, rate-limit, content filter) surface with retry + "continue manually" fallback
- Bug Replication fallback (AI fail → human) is first-class in §6.21
- Figma push failures queue for retry; don't block user progress

---

## 8. Summary matrices

### 8.1 Component × Service (which services each primitive calls)

| Primitive type | Key services it depends on |
|---|---|
| Sidebar / Top App Bar / Avatar | `IdentitySvc`, `NotificationSvc` |
| Stat Card / Sparkline / Trend Badge / Bento Grid | `MetricsSvc` |
| Data Table / Filter Bar / Pagination | Each screen's owning service + `SearchSvc` for text filters |
| AI Chat Panel / AI Quick-Actions / AI Confidence / RICE Agent Cards / Auto-Generate CTA / AI Generating Indicator / Submission Score Gauge / Transformation Velocity Bar | Owning service (`PRDSvc` / `ResearchSvc` / `RICESvc` / `SpecSvc` / `DesignSvc` / `UATSvc` / `ReleaseNotesSvc` / `BugReplicationSvc`) + `LLMCostSvc` + `AuditSvc` |
| Document Viewer / TOC / Version History / Diff / Annotation / Export | `PRDSvc` + `CommentSvc` |
| Lifecycle Pipeline | `SubmissionSvc` + `AuditSvc` (for historical transitions) |
| Kanban / Comparison Overlay | `BacklogSvc` / `DomainBacklogSvc` |
| Gantt | `RoadmapSvc` |
| Handover Checklist | `HandoverSvc` (aggregates `PRDSvc` + `SpecSvc` + `DesignSvc` + storage) |
| Sprint Row | `DeliverySvc` |
| UAT Criterion / Bug Report Form | `UATSvc` + `SpecSvc` + `RSDSvc` |
| Distribution Picker / Channel tiles | `NotificationSvc` |
| Budget Gauge / Per-feature Cost Row / Model Config | `LLMCostSvc` + `AdminSvc` |
| Comment Thread / Avatar Stack (assignees) | `CommentSvc` + `IdentitySvc` |

### 8.2 Entity × Screens (where each entity is read/written)

| Entity | Primary write screen(s) | Read-only screen(s) |
|---|---|---|
| Request / Brief | `[B01]` | `[B02]` `[B03]` `[D01]` detail |
| PRD | `[B02]` | `[B03]` `[B04]` `[B05]` `[C01]` `[C03]` `[C04]` `[D04]` `[E03]` |
| RSD | Bug Workspace (TBD) | `[B03]` `[D01]` (Type=Bug) |
| PRD Evaluation | `[B05]` | `[B03]` `[C02]` `[D02]` comparison |
| Research Session | `[C01]` | `[B03]` `[C02]` (as context) `[D02]` comparison |
| RICE Assessment | `[C02]` | `[D01]` card `[D02]` comparison `[D03]` Gantt bar |
| Spec Item | `[C03]` | `[B04]` linked `[C04]` `[D04]` `[E02]` (pre-pop criteria) |
| Design Screen / Variant | `[C04]` | `[D04]` |
| Backlog Item | `[D01]` status moves, `[B05]` creates | `[D02]` `[D03]` `[E01]` `[E04]` |
| Domain Flag / Sprint Commitment | `[D02]` | `[D01]` (star) `[D03]` |
| Roadmap Item | `[D03]` | `[A02]` `[E04]` |
| Handover Package | `[D04]` | `[B03]` activity `[E01]` |
| Sprint Task | `[E01]` | `[B03]` activity |
| UAT Run / Bug Report | `[E02]` | `[B03]` activity; Bug Workspace for RSD creation |
| Release Note | `[E03]` | `[B03]` notification; `[E04]` (Top Releases table) |
| Notification | `[E03]` publish writes | every screen's bell |
| LLM Cost Entry | every AI agent invocation | `[Z01]` |

### 8.3 Event × Subscriber

| Event | Subscribers |
|---|---|
| `RequestSubmittedEvt` | `NotificationSvc` · `SearchSvc` · `MetricsSvc` · `AuditSvc` · `PRDSvc` (Features) / `RSDSvc` (Bugs) · `SimilaritySvc` |
| `BriefLockedEvt` / `BriefSupersededEvt` | `NotificationSvc` · `AuditSvc` · `PRDSvc` (on supersede: close open reviews) |
| `PRDVersionCreatedEvt` | `SearchSvc` · `AuditSvc` · `SimilaritySvc` |
| `SubmissionScoreUpdatedEvt` | `NotificationSvc` (thresholds) · `MetricsSvc` |
| `PRDMarkedFinalEvt` | `NotificationSvc` · `SearchSvc` · `PRDSvc` (queue entry) · `AuditSvc` |
| `PRDEvaluatedEvt` | `NotificationSvc` (submitter + PM) · `BacklogSvc` (Approve→create item) · `AuditSvc` |
| `ResearchSessionCompletedEvt` | `NotificationSvc` · `SimilaritySvc` · `AuditSvc` |
| `RICEScoredEvt` | `BacklogSvc` · `MetricsSvc` · `AuditSvc` |
| `SpecItemStatusChangedEvt` · `SpecItemVersionCreatedEvt` | `HandoverSvc` · `SearchSvc` · `AuditSvc` |
| `DesignApprovedEvt` · `DesignPushedToFigmaEvt` | `HandoverSvc` · `NotificationSvc` · `AuditSvc` |
| `BacklogItemCreatedEvt` · `BacklogItemStatusChangedEvt` | `SearchSvc` · `DomainBacklogSvc` · `MetricsSvc` · `NotificationSvc` · `DeliverySvc` (on In Dev) · `AuditSvc` |
| `SprintCommittedEvt` | `RoadmapSvc` · `NotificationSvc` · `AuditSvc` |
| `HandoverSentEvt` | `NotificationSvc` · `DeliverySvc` · `AuditSvc` |
| `SprintTaskProgressEvt` · `SprintTaskBlockerAddedEvt` · `SprintTaskUATReadyEvt` | `MetricsSvc` · `NotificationSvc` · `UATSvc` (on UAT ready) · `AuditSvc` |
| `UATCriterionResultEvt` · `UATRunCompletedEvt` | `DeliverySvc` · `ReleaseNotesSvc` (eligibility) · `MetricsSvc` · `AuditSvc` |
| `BugReportFiledEvt` | `RSDSvc` (create) · `NotificationSvc` · `AuditSvc` |
| `BugReplicationResultEvt` | `RSDSvc` · `NotificationSvc` · `AuditSvc` |
| `ReleasePublishedEvt` | `NotificationSvc` (fan out to all Stakeholders of included Requests) · `MetricsSvc` · `AuditSvc` |
| `LLMInvocationEvt` | `LLMCostSvc` · `AuditSvc` |
| `LLMBudgetThresholdEvt` | `NotificationSvc` (admin alert) · `AuditSvc` |
| `ModelConfigUpdatedEvt` | every AI agent (reload) · `AuditSvc` |

### 8.4 Open items blocking full buildability (cross-reference to Journey doc §9.2)

| ID | What's blocked |
|---|---|
| OL-5 / OL-B6 | `PRDSvc.computeSubmissionScore` algorithm — unblocks `[B02]` gauge, `[B03]` display |
| OL-B1 | Brief supersession UX — affects `SubmissionSvc.createBriefVersion` flow |
| OL-B2 | Bug AI replication mechanism — blocks `BugReplicationSvc` implementation |
| OL-B3 | Bug scoring model — blocks `[D01]` / `[D02]` cards displaying Type=Bug |
| OL-B4 | Bug pipeline screens — blocks end-to-end bug journey |
| OL-B5 | Whether `sprint_commitments.rationale` is sufficient as "decision log" or we need a separate model |
| OL-B7 | Bug-triage agent architecture — affects cost profiles + `LLMCostSvc` categorisation |
| OL-B8 | Brief lock affordance on `[B03]` — UX detail; doesn't block service design |

---

*End of document. Sources: `/screens/A01.html`–`/screens/Z01.html` (canonical UI), `_SOURCES/User_Journey_Flow.md` (canonical journey), `_SOURCES/Product_Hub_Gap_Specifications.md` (legacy feature-level details where still applicable). For generation of missing screens, see `_HANDOFF_CLAUDE_DESIGN/Regeneration_Prompts.md`.*

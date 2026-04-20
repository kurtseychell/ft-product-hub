# API Contract & Event Bus

Complete service-by-service REST endpoints + the event bus schema. Derived from `../Component_Data_Architecture.md` §4 and the screens.

Conventions:
- All endpoints under `/api/v1/…`
- All requests/responses JSON with `Content-Type: application/json`
- Authentication: `Authorization: Bearer <session-token>` header
- Errors follow RFC 7807 problem details (`application/problem+json`)
- Pagination: `?page=1&page_size=25` on list endpoints; envelope `{ items, page, page_size, total }`
- Standard success: 200 (GET/PATCH), 201 (POST create), 202 (POST async triggered), 204 (DELETE)

---

## 1. Service dependency graph

Build in dependency order (low → high):

```
  IdentitySvc
      │
      ├─► NotificationSvc
      │
      ├─► AuditSvc  ────── (subscribed by everyone below)
      │
      ├─► LLMCostSvc ───── (required by every AI-calling service)
      │
      ├─► SubmissionSvc ──► PRDSvc ──► RICESvc ──► BacklogSvc ──► DeliverySvc ──► UATSvc ──► ReleaseNotesSvc
      │         │                │
      │         │                ├─► ResearchSvc (parallel to RICESvc)
      │         │                │
      │         │                ├─► SpecSvc ───► DesignSvc ──► HandoverSvc (pulls from SpecSvc + DesignSvc + PRDSvc)
      │         │
      │         └─► RSDSvc ──► BugReplicationSvc ──► BacklogSvc (same path as PRD once triaged)
      │
      ├─► SearchSvc (subscribes to domain events; read-only API)
      │
      ├─► SimilaritySvc (subscribes to domain events; read-only API)
      │
      ├─► MetricsSvc (subscribes to domain events; read-only API)
      │
      └─► AdminSvc
```

---

## 2. REST endpoints

### 2.1 IdentitySvc

```
POST   /auth/sign-in                          body: { provider, code?, email?, password? }
                                              response: { session_token, expires_at, mfa_required, user }
POST   /auth/sign-out                          response: 204
POST   /auth/mfa/challenge                     response: { challenge_id }
POST   /auth/mfa/verify                        body: { challenge_id, code } → bumps session.mfa_satisfied_at

GET    /users/me                               response: User
GET    /users                                  q, role, domain, status — list
GET    /users/{id}                             response: User
POST   /users                                  (admin) body: { email, role, domain_id? } → 201
PATCH  /users/{id}                             body: { role?, domain_id?, status? } → audit entry; MFA required for role changes
GET    /domains                                list
POST   /domains                                (admin) body: { name, color_token, owner_id } → 201
```

### 2.2 SubmissionSvc

```
POST   /requests                               body: { type, title, brief_md, attachments: [upload_id] }
                                              → 201 { request: Request, brief: Brief }
GET    /requests/{id}                          response: Request + Brief current version
GET    /requests/{id}/lifecycle                response: full stage-by-stage derived state + history

GET    /briefs/{id}?version=N                  response: BriefVersion
GET    /briefs/{id}/versions                   response: [BriefVersion]
POST   /briefs/{id}/versions                   body: { content_md, from_version } → creates v(N+1) Draft
PATCH  /briefs/{id}/versions/{v}               body: { content_md } → 409 if !Editable
POST   /briefs/{id}/versions/{v}/submit        → 200; returns { supersession_prompt_data }? if an in-flight review on earlier version
POST   /briefs/{id}/versions/{v}/supersede-prior
                                              body: { confirm: true } → emits BriefSupersededEvt

POST   /attachments/upload-url                 body: { entity_type, entity_id, filename, content_type }
                                              → { upload_id, signed_url } — client PUTs to s3
POST   /attachments/upload-complete            body: { upload_id } → 201 Attachment
```

### 2.3 PRDSvc

```
GET    /prds/{id}                              response: Prd (includes current_version_content)
GET    /prds/{id}/versions                     response: [PrdVersion]
GET    /prds/{id}/versions/{v}                 response: PrdVersion with content_md + sections
GET    /prds/{id}/diff?from=N&to=M            response: { additions, deletions, section_changes }

POST   /prds/{id}/messages                     body: { content } → 202 (triggers AI.PRD, streams via SSE)
                                              SSE events: turn-start, delta, turn-end, version-committed, score-updated
GET    /prds/{id}/conversation?from=N         response: [PrdConversation]

POST   /prds/{id}/regenerate                   body: { section? } → re-runs AI.PRD
POST   /prds/{id}/finalize                     → 200; transitions Draft → Final (if score ≥ threshold)

GET    /prd-evaluations?status=Pending        list for reviewer
POST   /prds/{id}/evaluations                  body: { scores, score_comments, overall_assessment, decision, decision_rationale } → 201
POST   /prds/{id}/evaluations/bulk-approve     body: { prd_ids[] } → 202 (only allowed for items with auto_score ≥ 4.0)
GET    /prds/{id}/evaluations                  list

POST   /prds/{id}/auto-score                   triggers AI.PRD auto-score pass → 202
GET    /prds/{id}/exports/{format}             async generate + return signed S3 URL; formats: md, html, pdf, pptx, docx

POST   /prds/{id}/annotations                  body: { anchor, text } → 201 Comment
GET    /prds/{id}/annotations                  list
```

### 2.4 RSDSvc + BugReplicationSvc

```
GET    /rsds/{id}                              response: Rsd with current version content
POST   /rsds/{id}/messages                     body: { content } → 202 (triggers AI.RSD)
POST   /rsds/{id}/submit-for-replication       → 200, transitions to InAIReplication, queues AI.BREP job
GET    /rsds/{id}/replication-attempts          list
POST   /rsds/{id}/trigger-replication          (admin) force another AI attempt
POST   /rsds/{id}/hand-to-qa                   → transitions to InManualReplication; notifies QA
POST   /rsds/{id}/manual-attempts              body: { findings, outcome, evidence_refs[] } → 201 replication_attempt
POST   /rsds/{id}/triage                       body: { domain_id, severity, rationale } → 201 creates backlog_items (Type=Bug) with bug_severity_score

GET    /bugs?filter=...                        (triage queue; same data shape as backlog but sliced)
POST   /bugs/{id}/close                        body: { reason } → closes as Cannot Reproduce
```

### 2.5 ResearchSvc

```
POST   /research-sessions                      body: { prd_id, mode } → 201
GET    /research-sessions/{id}                 response: ResearchSession
POST   /research-sessions/{id}/actions         body: { action: "market_analysis"|"competitor_scan"|"user_sentiment"|"tech_feasibility"|"full_research" } → 202
POST   /research-sessions/{id}/messages        body: { content } → 202
POST   /research-sessions/{id}/attach-to-prd   → 200; sets research_sessions.attached_to_prd = true
POST   /research-sessions/{id}/export          body: { format } → signed URL
```

### 2.6 RICESvc

```
POST   /rice/{prd_id}/run                      → 202; runs council of 3 agents in parallel
GET    /rice/{prd_id}                          response: RiceAssessment (consensus + agents + confidence_range)
PATCH  /rice/{prd_id}/override                 body: { rice: { R, I, C, E }, audit_note } → 200; appends to rice_override_history
```

### 2.7 SpecSvc

```
POST   /specs/generate                         body: { prd_id } → 202; AI.SPEC generates set
GET    /specs?prd_id=...&type=...              list
GET    /specs/{id}                             detail
PATCH  /specs/{id}                             body: { title?, content_rich?, acceptance_criteria?, status? }
POST   /specs/{id}/regenerate                  → 202
POST   /specs/{id}/enhance-a11y                → 202
POST   /specs/{id}/generate-acceptance-criteria → 202
DELETE /specs/{id}                             soft delete
GET    /specs/graph?prd_id=...                 response: { nodes, edges }
GET    /specs/transformation-velocity?prd_id=... response: TransformationVelocity
POST   /specs/submit-set                       body: { prd_id } → 202; transitions all Draft → InReview
```

### 2.8 DesignSvc

```
POST   /designs/generate                       body: { prd_id, style, screen_scope[] } → 202; AI.DSG
GET    /designs?prd_id=...                     list
GET    /designs/{id}                           detail with variants
POST   /designs/{id}/variants                  body: { feedback } → 202; AI.DSG regenerates
PATCH  /designs/{id}/active-variant            body: { variant_id } → 200
POST   /designs/{id}/push-figma                → 202; triggers Figma sync
POST   /designs/{id}/approve                   → 200; emits DesignApprovedEvt
POST   /designs/{id}/annotations               body: { region, component_name, note }
PATCH  /designs/flow-order                     body: { orders: [{ design_id, flow_order }] }
```

### 2.9 BacklogSvc & DomainBacklogSvc

```
GET    /backlog?domain=&status=&type=         paginated list
PATCH  /backlog/{id}                           body: { status?, domain_id?, assignees?, target_quarter? } (RLS-protected)
POST   /backlog                                (admin) manual creation

POST   /domain-backlog/{domain_id}/reorder     body: { backlog_item_id, ranked_position }
PATCH  /domain-backlog/{domain_id}/flags/{backlog_item_id}
                                              body: { flagged_priority?, domain_notes? }

POST   /domain-backlog/{domain_id}/compare     body: { backlog_item_ids[] } → 201 { session_id, cached_comparison_data } (Redis 24h TTL)
GET    /domain-backlog/compare/{session_id}    response: cached data
DELETE /domain-backlog/compare/{session_id}    → 204 (explicit close; auto-TTL also applies)

POST   /sprint-commitments                     body: { sprint_id, backlog_item_ids[], rationale, comparison_selection_ids? } → 201
GET    /sprint-commitments?sprint_id=          list
```

### 2.10 RoadmapSvc

```
GET    /roadmap?quarter=                       response: { items, monthly_allocation, strategic_capacity }
POST   /roadmap/items                          body: { backlog_item_id, quarter, start_week, end_week, domain_id } → 201
PATCH  /roadmap/items/{id}                      body: { start_week?, end_week?, status?, depends_on? }
DELETE /roadmap/items/{id}
PATCH  /roadmap/notes/{quarter}                body: { objectives_md, resource_shifting_md }
GET    /roadmap/export?quarter=&format=pdf|csv response: signed URL
```

### 2.11 HandoverSvc

```
GET    /handover-packages/{backlog_item_id}    derived package with readiness
POST   /handover-packages/{backlog_item_id}/integration-docs/upload-url
                                              body: { filename, content_type } → signed URL
POST   /handover-packages/{backlog_item_id}/assign
                                              body: { team_id, tech_lead_id }
POST   /handover-packages/{backlog_item_id}/send  → 202 HandoverSentEvt
GET    /handover-packages/{backlog_item_id}/export-zip → signed URL
```

### 2.12 DeliverySvc

```
GET    /sprints                                list
POST   /sprints                                (admin) body: { number, starts_on, ends_on }
GET    /sprints/{id}/tasks                    list with filter
PATCH  /sprint-tasks/{id}                      body: { progress_pct?, state?, lead_id?, target_date?, demo_ready? }
POST   /sprint-tasks/{id}/blockers             body: { title, description, severity }
PATCH  /sprint-tasks/{id}/blockers/{blocker_id} body: { resolved: true }
POST   /sprint-tasks/{id}/ready-for-uat        → promotes → UATSvc eligibility
```

### 2.13 UATSvc

```
POST   /uat-runs                               body: { backlog_item_id } → 201 (seeds criteria from specs.acceptance_criteria)
GET    /uat-runs/{id}                          response
PATCH  /uat-runs/{id}/criteria/{criterion_id}  body: { result, comment?, evidence_upload_ids[] }
POST   /uat-runs/{id}/bugs                     body: { title, description, severity } → 201 (creates Bug Report + RSD)
POST   /uat-runs/{id}/messages                 body: { content } → 202 AI.TST turn
POST   /uat-runs/{id}/complete                 → 200; emits UATRunCompletedEvt
```

### 2.14 ReleaseNotesSvc

```
POST   /release-notes                          body: { version_label, included_prd_ids[], included_bug_rsd_ids[] } → 201 Draft
GET    /release-notes/{id}                     response
PATCH  /release-notes/{id}                     body: { body_md?, audiences?, channels?, scheduled_at?, included_prd_ids? }
POST   /release-notes/{id}/generate            → 202; AI.RLN drafts body
POST   /release-notes/{id}/publish             → 202; emits ReleasePublishedEvt; fans out notifications
POST   /release-notes/{id}/preview             → returns rendered HTML
GET    /release-notes/eligible-prds            approved but not yet in any release
```

### 2.15 NotificationSvc

```
GET    /notifications?unread=true             list for current user
PATCH  /notifications/{id}/read
POST   /notifications/mark-all-read

# v2 (OL-3)
GET    /notification-prefs                     for current user
PATCH  /notification-prefs                     body: { event_type, channel, enabled, digest_schedule }
```

### 2.16 AdminSvc + LLMCostSvc

```
GET    /admin/llm-costs?range=...&feature=... response: cost breakdown with sparklines
GET    /admin/llm-budgets/{period}            response
PATCH  /admin/llm-budgets/{period}             body: { budget_cents, alert_thresholds }
GET    /admin/model-configs                    list
PATCH  /admin/model-configs/{feature}          body: { model, max_tokens }

GET    /admin/platform-settings               list
PATCH  /admin/platform-settings/{key}          body: { value }

# v2 (OL-4): users / domains / whitelist admin endpoints; already under /users and /domains namespace
```

### 2.17 MetricsSvc (read-only)

```
GET    /metrics/dashboard?range=              response: { pipeline_counts, velocity, team_capacity }
GET    /metrics/kpis?range=&domain=           response: KPI cards data
GET    /metrics/funnel?range=                 response: stage-by-stage counts
GET    /metrics/domain-distribution?range=
GET    /metrics/top-releases?range=
GET    /metrics/rice-accuracy?range=
GET    /metrics/dashboard-summary?user_id=    per-user personalised dashboard counts
```

### 2.18 SearchSvc & SimilaritySvc

```
GET    /search?q=...&type=prd|spec|backlog|research|bug
                                              response: [hit] with highlights
GET    /similarity/similar?entity_type=&entity_id=&k=5
                                              response: [similar entity refs with scores]
```

### 2.19 AuditSvc

```
GET    /audit?entity_type=&entity_id=          response: [audit entries, latest first]
GET    /audit/export?since=&until=&format=ndjson → signed URL (compliance export)
```

---

## 3. Domain Event Schemas

All events emitted to Kafka topic pattern `producthub.<svc>.<event>.v1`. Every event envelope:

```json
{
  "event_id": "uuid",
  "event_type": "PRDEvaluatedEvt",
  "event_version": 1,
  "emitted_at": "2026-04-20T09:15:22Z",
  "producer_service": "PRDSvc",
  "correlation_id": "uuid",
  "causation_id": "uuid",
  "tenant_id": "uuid",
  "payload": { /* per-event schema */ }
}
```

### 3.1 Event schemas

```typescript
RequestSubmittedEvt.payload = {
  request_id: UUID;
  public_id: string;
  type: 'NewIdea' | 'ChangeRequest' | 'Bug';
  submitter_id: UUID;
  title: string;
}

BriefVersionCreatedEvt.payload = {
  brief_id: UUID; request_id: UUID; version: int; author_id: UUID; lock_status: string;
}

BriefSubmittedEvt.payload = {
  brief_id: UUID; version: int; submitter_id: UUID; content_hash: string;
}

BriefLockedEvt.payload = {
  brief_id: UUID; version: int; trigger: string; locked_at: iso-ts;
}

BriefSupersededEvt.payload = {
  brief_id: UUID; from_version: int; superseded_by_version: int; decided_by: UUID;
  cancelled_review_id: UUID|null;
}

PRDVersionCreatedEvt.payload = {
  prd_id: UUID; version: int; author_id: UUID|null; ai_agent_code: string|null;
  commit_reason: string;
}

SubmissionScoreUpdatedEvt.payload = {
  prd_id: UUID; score: int; components: {completeness,depth,specificity,ai_confidence}; delta: int;
}

PRDMarkedFinalEvt.payload = {
  prd_id: UUID; version: int; score: int; finalized_by: UUID;
}

PRDEvaluatedEvt.payload = {
  prd_id: UUID; evaluation_id: UUID; reviewer_id: UUID; decision: string; rationale_preview: string;
}

ResearchSessionCompletedEvt.payload = {
  session_id: UUID; prd_id: UUID; recommendation: string; confidence: float; attached_to_prd: bool;
}

RICEScoredEvt.payload = {
  prd_id: UUID; aggregate_score: int; consensus_rice: {R,I,C,E}; confidence_range: [int,int];
  divergence_flags: string[]; override_active: bool;
}

SpecItemVersionCreatedEvt.payload = { spec_id: UUID; version: int; author_id: UUID|null; ai_agent_code: string|null; }
SpecItemStatusChangedEvt.payload = { spec_id: UUID; prd_id: UUID; from: string; to: string; changed_by: UUID; }

DesignVariantCreatedEvt.payload = { design_id: UUID; variant_id: UUID; prd_id: UUID; }
DesignApprovedEvt.payload = { design_id: UUID; prd_id: UUID; variant_id: UUID; approved_by: UUID; }
DesignPushedToFigmaEvt.payload = { design_id: UUID; figma_frame_url: string; pushed_by: UUID; }

BacklogItemCreatedEvt.payload = {
  backlog_item_id: UUID; public_id: string; type: 'Feature'|'Bug'; prd_id: UUID|null; rsd_id: UUID|null; domain_id: UUID|null;
}
BacklogItemStatusChangedEvt.payload = {
  backlog_item_id: UUID; from: string; to: string; changed_by: UUID;
}
BacklogItemScoreChangedEvt.payload = {
  backlog_item_id: UUID; score_kind: 'rice'|'bug_severity'; from: int|null; to: int;
}

DomainPriorityFlaggedEvt.payload = {
  backlog_item_id: UUID; domain_id: UUID; flagged: bool; by: UUID;
}

SprintCommittedEvt.payload = {
  commitment_id: UUID; sprint_id: UUID; backlog_item_id: UUID; committed_by: UUID; rationale_preview: string;
}

HandoverPackageUpdatedEvt.payload = { package_id: UUID; readiness_pct: int; }
HandoverSentEvt.payload = { package_id: UUID; backlog_item_id: UUID; tech_lead_id: UUID; sent_by: UUID; }

SprintTaskProgressEvt.payload = { task_id: UUID; backlog_item_id: UUID; progress_pct: int; state: string; }
SprintTaskBlockerAddedEvt.payload = { task_id: UUID; blocker_id: UUID; severity: string; title: string; }
SprintTaskUATReadyEvt.payload = { task_id: UUID; backlog_item_id: UUID; by: UUID; }

UATCriterionResultEvt.payload = { uat_run_id: UUID; criterion_id: string; result: string; by: UUID; }
UATRunCompletedEvt.payload = { uat_run_id: UUID; backlog_item_id: UUID; all_pass: bool; }
BugReportFiledEvt.payload = { bug_id: UUID; source: string; rsd_id: UUID|null; uat_run_id: UUID|null; submitter_id: UUID; }

RSDSubmittedForReplicationEvt.payload = { rsd_id: UUID; }
BugReplicationResultEvt.payload = {
  rsd_id: UUID; attempt_id: UUID; result: string; strategies_used: string[];
  evidence_count: int; reasoning_preview: string; total_cost_cents: int;
}
RSDHandedToQAEvt.payload = { rsd_id: UUID; by: UUID; assigned_to: UUID|null; }
ManualReplicationCompletedEvt.payload = { rsd_id: UUID; attempt_id: UUID; outcome: string; }
RSDTriagedEvt.payload = { rsd_id: UUID; backlog_item_id: UUID; severity: string; domain_id: UUID|null; }

ReleaseNoteDraftedEvt.payload = { release_note_id: UUID; version_label: string; }
ReleaseNoteScheduledEvt.payload = { release_note_id: UUID; scheduled_at: iso-ts; }
ReleasePublishedEvt.payload = {
  release_note_id: UUID; version_label: string; published_by: UUID;
  prd_ids: UUID[]; bug_rsd_ids: UUID[]; audiences: string[]; channels: string[];
}

LLMInvocationEvt.payload = {
  cost_entry_id: UUID; agent_code: string; feature: string; model: string;
  tokens_in: int; tokens_out: int; cost_cents: int; latency_ms: int;
  caller_id: UUID|null; entity_type: string|null; entity_id: UUID|null;
}
LLMBudgetThresholdEvt.payload = {
  period_month: date; threshold_pct: int; current_spend_cents: int; budget_cents: int;
}
ModelConfigUpdatedEvt.payload = { feature: string; model: string; max_tokens: int; updated_by: UUID; }

AlgorithmConfigChangedEvt.payload = { key: string; old_value: any; new_value: any; updated_by: UUID; }

AuditEntryWrittenEvt.payload = { audit_id: UUID; actor_type: string; action: string; entity_type: string; entity_id: UUID; }

SessionStartedEvt.payload = { user_id: UUID; ip: string; ua: string; }

CommentCreatedEvt.payload = { comment_id: UUID; entity_type: string; entity_id: UUID; author_id: UUID; mentions: UUID[]; }
```

### 3.2 Event producers & subscribers

See `../Component_Data_Architecture.md` §8.3 for full matrix. New events added in this doc:
- `BriefVersionCreatedEvt`, `BriefVersionForkedEvt`: subscribed by `SearchSvc`, `AuditSvc`
- `BugSeverityComputedEvt`: emitted by `BacklogSvc`, subscribed by `AuditSvc`, `MetricsSvc`
- `SubmissionScoreComputedEvt`, `TransformationVelocityComputedEvt`, `RICEConsensusComputedEvt`: emitted by respective algorithm runners; subscribed by `MetricsSvc`

### 3.3 Subscriber conventions

- Consumers must be **idempotent** — subscribing to the same event twice must produce the same end state
- Consumers must **not block** — long-running work must enqueue into a local job queue and acknowledge the event within 500ms
- Consumers handle events **at-least-once** — duplicates expected
- Consumers persist their consumer offset in their own DB (per-service)
- Dead-letter queue for unprocessable events; alert at >10 messages in DLQ

### 3.4 Event versioning

- `event_version: 1` initially on all events
- Breaking changes require bumping version + running both versions side-by-side during migration window (minimum 30 days)
- New optional fields do not bump version; required-field additions do

---

## 4. WebSocket / Server-Sent Events

Real-time updates for UI:

| Endpoint | Stream content | Consumer screen |
|---|---|---|
| `SSE /prds/{id}/stream` | PRD version created, score updated, AI streaming deltas | `[B02]` |
| `SSE /research-sessions/{id}/stream` | Conversation deltas, report updates | `[C01]` |
| `SSE /rsds/{id}/stream` | RSD version updates, replication attempt progress | Bug Workspace |
| `WS /backlog/live` | `BacklogItemStatusChangedEvt`, `BacklogItemScoreChangedEvt` (filtered to visible items) | `[D01]`, `[D02]` |
| `WS /delivery/live?sprint_id=` | `SprintTaskProgressEvt` | `[E01]` |
| `WS /uat-runs/{id}/stream` | `UATCriterionResultEvt`, AI.TST deltas | `[E02]` |
| `WS /notifications/live` | NotificationCreated, NotificationRead | every screen's bell |

All WS/SSE connections are authenticated and scoped to the user's identity + RLS policies at subscription time.

---

## 5. Rate limits & quotas

| Scope | Limit |
|---|---|
| Per-user API | 300 req/min sustained, 60 burst |
| Per-user AI turns (PRD Builder, Research) | 20 turns/min |
| Per-user file uploads | 100 MB/hour |
| Per-IP unauthenticated | 10 req/min (login attempts) |
| Search queries | 60 req/min per user |
| AI agent invocations (system-wide) | Governed by LLM budget, not rate limit |

Rate limit responses: `429 Too Many Requests` with `Retry-After` header.

---

## 6. Error model

```json
{
  "type": "https://producthub.example.com/errors/validation",
  "title": "Validation failed",
  "status": 422,
  "detail": "Decision rationale must be at least 20 characters",
  "instance": "/api/v1/prds/550e8400-.../evaluations",
  "errors": [
    { "field": "decision_rationale", "code": "too_short", "message": "must be at least 20 characters" }
  ]
}
```

Canonical error types (slugs under /errors/): `authentication`, `authorization`, `validation`, `not_found`, `conflict`, `locked_for_review`, `rate_limit`, `ai_cost_cap`, `upstream_unavailable`, `internal`.

---

*See `06_RBAC_Security_Observability.md` for authz matrix per endpoint, `04_Database_Schema.sql` for entity definitions.*

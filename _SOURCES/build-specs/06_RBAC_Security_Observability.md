# RBAC, Security & Observability

Operational spec: who can do what (RBAC), how data is protected (security), how we see what's happening (observability).

---

## 1. RBAC Matrix

### 1.1 Roles

Eight roles. Can be combined per user (e.g., Product Lead + Domain Owner):

| Role | Superset of | Notes |
|---|---|---|
| `Stakeholder` | — | End user; submits and tracks own |
| `Viewer` | — | Read-only across screens they have entity access to |
| `ProductManager` | Viewer | Drives PRDs, research, specs, designs, handover, release notes |
| `ProductLead` | ProductManager | Can evaluate, score RICE override, commit sprints |
| `DomainOwner` | ProductLead (within domain) | Scoped by domain via RLS |
| `EngineeringLead` | Viewer | Delivery + handover receipt |
| `QA` | Viewer | UAT execution + manual bug replication |
| `Admin` | all above | Platform config, user management, LLM budgets |

### 1.2 Action matrix

Shorthand:
- `R` = read (own)
- `RA` = read all within domain
- `RG` = read all globally
- `W` = write (own)
- `WA` = write any in-domain
- `WG` = write globally
- `—` = no access
- `MFA` = fresh MFA challenge required

| Action | Stake | Viewer | PM | PL | DO | EL | QA | Admin |
|---|---|---|---|---|---|---|---|---|
| **Requests / Briefs** | | | | | | | | |
| Create Request (any type) | W | — | W | W | W | W | W | W |
| Edit own Brief (Draft/Submitted) | W | — | — | — | — | — | — | — |
| Fork v(N+1) of own Brief | W | — | — | — | — | — | — | — |
| Supersede own Brief | W | — | — | — | — | — | — | — |
| Read any Brief | R (own) | R (where entity access) | RG | RG | RA | RG | RG | RG |
| **PRDs** | | | | | | | | |
| Drive PRD Builder | — | — | W (assigned) | W (any) | W (in domain) | — | — | W |
| Mark PRD Final | — | — | W (assigned) | W | W (in domain) | — | — | W |
| Read PRD | R (own request) | R | RG | RG | RA | RG | RG | RG |
| Evaluate PRD | — | — | — | W | W (in domain) | — | — | W |
| Bulk approve PRDs | — | — | — | W | W (in domain) | — | — | W |
| Annotate PRD | — | W | W | W | W | W | W | W |
| Export PRD | R | R | W | W | W | W | W | W |
| **Research** | | | | | | | | |
| Start research session | — | — | W | W | W | — | — | W |
| Attach research to PRD | — | — | W (own session) | W | W | — | — | W |
| **RICE** | | | | | | | | |
| Trigger RICE scoring | — | — | W | W | W | — | — | W |
| Manual RICE override | — | — | — | W (MFA) | W (MFA) | — | — | W (MFA) |
| **Specs** | | | | | | | | |
| Generate spec set | — | — | W | W | W | — | — | W |
| Edit spec | — | — | W | W | W | W | — | W |
| Approve spec | — | — | — | W | W | W | — | W |
| **Designs** | | | | | | | | |
| Generate design variants | — | — | W | W | W | — | — | W |
| Approve design | — | — | W | W | W | — | — | W |
| Push to Figma | — | — | W | W | W | — | — | W |
| **Backlog** | | | | | | | | |
| Read backlog | — | R | RG | RG | RA | RG | RG | RG |
| Move item on Kanban | — | — | W | W | W (in domain) | W | — | W |
| Manual item create | — | — | — | — | — | — | — | W |
| **Domain Backlog** | | | | | | | | |
| Reorder within domain | — | — | — | W (in domain) | W (in domain) | — | — | W |
| Flag Domain Priority | — | — | — | W (in domain) | W (in domain) | — | — | W |
| Start comparison | — | — | W | W | W | — | — | W |
| Commit to sprint | — | — | — | W | W (in domain) | — | — | W |
| **Roadmap** | | | | | | | | |
| Read roadmap | — | R | RG | RG | RG | RG | RG | RG |
| Edit roadmap items | — | — | — | W | W (in domain) | — | — | W |
| Edit roadmap notes | — | — | — | W | W (in domain) | — | — | W |
| **Handover** | | | | | | | | |
| Upload integration docs | — | — | W | W | W | W | — | W |
| Assign handover to team | — | — | W | W | W | — | — | W |
| Send handover | — | — | W | W | W | — | — | W |
| **Delivery** | | | | | | | | |
| Update task progress / state | — | — | — | — | — | W | — | W |
| Mark UAT ready | — | — | — | — | — | W | — | W |
| Add blocker | — | — | — | — | — | W | W | W |
| **UAT** | | | | | | | | |
| Execute UAT | — | — | — | — | — | — | W | W |
| File bug in UAT | — | — | — | — | — | W | W | W |
| **Bug Pipeline** | | | | | | | | |
| Edit RSD | R (own if Stakeholder-filed) | — | — | — | — | W | W | W |
| Trigger AI replication | — | — | — | — | — | W | W | W |
| Perform manual replication | — | — | — | — | — | W | W | W |
| Triage bug to backlog | — | — | — | — | — | W | W | W |
| Close bug as Cannot Reproduce | — | — | — | — | — | W (MFA) | W (MFA) | W |
| **Release Notes** | | | | | | | | |
| Draft release note | — | — | W | W | — | — | — | W |
| Publish release note | — | — | W (MFA) | W (MFA) | — | — | — | W (MFA) |
| **Admin** | | | | | | | | |
| Manage users (role changes) | — | — | — | — | — | — | — | W (MFA) |
| Edit LLM budgets | — | — | — | — | — | — | — | W (MFA) |
| Edit model configs | — | — | — | — | — | — | — | W (MFA) |
| Edit platform settings | — | — | — | — | — | — | — | W (MFA) |
| Export audit log | — | — | — | — | — | — | — | W (MFA) |

### 1.3 Enforcement locations

- **Postgres RLS**: coarse data-level isolation (domain scoping on backlog, requests, briefs, etc.). Enforced on every query.
- **Service-layer guards**: per-action checks using the role and entity context (e.g., "only the assigned reviewer can submit the evaluation"). Expressed as policy functions.
- **API gateway middleware**: role-check on every route before hitting service.
- **UI gates**: disable/hide CTAs for roles that can't perform the action — **defense-in-depth only, not trusted**.

### 1.4 Elevation & audit

- MFA-gated actions log an `ElevatedActionEvt` before execution; action audit entry includes `mfa_satisfied_at`
- Role changes: `actor_id` in audit must be an `Admin`; self-role-change is disallowed; audit includes before/after role
- Suspensions: user's active sessions are revoked on suspension

---

## 2. Security model

### 2.1 Data classification

| Class | Examples | Encryption | Access log |
|---|---|---|---|
| **Public** | Release notes (published) | TLS only | No |
| **Internal** | Requests, PRDs, backlog items, metrics | TLS + at-rest | Yes (audit log) |
| **Sensitive** | User emails, session tokens, SSO subject ids | TLS + at-rest + field-level where viable | Yes; access reviews quarterly |
| **Secret** | API keys, webhook secrets, SMTP creds, LLM provider keys | TLS + at-rest + KMS-managed keys; never in application config | Yes; alert on any read |
| **Forbidden** | Payment card data, health data | Not stored | N/A |

### 2.2 Encryption at rest

- Postgres: TDE enabled; key rotated every 12 months; managed by cloud KMS
- S3: SSE-KMS on all buckets; bucket policy denies public access
- Redis: TLS + AUTH; no sensitive data stored (session state only, with TTL)
- Kafka: TLS + SASL; topic-level ACLs

### 2.3 Encryption in transit

- Public endpoints: TLS 1.3 minimum; HSTS enabled; HTTP → HTTPS 301
- Internal service-to-service: mTLS
- Admin endpoints: served on separate hostname (e.g., admin.producthub.example.com) with stricter CSP

### 2.4 Secret management

- No secrets in source, in env files, or in image configs
- All secrets in KMS-backed secret store (AWS Secrets Manager / GCP Secret Manager / Vault)
- Rotation:
  - LLM provider API keys: quarterly
  - SMTP/Slack/Confluence webhooks: on suspicion of compromise + quarterly rotation
  - Signing keys (JWT): monthly with 2-key overlap
- Break-glass credential: sealed, 2-person retrieval, audited use

### 2.5 PII handling

**PII fields** (users table + comments + notifications):
- `email`, `full_name`, `avatar_url`, `sso_subject`, `ip_address` (sessions, audit_log)

**Rules:**
- Hash email lookups with pepper for bulk queries
- Never include email/full_name in log lines (use `user_id` only)
- Masking in UI for non-owner views (show initial+last letter of surname for Stakeholder in cross-domain views)
- GDPR erasure: soft-delete user (`users.deleted_at`), anonymise `full_name → "Deleted User"`, set `email := 'deleted-{user_id}@internal'`, scrub avatar. Business artifacts retain anonymised author refs (the work isn't erased — legal hold applies per contract).

### 2.6 Threat model (top-10 risks)

| # | Risk | Mitigation |
|---|---|---|
| 1 | Credential stuffing on sign-in | Rate limit per IP; account lockout after 10 failures/hr; 2FA required for Admin |
| 2 | Session hijacking | Short session TTL (30 min idle) + refresh on activity; sessions bound to user agent + IP range |
| 3 | Privilege escalation via role change | MFA required; audit logged; can't self-change; admin-only endpoint |
| 4 | Cross-domain read (RLS bypass) | RLS on all domain-scoped tables; RLS tested in CI; request tests verify per-role boundaries |
| 5 | Prompt injection via Brief → AI.PRD | Prompt templates use content-isolation (user content in quoted section, never template); output parsing validates structure; AI.PRD can only call approved tools |
| 6 | Malicious file upload → XSS or virus | ClamAV scan; content-type sniffing; served from isolated CDN domain; Content-Security-Policy blocks scripts |
| 7 | Enumeration of Requests/PRDs via public_id | public_id is random (not sequential); RLS prevents cross-reading; rate limit on lookups |
| 8 | LLM cost DoS (triggering expensive agents repeatedly) | Per-user + per-month quotas; cost cap per invocation; 429 on quota exhausted |
| 9 | Webhook forgery (Figma, Stripe, etc.) | Verify HMAC signatures; replay-protect via nonce; timestamp window of 5 min |
| 10 | Insider data exfiltration | All sensitive actions audited; bulk export requires MFA; anomaly detection on abnormally large queries |

### 2.7 Dependencies & SBOM

- All dependencies scanned in CI (Snyk / npm audit / pip-audit / gosec equivalent)
- SBOM generated per release (Syft); shipped alongside release artifact
- Monthly dependency review; critical CVEs patched within 72h

### 2.8 Compliance posture

- **SOC 2 Type II**: audit log retention 7y, access reviews quarterly, MFA enforced, change management documented
- **GDPR / UK-GDPR**: erasure path (§2.5), data processing records documented, DPA available
- **ISO 27001**: information security policies, supplier management, incident response plan
- Annual penetration test; findings tracked to resolution

---

## 3. Observability

### 3.1 Signals

Four signal types. Every service instruments all four.

| Signal | Tool (recommended) | Cardinality | Retention |
|---|---|---|---|
| **Metrics** | Prometheus + Grafana | Low-med | 30d high-res, 1y aggregated |
| **Logs** | OpenSearch / Loki | High | 30d hot, 1y cold |
| **Traces** | Jaeger / OpenTelemetry | Med | 7d sampling at 10% |
| **Events** | Kafka → ClickHouse (analytics) | Very high | 90d |

### 3.2 Key metrics

**RED method per service:**
- **Rate**: `producthub_http_requests_total{svc, method, route, status}`
- **Errors**: `producthub_http_errors_total{svc, route, error_type}`
- **Duration**: `producthub_http_request_duration_seconds{svc, route}` (histogram)

**Per-algorithm:**
- `producthub_submission_score_compute_duration_ms` (p50/p95/p99)
- `producthub_rice_consensus_compute_duration_ms`
- `producthub_transformation_velocity_compute_duration_ms`
- `producthub_bug_severity_compute_duration_ms`

**Business counters:**
- `producthub_requests_submitted_total{type}`
- `producthub_prds_marked_final_total`
- `producthub_prds_evaluated_total{decision}`
- `producthub_rice_scored_total`
- `producthub_designs_approved_total`
- `producthub_bugs_triaged_total{severity}`
- `producthub_releases_published_total`

**LLM:**
- `producthub_llm_invocations_total{agent_code, model, outcome}`
- `producthub_llm_tokens_total{agent_code, direction}` (in/out)
- `producthub_llm_cost_cents_total{agent_code, feature}`
- `producthub_llm_latency_seconds{agent_code}`

**Event bus:**
- `producthub_event_publish_total{topic}`
- `producthub_event_consume_duration_ms{topic, subscriber}`
- `producthub_event_dlq_total{topic}`

### 3.3 Structured logs

All logs: JSON, one record per line, `trace_id` + `user_id` + `entity_type/id` fields. No PII (email, name) in log lines.

Canonical log fields:
```
{ ts, level, svc, trace_id, span_id, user_id, tenant_id, action, entity_type, entity_id, message, extra:{} }
```

Log levels:
- `DEBUG` — disabled in prod by default
- `INFO` — successful state transitions, external calls
- `WARN` — recoverable errors, fallback paths taken
- `ERROR` — request failed, needs attention
- `FATAL` — service is dying

### 3.4 Traces

OpenTelemetry propagation across HTTP + Kafka + AI agent calls. Key spans:
- `api.handler.{route}` — top-level request
- `db.query.{table}.{operation}` — with SQL metadata, no values
- `llm.invoke.{agent_code}` — with model, tokens, cost as attributes
- `event.publish.{topic}` and `event.consume.{topic}`
- `algorithm.{name}` — algorithm computation spans

Sampling:
- 100% of error traces
- 100% of traces with LLM invocations (for cost debugging)
- 10% of normal traces
- 1% of health check traces

### 3.5 Dashboards

Mandatory dashboards (Grafana):
1. **Platform overview** — RED per service, event bus lag, error rate
2. **LLM costs** — mirrors `[Z01]` but real-time (breakdown by agent, feature, model; burn rate vs. budget)
3. **Pipeline throughput** — mirrors `[E04]` in real-time; funnel per stage
4. **Algorithm health** — compute latencies for the 4 algorithms; recomputation rates
5. **Bug pipeline** — AI replication success rate; cost per replication; triage latency
6. **Security** — MFA challenges issued vs. completed; privilege escalations; auth failures
7. **Database** — query duration p95, connection pool utilisation, dead-tuple ratio, replication lag
8. **User experience** — synthetic check latency per screen; front-end error rate

### 3.6 Alerts (on-call pager)

| Severity | Condition | Response |
|---|---|---|
| P1 | Error rate > 5% for 5 min on any core service | Page immediately |
| P1 | LLM budget 95% consumed mid-month | Page — risk of service disable |
| P1 | Event bus DLQ > 50 messages | Page |
| P2 | p95 latency > 2× baseline for 15 min | Notify channel |
| P2 | AI replication success rate drops > 20% WoW | Notify — may indicate prompt drift |
| P2 | Session concurrency > 2× baseline | Notify — may indicate attack |
| P3 | Storage > 80% capacity | Notify — plan expansion |
| P3 | Dependency CVE critical | Ticket created for patch |

### 3.7 Audit-log vs. event-log vs. metrics

These are three distinct concerns; don't conflate:

- **Audit log** (`audit_log` table) — append-only record of sensitive/meaningful mutations. Human-readable. For compliance, forensic review, activity timelines on screens.
- **Event log** (Kafka) — firehose of domain events. Machine-readable. For service coordination, stream processing, replay.
- **Metrics** — time-series quantities. Aggregated. For dashboards, alerts, capacity planning.

An LLM invocation produces **all three**: audit entry (who/what/when), event (`LLMInvocationEvt` for cost accounting), metrics (`producthub_llm_*` counters/histograms).

### 3.8 Synthetic & RUM

- **Synthetic checks**: scripted user journeys (submit → PRD builder → evaluate) every 5 min from 3 regions; fail = page
- **RUM** (Real User Monitoring): front-end error rate, Core Web Vitals per screen, per-browser breakdown; dashboards per screen

### 3.9 Runbooks

Every P1 alert has a runbook linked from the alert message. Runbook structure:
- Symptom — what you'd see on the dashboard
- Hypothesis — likely causes ordered by probability
- Diagnostic steps — commands to run, dashboards to check
- Mitigation — rollback, scaling, feature flags
- Resolution — post-incident actions

Stored in `docs/runbooks/` (future — currently in this spec doc as appendices).

---

## 4. Data governance policies

### 4.1 Retention
Governed by data class (§2.1) and entity class (see `../Component_Data_Architecture.md` §3.3):
- Business artifacts (PRDs, specs, etc.): indefinite with archive tier after 1y inactivity
- Audit log: 7 years
- LLM cost ledger: 7 years (financial)
- Sessions: TTL (30 min to 30 days based on remember-me)
- Ephemeral Redis state: TTL per type (2 min for edit locks; 24h for comparison sessions)
- Logs: 30 days hot, 1 year cold, then deleted
- User PII: while active; 30 days after deletion; then permanent tombstone

### 4.2 Legal hold
An admin can place legal hold on a Request — its artifacts skip archival and deletion even after normal retention expires. Hold is audited.

### 4.3 Quarterly reviews
- Access review: every 90 days; removes inactive users + validates role assignments
- Vendor / dependency review: every 90 days
- Retention review: verify archive processes running; random-sample spot-checks

### 4.4 Incident response
Named on-call. Severity classes S1–S4 with response SLOs. Post-mortem required for S1/S2 within 5 business days. Public communication channel for external S1s.

---

*See `04_Database_Schema.sql` for RLS policy skeletons; `07_Deployment_Testing_Phasing.md` for rollout and infra; `../User_Journey_Flow.md` for decision provenance.*

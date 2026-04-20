# Bug Pipeline Specification (Stage B-Bug)

Complete specification for the Bug-path journey from Stakeholder submission through triage and into the standard backlog. Closes **OL-B2**, **OL-B4**, **OL-B7**.

---

## 1. Flow overview

```
[B01] Submit Request (Type=Bug)
    │
    │  RequestSubmittedEvt (type=Bug)
    ▼
Bug Workspace ─── AI.RSD drafts RSD from Brief ──► RSD v1 Draft
    │
    │  User marks "Mark for AI Replication"
    ▼
AI Replication Phase
    ├─► AI.BREP attempts replication (sandbox / test harness / log query)
    │       │
    │       ├── success ──► RSD status: Replicated by AI
    │       │               evidence: log bundle, screenshot, video
    │       │               ──► goto Triage
    │       │
    │       └── failure ──► RSD status: Replication Failed
    │                       reasons: captured
    │                       ──► Manual Replication
    │
Manual Replication (human fallback)
    ├─► QA/Engineer works through the RSD
    │       │
    │       ├── reproduced ──► RSD status: Reproduced ──► Triage
    │       └── can't reproduce ──► RSD status: Cannot Reproduce ──► Triage (flagged)
    │
Triage (Bug Triage Queue screen)
    ├─► Assign to domain, set Bug Severity (via §1 algo)
    ├─► Create backlog_items row (Type=Bug)
    └─► ──► goes through normal [D01] / [D02] / [D03] / [E01] flow like a Feature
```

## 2. Entities

### 2.1 `rsds` (Reproduction Steps Document)

```sql
CREATE TABLE rsds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE RESTRICT,
  current_version INT NOT NULL DEFAULT 1,
  status rsd_status NOT NULL DEFAULT 'Draft',
    -- 'Draft' | 'InAIReplication' | 'ReplicatedByAI' | 'ReplicationFailed'
    -- | 'InManualReplication' | 'Reproduced' | 'CannotReproduce' | 'Triaged'
  severity_estimate severity_level,  -- Stakeholder's estimate
  ai_detected_severity severity_level, -- post-replication
  affected_users_estimate INT,       -- null = unknown
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  triaged_at TIMESTAMPTZ,
  backlog_item_id UUID REFERENCES backlog_items(id) ON DELETE SET NULL
);

CREATE TYPE severity_level AS ENUM ('Low', 'Medium', 'High', 'Critical');
CREATE TYPE rsd_status AS ENUM (
  'Draft', 'InAIReplication', 'ReplicatedByAI', 'ReplicationFailed',
  'InManualReplication', 'Reproduced', 'CannotReproduce', 'Triaged'
);

CREATE INDEX idx_rsds_status ON rsds(status) WHERE status != 'Triaged';
CREATE INDEX idx_rsds_request ON rsds(request_id);
```

### 2.2 `rsd_versions`

```sql
CREATE TABLE rsd_versions (
  rsd_id UUID NOT NULL REFERENCES rsds(id) ON DELETE CASCADE,
  version INT NOT NULL,
  content_snapshot JSONB NOT NULL,
    -- { environment: {...}, expected: str, actual: str, repro_steps: [str], severity_rationale: str }
  edited_by UUID REFERENCES users(id),
  edited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (rsd_id, version)
);
```

### 2.3 `replication_attempts`

```sql
CREATE TABLE replication_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rsd_id UUID NOT NULL REFERENCES rsds(id) ON DELETE CASCADE,
  attempt_number INT NOT NULL,       -- 1-indexed
  kind attempt_kind NOT NULL,        -- 'AI' | 'Manual'
  actor_id UUID REFERENCES users(id), -- null for AI attempts
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ,
  result attempt_result,             -- NULL while in progress
    -- 'Success' | 'Failure' | 'Partial' | 'CannotReproduce'
  strategies_used TEXT[],            -- e.g., ['sandbox_spin_up', 'test_harness', 'log_query']
  evidence_refs JSONB,               -- [{type: 'log'|'screenshot'|'video'|'trace', s3_url: str}]
  reasoning TEXT,                    -- AI's explanation or human's notes
  cost_cents INT,                    -- AI attempts only; links to llm_cost_entries
  llm_cost_entry_id UUID REFERENCES llm_cost_entries(id)
);

CREATE TYPE attempt_kind AS ENUM ('AI', 'Manual');
CREATE TYPE attempt_result AS ENUM ('Success', 'Failure', 'Partial', 'CannotReproduce');

CREATE INDEX idx_repl_rsd ON replication_attempts(rsd_id, attempt_number);
```

### 2.4 `bug_reports` (from UAT)

```sql
CREATE TABLE bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source bug_source NOT NULL,         -- 'Stakeholder' | 'UAT' | 'Support' | 'Internal'
  source_uat_run_id UUID REFERENCES uat_runs(id),  -- if source=UAT
  request_id UUID REFERENCES requests(id),         -- if source=Stakeholder (via [B01])
  title TEXT NOT NULL,
  description TEXT,
  submitter_id UUID NOT NULL REFERENCES users(id),
  severity severity_level NOT NULL,
  created_rsd_id UUID REFERENCES rsds(id),         -- created by SubmissionSvc/UATSvc
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TYPE bug_source AS ENUM ('Stakeholder', 'UAT', 'Support', 'Internal');
```

## 3. AI Replication mechanism (closes OL-B2)

### 3.1 Strategies (tiered)

The `AI.BREP` agent attempts in order of cheapness, stopping as soon as one succeeds.

| Tier | Strategy | Cost (avg) | Latency | When to skip |
|---|---|---|---|---|
| 1 | **Log query** — search structured logs for the error pattern | $0.005 | 500ms | No log source configured |
| 2 | **Trace replay** — find OpenTelemetry traces matching the scenario | $0.02 | 3s | No tracing |
| 3 | **Test harness** — execute the repro_steps via headless browser / API client in dev env | $0.10 | 30s–5min | No test harness registered |
| 4 | **Sandbox spin-up** — provision an ephemeral environment matching user's context | $2–5 | 2–10min | Cost cap exceeded |
| 5 | **LLM-only inference** — ask the model to reason about likely root cause | $0.03 | 5s | Fallback always available |

Each attempt produces a `replication_attempt` row. Evidence is stored in S3 under `replication-evidence/{rsd_id}/{attempt_id}/`.

### 3.2 Cost cap

- Per-attempt cap: `platform_config.bug_replication_cost_cap_cents` (default **500¢ = $5**)
- Per-RSD cap: default **3 AI attempts** before falling back to human
- Per-month budget: integrated with `LLMCostSvc` quota

If cost cap exceeded mid-attempt, the attempt aborts, logs `strategies_used` up to that point, returns `Failure` with reasoning "cost cap reached — hand to QA".

### 3.3 Output contract

Every `AI` attempt MUST produce:

```json
{
  "attempt_id": "uuid",
  "result": "Success | Failure | Partial | CannotReproduce",
  "strategies_used": ["log_query", "trace_replay"],
  "evidence_refs": [
    { "type": "log", "s3_url": "..." },
    { "type": "trace", "s3_url": "..." },
    { "type": "screenshot", "s3_url": "..." }
  ],
  "reasoning": "Reproduced in sandbox: step 3 returned 500 because X. See trace for root cause.",
  "severity_assessment": {
    "severity": "High",
    "confidence": 0.85,
    "affected_users_estimate": 4200
  },
  "suggested_fix_hint": "likely in PaymentRetrySvc.checkTaxApplicability()"
}
```

### 3.4 Success criteria — when is "replicated"?

- Tier 1/2: match rate ≥ 0.8 between RSD repro_steps and found log pattern/trace
- Tier 3: test harness reproduces the exact error message or status code
- Tier 4: sandbox reproduces the user-described symptom (AI judges similarity)
- Tier 5: never counted as "Success" — always `Partial` at best (AI reasoning without execution)

### 3.5 Failure modes

- **Environment divergence**: test harness can't access user-specific data → `Failure, reasoning="sandbox lacks user-scoped state"`
- **Non-deterministic**: first attempt succeeds, retry fails → flagged as flaky; escalate severity
- **External dependency down**: Stripe sandbox returning different state → log, mark `Partial`, recommend manual
- **Timeout**: attempt exceeds 10-minute wall clock → abort, `Failure`

## 4. Bug-Triage Agent architecture (closes OL-B7)

### 4.1 Which agent generates the RSD?

**Decision:** A dedicated **`AI.RSD`** agent (not the same as `AI.PRD`).

Reasoning:
- PRD agent is optimised for feature specification, not incident analysis
- RSD structure is fundamentally different (environment + expected + actual + repro_steps + severity_rationale)
- Different prompt template; different training data; different cost profile (shorter context usually)
- Better auditability: `LLMInvocationEvt.agent_code = 'AI.RSD'` is distinct in `[Z01]` cost breakdown

### 4.2 Cost profile

| Agent | Typical tokens in | Typical tokens out | Avg cost per invocation |
|---|---|---|---|
| `AI.RSD` (initial draft) | 3–8k | 1–2k | $0.05 |
| `AI.RSD` (clarifying turn) | 10–15k | 0.5–1k | $0.08 |
| `AI.BREP` (tier 1–3) | 4–10k | 1–2k | $0.03–0.10 |
| `AI.BREP` (tier 4 sandbox spin-up) | 8–20k | 1–3k + compute | $2–5 |

Daily budget alert if bug-pipeline agents exceed **$50/day** without proportional bug volume.

### 4.3 Shared context between agents

`AI.RSD` and `AI.BREP` both read the same `rsds.current_version` snapshot. `AI.BREP` additionally reads `replication_attempts` history so it doesn't repeat failed strategies.

`AI.TST` (the UAT Test Agent) is shared between `[E02]` UAT and Manual Replication — same agent code, same prompt family; called with different context wrapper.

## 5. Screen specifications (detailed — for implementation)

### 5.1 Bug Workspace

See also: `_HANDOFF_CLAUDE_DESIGN/Regeneration_Prompts.md` §2.1 for the generation prompt.

**Route:** `/bugs/{rsd_id}`
**Guards:** `[H.STK]` if submitter; `[H.QA]` / `[H.EL]` always; others via explicit share

**Layout:**
- 3-panel (match `[B02]` pattern): Brief | `AI.RSD` chat | Live RSD
- Top header: breadcrumb + "Mark for AI Replication" primary CTA + status pill
- Left: Bug Brief + Environment block + Attachments + Severity estimate
- Middle: `AI.RSD` conversation (same primitive as `[B02]`)
- Right: Live RSD document with 5 sections (Environment / Expected / Actual / Repro Steps / Severity Rationale)

**API endpoints:**
```
GET    /api/rsds/{id}
POST   /api/rsds/{id}/messages      → appends to AI.RSD conversation
POST   /api/rsds/{id}/sections/{s}  → edit a section manually
POST   /api/rsds/{id}/submit-for-replication  → transitions to InAIReplication
```

**Events produced:**
- `RSDVersionCreatedEvt`
- `RSDSubmittedForReplicationEvt`

### 5.2 Bug Replication Result

**Route:** `/bugs/{rsd_id}/replication-result` (or shown as overlay on Bug Workspace)
**Guards:** same as Bug Workspace

**Layout — STATE A (Replicated by AI):**
- Emerald pill "Replicated by AI ✓"
- Hero card: checkmark + confirmation + stats (attempts, time, cost)
- Evidence grid: Run Log (timeline), Evidence Artifacts (chips), Environment Used
- CTAs: "Continue to Triage" (primary) + "Edit RSD" + "View Backlog Item"

**Layout — STATE B (Replication Failed):**
- Amber pill "Replication Failed"
- Hero: warning + explanation + stats
- "Why it failed" section: bulleted reasons from AI
- CTAs: "Hand to QA for Manual Replication" (primary) + "Re-run with hints" + "Edit RSD"

**API endpoints:**
```
GET    /api/rsds/{id}/replication-attempts
POST   /api/rsds/{id}/trigger-replication
POST   /api/rsds/{id}/hand-to-qa           → creates manual_replication assignment
```

### 5.3 Manual Bug Replication

**Route:** `/bugs/{rsd_id}/manual-replication`
**Guards:** `[H.QA]` or `[H.EL]`

**Layout:** mirror `[E02]` UAT Testing structure
- Left (55%): RSD Reference (accordion) + AI Attempt Log (accordion) + Replication Outcome radio + Findings (rich text) + Evidence Upload
- Right (45%): `AI.TST` chat suggesting diagnostics

**API endpoints:**
```
POST   /api/rsds/{id}/manual-attempts      → creates Manual replication_attempt
POST   /api/rsds/{id}/manual-attempts/{aid}/outcome  → sets result + findings
POST   /api/rsds/{id}/triage                → moves RSD to Triaged status, creates backlog_item
```

### 5.4 Bug Triage Queue

**Route:** `/bugs`
**Guards:** `[H.EL]` or `[H.QA]` lead role

**Layout:** mirror `[B05]` PRD Evaluation queue
- Top tabs: Triage Queue (active) / In Manual Replication / Resolved / Cannot Reproduce
- Filter bar: Severity / Status / Source / Age
- Table columns: checkbox, title, bug_id, severity (pill), status, AI replication result (icon), submitter, submitted, assigned engineer
- Right slide-out: bug summary, Open RSD link, sections, actions (Promote to Backlog / Reassign / Close as Cannot Reproduce)

**API endpoints:**
```
GET    /api/bugs?filter=...
POST   /api/bugs/{id}/assign
POST   /api/bugs/{id}/promote-to-backlog  → creates backlog_items (Type=Bug) with bug_severity_score
POST   /api/bugs/{id}/close                → closes as Cannot Reproduce; notifies Stakeholder
```

## 6. Event flow for the bug pipeline

```
[B01] submit (type=Bug)
  └─► RequestSubmittedEvt
        └─► SubmissionSvc routes to RSDSvc
        └─► RSDSvc.createFromBrief
              └─► RSDVersionCreatedEvt v1
              └─► AI.RSD invoked (LLMInvocationEvt)

[Bug Workspace] user marks for replication
  └─► RSDSubmittedForReplicationEvt
        └─► BugReplicationSvc.orchestrate
              ├─► AI.BREP tier 1 attempt (LLMInvocationEvt)
              ├─► AI.BREP tier 2 attempt (LLMInvocationEvt)
              ├─► ...
              └─► BugReplicationResultEvt (Success | Failure)
                    ├── Success ──► RSDSvc.markReplicatedByAI
                    └── Failure ──► RSDSvc.markReplicationFailed

[Replication Result] user clicks "Hand to QA"
  └─► RSDHandedToQAEvt
        └─► NotificationSvc alerts QA lead
        └─► RSDSvc.markInManualReplication

[Manual Replication] QA submits outcome
  └─► ManualReplicationCompletedEvt
        ├── Reproduced ──► RSDSvc.markReproduced
        └── CannotReproduce ──► RSDSvc.markCannotReproduce

[Any reproduced state] QA/EL clicks "Triage"
  └─► RSDTriagedEvt
        └─► BacklogSvc.createBug
              ├─► BugSeverityComputedEvt (score algorithm from §01)
              └─► BacklogItemCreatedEvt (Type=Bug)
                    └─► ... standard backlog flow
```

## 7. Test scenarios

| Scenario | Expected path | States produced |
|---|---|---|
| Happy path: stakeholder submits bug, AI replicates, gets triaged | B01→Bug Workspace→AI attempt 1 success→Triage | RSD: Draft→InAIReplication→ReplicatedByAI→Triaged |
| AI fails all 3 attempts, human reproduces | B01→Bug Workspace→3 failures→Manual→Reproduced→Triage | RSD: Draft→InAIReplication→ReplicationFailed→InManualReplication→Reproduced→Triaged |
| Neither AI nor human can reproduce | ...→Manual→CannotReproduce→Triage (flagged) | RSD: ...→InManualReplication→CannotReproduce→Triaged; BugSeverity may be reduced automatically |
| Cost cap hit mid-sandbox | AI attempts tier 1/2/3, skips 4 | Partial evidence; human fallback |
| UAT bug filed during [E02] | UAT form→createBug→createRSD→enters Bug Workspace | Same as stakeholder-originated bug with source=UAT; source_boost adds 10 to severity |

## 8. Open questions for roadmap (not blocking v1 build)

- Should duplicate bugs (same root cause) share a single RSD? Recommended: **yes, via `SimilaritySvc`** — surface "this looks like RSD-042, merge?" at intake
- Sandbox tier: build in-house or integrate a vendor (e.g., existing staging env orchestration)? Vendor recommended for v1
- Should Stakeholder see AI attempt progress live? Recommended: **yes, via `[B03]` activity timeline** (new events: `ReplicationAttemptStartedEvt` + `ReplicationAttemptFinishedEvt` → Stakeholder notifications on opt-in)

---

*See `04_Database_Schema.sql` for full DDL, `05_API_and_Events.md` for endpoint and event schemas, `01_Algorithms.md` §2 for Bug Severity Score.*

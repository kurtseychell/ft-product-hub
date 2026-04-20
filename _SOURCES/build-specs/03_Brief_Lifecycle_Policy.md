# Brief Lifecycle Policy

Covers the Brief version lifecycle, PM review lock semantics, Stakeholder supersession UX, and visible affordances. Closes **OL-B1**, **OL-B8**.

---

## 1. States

```
┌─────────────────┐    Stakeholder submits
│  v1 Draft       │ ─────────────────────────┐
│  (editable)     │                          │
└─────────────────┘                          ▼
                                   ┌──────────────────┐
                                   │  v1 Submitted    │
                                   │  (still editable │
                                   │   by Stakeholder │
                                   │   until review)  │
                                   └────────┬─────────┘
                                            │
                             PM opens review in [B02]
                                            │
                                            ▼
                                   ┌──────────────────┐
                                   │  v1 Locked       │
                                   │  for Review      │
                                   │  (Stakeholder:   │
                                   │   read-only)     │
                                   └────────┬─────────┘
                                            │
                              ┌─────────────┴─────────────┐
                              │                           │
                         PM edits PRD              Stakeholder forks
                         (normal flow)             ┌────────────────┐
                                                   │  v2 Draft      │
                                                   │  (Stakeholder  │
                                                   │   editable)    │
                                                   └────────┬───────┘
                                                            │
                                                  Stakeholder submits v2
                                                            │
                                                            ▼
                                                   ┌────────────────┐
                                                   │  v2 Submitted  │
                                                   │  (parallel to  │
                                                   │   v1's review) │
                                                   └────────┬───────┘
                                                            │
                                            Stakeholder chooses:
                                            ┌───────────────┴────────────────┐
                                            │                                 │
                              "Supersede v1 review?"              "Keep v1 review running"
                                            │                                 │
                                            ▼                                 ▼
                                  ┌──────────────────┐             ┌──────────────────┐
                                  │ v1 Superseded    │             │ Both versions    │
                                  │ (review closes)  │             │ coexist; v2      │
                                  │ v2 Locked        │             │ waits until v1   │
                                  │ for Review       │             │ review closes    │
                                  └──────────────────┘             └──────────────────┘
```

### 1.1 State values (as stored)

```sql
CREATE TYPE brief_lock_status AS ENUM (
  'Editable',        -- Draft; Stakeholder can edit
  'Submitted',       -- Submitted; Stakeholder still owns edits until review starts
  'LockedForReview', -- PM review active; Stakeholder read-only
  'Superseded'       -- Replaced by a newer version
);
```

## 2. Transition rules

### 2.1 `Draft → Submitted`
Triggered by `[B01]` "Submit & Open PRD Builder" click.
- Runs intake validation (title length, brief length > 50 chars, type selected)
- Emits `RequestSubmittedEvt` + `BriefSubmittedEvt`
- Creates PRD draft via `PRDSvc.initializeFromBrief` OR RSD draft via `RSDSvc.initializeFromBrief` (type-dependent)

### 2.2 `Submitted → LockedForReview`
Triggered **automatically** when the PRD or RSD moves to `In Review` status (via `[B02]` / Bug Workspace lock event or `[B05]` evaluator assignment — whichever comes first).
- Emits `BriefLockedEvt { brief_id, version, trigger: 'PRDReviewStarted' | 'EvaluationAssigned' }`
- Stakeholder sees lock badge on `[B03]`
- Stakeholder's edit endpoints return `409 LockedForReview`

### 2.3 `LockedForReview → Draft (v(N+1))`
Triggered by Stakeholder creating a new version via `[B03]` UI "Edit Brief" action.
- Creates new `brief_versions` row with version = N+1, status = `Editable`
- Original vN remains `LockedForReview` (unchanged)
- Emits `BriefVersionForkedEvt { brief_id, old_version: N, new_version: N+1 }`

### 2.4 v(N+1) Submitted → supersession decision
Triggered when Stakeholder clicks "Submit" on v(N+1).
- UI prompt: "Supersede the current PRD review on v{N}?"
- If **Yes** → emit `BriefSupersededEvt`; vN → `Superseded`; v(N+1) enters `LockedForReview`; in-flight PRD review on vN is **cancelled** with a notification to the reviewer ("Stakeholder submitted v{N+1}; PRD review on v{N} has been cancelled")
- If **No** → v(N+1) waits; status stays `Submitted` until vN's review concludes; then v(N+1) auto-transitions to `LockedForReview` via event chain

## 3. UX for supersession prompt

Triggered at v(N+1) submit time on `[B03]` (or `[B01]` if Stakeholder started v(N+1) from there).

### 3.1 Modal content

```
Title: "Your new version is ready"

Body:
  You've prepared v{N+1} of your Brief. There's currently a PRD review
  running on v{N} (assigned to {reviewer_name}, started {relative_time}).

Two options:

  [OPTION A] Supersede v{N}
    Cancel the current review. v{N+1} becomes the active version and
    enters review instead.
    {reviewer_name} will be notified.

  [OPTION B] Keep v{N}'s review running
    v{N+1} will wait. When v{N}'s review concludes, v{N+1} will
    automatically take over.

  [button: Supersede v{N}]   [button: Keep v{N}'s review running]   [button: Cancel]
```

Default focus: **"Keep v{N}'s review running"** (safer — no work lost).

### 3.2 Stakeholder can change their mind

Both options are reversible as long as v(N)'s review is still in-flight. The Stakeholder can, via `[B03]`:
- Manually supersede later ("Supersede now" CTA available while v(N+1) is queued)
- Un-supersede is NOT supported (once v(N) review is cancelled, it stays cancelled — start a fresh review if needed)

## 4. Visible affordance — Brief lock on `[B03]`

Closes OL-B8.

### 4.1 Status chip location
In the Request Lifecycle Pipeline stepper on `[B03]`, add a secondary chip below the "PRD Review" step:

```
┌──────────────────────┐
│ ● PRD Review         │  ← current step (indigo)
│   Assigned: S. Chen  │
│   ┌────────────────┐ │
│   │ 🔒 Brief v3    │ │  ← new sub-chip
│   │    Locked      │ │
│   └────────────────┘ │
└──────────────────────┘
```

### 4.2 Chip states

| Brief status | Chip text | Icon | Colour |
|---|---|---|---|
| `Editable` | "Brief v{N} — Draft" | pencil | slate |
| `Submitted` (pre-lock) | "Brief v{N} — Submitted" | check | emerald |
| `LockedForReview` | "Brief v{N} — Locked for Review" | lock | amber |
| `Superseded` | "Brief v{N} — Superseded by v{N+1}" | archive | slate |

### 4.3 Click behaviour

Clicking the chip opens a popover:

- State `LockedForReview`:
  - Text: "This version is under review. You can create a new version to propose changes."
  - CTA: "Create v{N+1}"

- State `Superseded`:
  - Text: "v{N} was replaced by v{N+1} on {date}."
  - Link: "View v{N}" (read-only view)

- State `Submitted`:
  - Text: "Your brief is submitted and is waiting for review."
  - CTA: "Edit before review starts" (only enabled if no reviewer yet)

## 5. Concurrent edits — conflict handling

### 5.1 Same Stakeholder, multiple tabs
Pessimistic UI: when a Brief edit session is opened in one tab, other tabs show a banner "You have this Brief open in another tab — close it there to edit here". Enforced via a Redis lock keyed on `brief:{id}:v{n}:editor`. Lock TTL 2min; renewed on activity.

### 5.2 Stakeholder edits vN while PM is reviewing
Impossible because vN is `LockedForReview`. Stakeholder must fork v(N+1).

### 5.3 Two Stakeholders on same Request
Not supported in v1. Requests are single-submitter. If multi-submitter support comes in v2, Briefs would need `co_authors[]` — new schema.

### 5.4 PM deletes a PRD mid-review (shouldn't happen, but...)
PRD deletion is soft (status → `Archived`). Brief lock status unchanged. When PRD is archived, `BriefUnlockedEvt` fires? Decision: **no** — archiving is rare and operator-driven. Surface a banner on `[B03]` "This review was abandoned. Contact your PM." and let humans handle.

## 6. Events

```typescript
BriefVersionCreatedEvt: {
  brief_id: uuid;
  request_id: uuid;
  version: int;
  author_id: uuid;
  // Fires on Draft creation (v1 or v(N+1))
}

BriefSubmittedEvt: {
  brief_id: uuid;
  version: int;
  submitter_id: uuid;
  content_hash: string;  // so downstream can verify it saw the exact submitted version
}

BriefLockedEvt: {
  brief_id: uuid;
  version: int;
  trigger: 'PRDReviewStarted' | 'EvaluationAssigned' | 'AutoLockOnReviewStart';
  locked_at: timestamp;
}

BriefVersionForkedEvt: {
  brief_id: uuid;
  from_version: int;
  new_version: int;
  forked_by: uuid;
}

BriefSupersededEvt: {
  brief_id: uuid;
  from_version: int;
  superseded_by_version: int;
  decided_by: uuid;
  cancelled_review_id: uuid?;  // if an in-flight review was cancelled
}
```

## 7. API endpoints

```
GET    /api/briefs/{id}?version=N           → read specific version (authz: current or Superseded are public to submitter; Locked is also readable)
GET    /api/briefs/{id}/versions            → list all versions with status
POST   /api/requests/{req_id}/briefs/versions  → creates new Draft (v(N+1))
PATCH  /api/briefs/{id}/versions/{v}         → edit Draft content; 409 if not Editable
POST   /api/briefs/{id}/versions/{v}/submit  → transition Draft → Submitted; returns supersession prompt data if applicable
POST   /api/briefs/{id}/versions/{v}/supersede-prior  → confirm supersession (idempotent)
```

## 8. Test scenarios

| Scenario | Expected |
|---|---|
| Stakeholder submits, PM opens [B02] | Brief → LockedForReview; lock badge visible on [B03]; Stakeholder gets notification (in-app "Review started") |
| Stakeholder tries to edit vN after lock | API 409; UI shows "Brief locked. Create a new version?" |
| Stakeholder creates v2, submits, chooses Supersede | vN → Superseded; reviewer notified; review cancelled; v2 → LockedForReview; Lifecycle Pipeline updates |
| Stakeholder creates v2, submits, chooses Keep | v2 → Submitted (waiting); banner on [B03] "v2 is queued — will auto-enter review after v1 completes" |
| v1 review completes (any outcome), v2 queued | v2 auto-transitions LockedForReview; PM is assigned; notification fires |
| Stakeholder tries to supersede after v1 review already complete | No-op; UI already shows v2 as active version |
| Race: Stakeholder submits v2 same moment PM submits v1 evaluation | Transactional: whichever Postgres commits first wins. If evaluation wins, v2 enters queue; if v2 wins, evaluation is rejected with 409 and reviewer prompted to restart on v2 |

## 9. Platform config

```yaml
brief_lifecycle:
  lock_trigger: "pm_opens_builder" | "evaluator_assigned"  # default: pm_opens_builder
  default_supersession_choice: "keep_running" | "supersede"  # default: keep_running
  edit_session_lock_ttl_sec: 120
  max_pending_versions: 3   # cap on how many v(N+1) can queue behind a running review
```

## 10. Observability

- `BriefLockedEvt.trigger` histogram → which path dominates (PM-first vs. evaluator-first)
- Rate of v(N+1) forks per Request → UX signal; if >15%, Briefs are getting too much back-and-forth
- Time from `BriefLockedEvt` to `PRDEvaluatedEvt` → reviewer throughput
- Rate of supersessions vs. "keep running" → UX signal; if supersession dominates, the default choice is wrong

---

*See `04_Database_Schema.sql` §briefs for DDL, `05_API_and_Events.md` §events for full event envelope schemas.*

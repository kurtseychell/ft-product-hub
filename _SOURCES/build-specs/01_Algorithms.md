# Algorithms

Four production algorithms. Each has: purpose, inputs, outputs, formula/pseudocode, edge cases, test cases, observability hooks.

Closes **OL-5**, **OL-B3**, **OL-B6** from `../User_Journey_Flow.md`.

---

## 1. Submission Score

**Purpose.** Signal to Product team whether a PRD is ready for their review. Visible in `[B02]` header and `[B03]` tracking. Must pass a configurable threshold (default **80/100**) before "Mark as Final" is enabled.

### Inputs

| Input | Source | Type | Range |
|---|---|---|---|
| `prd.current_version` | `prds` | JSONB (parsed sections) | — |
| `prd.conversation_jsonb` | `prds` | JSONB (chat turns) | — |
| `prd.ai_section_confidences` | per-section confidence from `AI.PRD` | `Map<section_id, 0..1>` | 0–1 per section |
| `prd.attachments_count` | `attachments` join | integer | ≥ 0 |
| `prd.linked_research_refs` | `research_sessions.attached_to_prd` | array | — |
| `platform_config.submission_score_weights` | `platform_settings` | `{completeness, depth, specificity, ai_confidence}` | sum = 1.0 |
| `platform_config.required_sections` | `platform_settings` | array of section_ids | — |

### Output

```typescript
type SubmissionScore = {
  total: number;              // 0–100 integer
  components: {
    completeness: number;     // 0–100
    depth: number;            // 0–100
    specificity: number;      // 0–100
    ai_confidence: number;    // 0–100
  };
  blockers: string[];         // human-readable reasons score is held below threshold
  updated_at: string;         // ISO timestamp
};
```

### Formula

```
total = round(
  weights.completeness  × score_completeness  +
  weights.depth         × score_depth         +
  weights.specificity   × score_specificity   +
  weights.ai_confidence × score_ai_confidence
)
```

Default weights: `{completeness: 0.6, depth: 0.2, specificity: 0.1, ai_confidence: 0.1}`.

### Component algorithms

**1.1 Completeness (60% of total by default)**

```
required = platform_config.required_sections
// default: ['problem_statement', 'target_users', 'functional_requirements',
//           'data_schema', 'edge_cases', 'success_metrics', 'future_iterations']

present = required.filter(s =>
  prd.current_version.sections[s] != null &&
  prd.current_version.sections[s].text.length > 50  // minimum body
)

score_completeness = round(100 × present.length / required.length)
```

Edge cases:
- Section present but body ≤50 chars → counted as missing
- Section present with only headers (no prose) → counted as missing (detector: strip all `#` lines, check remaining length)

**1.2 Depth (20%)**

Per section, expected word count from platform config. Default targets:

| Section | Min words | Ideal words |
|---|---|---|
| problem_statement | 80 | 200 |
| target_users | 60 | 150 |
| functional_requirements | 150 | 500 |
| data_schema | 50 | 200 |
| edge_cases | 60 | 200 |
| success_metrics | 40 | 150 |
| future_iterations | 40 | 150 |

```
section_depth(s) =
  if s.word_count < min then 0
  else if s.word_count >= ideal then 100
  else round(100 × (s.word_count - min) / (ideal - min))

score_depth = average(section_depth(s) for s in present_sections)
```

**1.3 Specificity (10%)**

Per-section entity extraction. Counts concrete signals that distinguish a real spec from vague prose.

```
signals per section = count of:
  - numbers (/\b\d[\d,.]*\b/)
  - dates (ISO or "Month YYYY" patterns)
  - named systems (capitalised multi-word entities, curated allowlist from platform_config.known_systems — e.g., "Stripe", "Adyen", "Redis")
  - attachment refs (inline [file: xxx])
  - research refs (inline [research: session_id])

section_specificity(s) =
  if signals >= 5 then 100
  else round(100 × signals / 5)

score_specificity = average(section_specificity(s) for s in present_sections)
```

**1.4 AI Confidence (10%)**

```
score_ai_confidence = round(100 × average(prd.ai_section_confidences.values()))
```

When a section has been edited by a human since AI last touched it, its confidence is **frozen at the AI value** — human edits don't change AI confidence (they may improve other components).

### Blockers

If `total < threshold`, emit blockers. Order by highest-leverage first:

```
blockers = []
for s in required:
  if not present(s): blockers.push(`§${s} is missing`)
  elif word_count(s) < min: blockers.push(`§${s} needs depth (${word_count}/${min} words)`)
for s in present:
  if ai_confidence[s] < 0.6: blockers.push(`§${s} has low AI confidence — review suggested`)
```

Return top 5.

### Recomputation triggers

- On every `PRDVersionCreatedEvt` (any change to PRD body)
- On every `LLMInvocationEvt` for `AI.PRD` (agent may have updated confidences)
- Debounced to 2s (don't recompute per keystroke)

Cached in Redis with key `prd:score:{prd_id}` TTL 60s. Authoritative value in `prds.submission_score` column refreshed on version save.

### Test cases

| Scenario | Expected |
|---|---|
| Empty PRD (no sections) | total=0, blockers list all 7 required |
| All sections at exactly `min` words | total ~= 60×(100) + 20×(0) + 10×(based on signals) + 10×(based on AI conf) ≈ 62–70 |
| All sections at ideal, AI confidence avg 0.9 | total ≥ 90 |
| One required section missing | completeness drops to round(100 × 6/7) = 86, total reduced by (1/7)×60 = 8.6 |
| Rich text pasted without prose (just tables) | depth scored by word count — may be unfairly low; flag for review |

### Observability
- Emit `SubmissionScoreComputedEvt { prd_id, total, components, duration_ms }` for every computation
- Log ratio: computations / `PRDVersionCreatedEvt` (should be ≤ 1.0)
- Alert if `duration_ms.p95 > 200ms` (this is a synchronous UI blocker)

---

## 2. Bug Severity Score

**Purpose.** Replace standard RICE for Type=Bug backlog items. Feature RICE agents (`AI.RICE.*`) do not apply to bugs — different prioritization model. Visible on `[D01]` Kanban cards and Bug Triage Queue.

Closes **OL-B3**.

### Inputs

| Input | Source | Type |
|---|---|---|
| `rsd.reproduction_confirmed` | RSD status | boolean |
| `rsd.severity_estimate` | Stakeholder input at `[B01]` (Low/Med/High/Critical) | enum |
| `rsd.ai_detected_severity` | `AI.BREP` post-replication (may differ from estimate) | enum |
| `rsd.affected_users_estimate` | `AI.BREP` estimate from logs or Stakeholder input | integer |
| `bug.source` | UAT / Stakeholder | enum |
| `bug.business_impact` | Free-text + AI categorisation | enum (None/Low/Medium/High) |

### Output

```typescript
type BugSeverityScore = {
  total: number;       // 0–100, higher = more urgent
  severity_factor: number;   // 1,2,3,5,8
  reach_multiplier: number;  // 1–10 based on log(users/100)
  source_boost: number;      // 0 or +10
  business_boost: number;    // 0 to +15
  confidence: 'High' | 'Medium' | 'Low';  // AI-estimated confidence
};
```

### Formula

```
severity_factor = {Low: 1, Medium: 2, High: 5, Critical: 8}[
  max(rsd.severity_estimate, rsd.ai_detected_severity)
]

// Reach (log-scaled so 10k vs 100k users doesn't dwarf everything else)
reach_multiplier = max(1, min(10, ceil(log10(max(affected_users, 1)) × 2.5)))

base = severity_factor × reach_multiplier

// Boosts
source_boost = (bug.source === 'UAT' ? 0 : 10)    // external bugs get +10
business_boost = {None: 0, Low: 5, Medium: 10, High: 15}[bug.business_impact]

total = min(100, base × 100/80 + source_boost + business_boost)
```

Where `80 = max(severity_factor) × max(reach_multiplier) = 8 × 10`, normalising `base` to 100 before boosts.

Confidence is `AI.BREP`'s confidence in the severity estimate (defaults to `Medium` if no AI intervention yet).

### Examples

| Scenario | severity_factor | reach | base | boosts | total |
|---|---|---|---|---|---|
| Critical bug, 50k users, external, high business | 8 | 10 | 80 | +10+15 | 100 (capped) |
| High bug, 5k users, UAT-only, medium business | 5 | 8 | 40 | +0+10 | 60 |
| Medium bug, 500 users, UAT, low business | 2 | 5 | 10 | +0+5 | 17 |
| Low bug, 1 user (stakeholder report), no business impact | 1 | 1 | 1 | +10+0 | 11 |

### Recomputation triggers

- On `BugReplicationResultEvt` (AI may have adjusted severity/affected_users)
- On manual override in Bug Triage Queue (human adjusts severity)

Persisted in `backlog_items.bug_severity_score` (for Type=Bug rows only).

### Test cases

| Input | Expected |
|---|---|
| severity=Critical, users=10k, source=external, biz=High | total=100 (cap) |
| severity=Low, users=1, source=UAT, biz=None | total=1 |
| severity=High, users=0 | reach=1, base=5, total≈6 (reach floor protects against /0) |

### Observability
- `BugSeverityComputedEvt { rsd_id, total, inputs }` per computation
- Alert if total changes by >30 points between recomputations (suggests noisy inputs)

---

## 3. RICE Consensus

**Purpose.** Combine 3 council agents' independent R/I/C/E assessments into a single aggregate + confidence range. Visible in `[C02]` aggregate banner, `[D01]` card badge, `[D02]` comparison.

### Inputs

Per agent (`AI.RICE.M`, `AI.RICE.T`, `AI.RICE.B`):

```typescript
type AgentAssessment = {
  reach: number;       // users affected (count)
  impact: number;      // 0.25, 0.5, 1, 2, 3 (minimal to massive)
  confidence: number;  // 0–1
  effort: number;      // person-months, positive
  commentary: string;
  self_confidence: number;  // 0–1 — how certain is the agent in its own numbers?
};
```

### Output

```typescript
type RICEConsensus = {
  aggregate_score: number;            // 0–100
  consensus_RICE: { R, I, C, E };     // weighted averages
  confidence_range: [low, high];     // 80% interval in aggregate_score units
  divergence_flags: string[];        // dimensions where agents disagreed
};
```

### Formula

```
// For each dimension d ∈ {R, I, C, E}:
weights = [1/3, 1/3, 1/3]   // equal unless platform_config overrides
consensus[d] = sum(agent[d] × weight × self_confidence) / sum(weight × self_confidence)

// Aggregate RICE formula (standard): R × I × C / E, then normalised
raw = (consensus.R × consensus.I × consensus.C) / max(consensus.E, 0.1)

// Normalise to 0–100: log-scale then clamp
// Calibration: a raw of 100 → score 20; raw of 10000 → score 80
aggregate_score = round(max(0, min(100,
  20 × log10(max(raw, 1)) / log10(100)
  // Simpler approximation that's easier to calibrate; details in platform_config
)))

// Divergence detection — per dimension
for d in [R, I, C, E]:
  values = [agent.d for agent in agents]
  range = max(values) - min(values)
  if range / mean(values) > 0.5:   // coefficient of variation >50%
    divergence_flags.push(d)

// Confidence range — Monte Carlo or analytic
// Sample 1000 times from each agent's uncertainty (triangular distribution ±20% around their number)
// Compute aggregate_score for each sample
// Return 10th percentile, 90th percentile
```

Divergence flags mean "council doesn't agree; human review recommended." Surface in UI as an amber badge.

### Recomputation triggers

- On any `LLMInvocationEvt` from one of the 3 council agents (re-run council if one agent updates)
- On manual override — override does NOT recompute consensus; it *replaces* the displayed aggregate and logs to `rice_override_history`

### Test cases

| Scenario | Expected |
|---|---|
| 3 agents agree on R=10000, I=2, C=0.8, E=3 | agg ≈ 82; no divergence |
| Agents split on Effort (2, 5, 10) | divergence_flag includes 'E' |
| One agent has very low self_confidence | that agent's vote weights down |

### Observability
- `RICEConsensusComputedEvt { prd_id, aggregate, divergence_flags }`
- Track agent agreement rate over time (helps calibrate prompts)

---

## 4. Transformation Velocity

**Purpose.** Per-PRD metric shown in `[C03]` SpecKit footer: "X% Accurate to PRD". Measures how well the AI-generated spec set covers the PRD's requirements.

### Inputs

| Input | Source | Type |
|---|---|---|
| `prd.requirements_sections` | `prds` section `functional_requirements` parsed | list of requirement statements |
| `prd.edge_cases_section` | `prds` section `edge_cases` parsed | list of edge case statements |
| `spec_items[*].source_prd_sections` | `spec_items.source_prd_sections` | per-spec back-ref to PRD sections |
| `spec_items[*].content_rich` | `spec_items` | text content |

### Output

```typescript
type TransformationVelocity = {
  pct: number;                // 0–100
  covered_count: number;
  total_count: number;
  uncovered: { text: string, section: string }[];  // max 10 worst-covered
};
```

### Formula

```
requirements = prd.requirements_sections.statements ++ prd.edge_cases_section.statements
total_count = requirements.length

covered_count = 0
for req in requirements:
  req_embedding = embed(req.text)

  best_match_score = max(
    cosine_similarity(req_embedding, embed(spec.content_rich))
    for spec in spec_items
  )

  if best_match_score > 0.75:
    covered_count += 1
  else:
    uncovered.push({ text: req.text, section: req.section_name })

pct = round(100 × covered_count / max(total_count, 1))
```

Embedding via `X.LLM` (cached — requirements don't change without PRD version bump; specs don't change without `SpecItemVersionCreatedEvt`).

### Recomputation triggers

- On `SpecItemVersionCreatedEvt`
- On `PRDVersionCreatedEvt` (requirement set may have changed)

Cached at `prds.transformation_velocity_cache` with ref timestamps of last PRD + spec update.

### Test cases

| Scenario | Expected |
|---|---|
| PRD with 10 requirements, 10 specs each covering one | pct=100, uncovered=[] |
| PRD with 10 requirements, 5 specs covering 5 | pct=50, uncovered lists the 5 missing |
| PRD with 0 requirements (empty section) | pct=0 (or could define as 100 — UX decision: show "N/A" below threshold) |

### Observability
- `TransformationVelocityComputedEvt { prd_id, pct, total, covered }`
- Alert if pct drops >15 points after a spec edit (may indicate regression)

---

## Shared concerns

### Numeric precision
All scores are **integers 0–100**, not floats. Round at the final step; internal computation uses doubles.

### Performance budgets
- Submission Score: p95 ≤ 200ms (UI-blocking)
- Bug Severity: p95 ≤ 50ms (batch-friendly)
- RICE Consensus: p95 ≤ 300ms (acceptable; triggered on explicit action)
- Transformation Velocity: p95 ≤ 2s (async; background compute)

All embedding-based algorithms (§4) should use **batched** embedding calls to the LLM provider.

### Determinism
For Submission Score, Bug Severity, RICE Consensus — given same inputs, output must be byte-identical. No randomness. Makes them cache-friendly and test-stable.

For Transformation Velocity — embedding results are deterministic per model+seed. Pin the model version in `platform_config.embedding_model`.

### Platform config overrides
All weights, thresholds, and targets are readable from `platform_settings` with keys `algo.submission_score.*`, `algo.bug_severity.*`, `algo.rice_consensus.*`, `algo.transformation_velocity.*`. Changes emit `AlgorithmConfigChangedEvt` and trigger cache invalidation.

---

*See `../Component_Data_Architecture.md` §4 for service boundaries implementing these. See `05_API_and_Events.md` for endpoint shapes.*

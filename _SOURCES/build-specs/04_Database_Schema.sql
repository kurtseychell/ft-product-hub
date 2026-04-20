-- Product Hub — Canonical Database Schema
-- Postgres 16
-- Generated 2026-04-20
--
-- Source-of-truth derived from `../Component_Data_Architecture.md` §3 and canonical screens.
-- Companion docs: 01_Algorithms.md, 02_Bug_Pipeline_Specification.md, 03_Brief_Lifecycle_Policy.md
--
-- Design principles:
-- * Every versioned artifact uses a split primary+versions table pattern
-- * Append-only tables (audit_log, llm_cost_entries, prd_evaluations, rice_override_history) have no UPDATE permission at app level
-- * Row-Level Security enforces domain isolation (Domain Owners see their domain only unless elevated)
-- * All foreign keys ON DELETE policies chosen defensively: RESTRICT for hard parents, SET NULL for optional links, CASCADE only for true ownership hierarchies
-- * Every mutable table has a BEFORE UPDATE trigger to stamp updated_at
-- * Uses pgvector for similarity; pg_trgm for fuzzy match

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE user_role AS ENUM (
  'Stakeholder', 'ProductManager', 'ProductLead', 'DomainOwner',
  'EngineeringLead', 'QA', 'Admin', 'Viewer'
);

CREATE TYPE user_status AS ENUM ('Invited', 'Active', 'Suspended', 'Removed');

CREATE TYPE request_type AS ENUM ('NewIdea', 'ChangeRequest', 'Bug');
CREATE TYPE request_status AS ENUM (
  'Draft', 'Submitted', 'RequestReview', 'PRDBuilt', 'PRDReview',
  'RICEScoring', 'BacklogApproved', 'InDevelopment', 'Released',
  'Rejected', 'Cancelled'
);

CREATE TYPE brief_lock_status AS ENUM (
  'Editable', 'Submitted', 'LockedForReview', 'Superseded'
);

CREATE TYPE prd_status AS ENUM ('Draft', 'InReview', 'Approved', 'Final', 'Archived');

CREATE TYPE rsd_status AS ENUM (
  'Draft', 'InAIReplication', 'ReplicatedByAI', 'ReplicationFailed',
  'InManualReplication', 'Reproduced', 'CannotReproduce', 'Triaged'
);

CREATE TYPE severity_level AS ENUM ('Low', 'Medium', 'High', 'Critical');

CREATE TYPE attempt_kind AS ENUM ('AI', 'Manual');
CREATE TYPE attempt_result AS ENUM ('Success', 'Failure', 'Partial', 'CannotReproduce');

CREATE TYPE bug_source AS ENUM ('Stakeholder', 'UAT', 'Support', 'Internal');

CREATE TYPE evaluation_decision AS ENUM ('Approved', 'RevisionsRequested', 'Rejected');

CREATE TYPE research_mode AS ENUM ('QuickScan', 'Standard', 'DeepDive');
CREATE TYPE research_recommendation AS ENUM ('Pursue', 'Defer', 'Reject');

CREATE TYPE spec_type AS ENUM ('API', 'DataModel', 'UIComponent', 'BusinessLogic', 'Integration');
CREATE TYPE spec_status AS ENUM ('Draft', 'InReview', 'Approved', 'NeedsRevision');
CREATE TYPE ai_confidence AS ENUM ('High', 'Medium', 'Low');

CREATE TYPE design_style AS ENUM ('Wireframe', 'LowFidelity', 'HighFidelity');
CREATE TYPE design_status AS ENUM ('Generating', 'Draft', 'Reviewed', 'Approved', 'PushedToFigma');

CREATE TYPE backlog_item_type AS ENUM ('Feature', 'Bug');
CREATE TYPE backlog_status AS ENUM ('New', 'UnderReview', 'Approved', 'InDevelopment', 'Released', 'Archived');

CREATE TYPE delivery_state AS ENUM ('OnTrack', 'AtRisk', 'Blocked');

CREATE TYPE uat_result AS ENUM ('Pass', 'Fail', 'Blocked', 'Skipped');

CREATE TYPE release_note_status AS ENUM ('Draft', 'Scheduled', 'Published');
CREATE TYPE notification_channel AS ENUM ('Email', 'InApp', 'Slack', 'SMS', 'Confluence');
CREATE TYPE audience_segment AS ENUM ('Internal', 'External', 'Engineering');

CREATE TYPE agent_code AS ENUM (
  'AI.PRD', 'AI.RSD', 'AI.RES', 'AI.BREP',
  'AI.RICE.M', 'AI.RICE.T', 'AI.RICE.B',
  'AI.SPEC', 'AI.DSG', 'AI.TST', 'AI.RLN'
);

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

-- Generic updated_at trigger
CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- IDENTITY & USERS
-- ============================================================================

CREATE TABLE domains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  color_token TEXT NOT NULL,  -- e.g., 'payments-blue', 'growth-green'
  owner_id UUID,              -- foreign key added later (circular with users)
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'Viewer',
  domain_id UUID REFERENCES domains(id) ON DELETE SET NULL,  -- nullable; non-Domain Owners don't need one
  status user_status NOT NULL DEFAULT 'Invited',
  avatar_url TEXT,
  last_active_at TIMESTAMPTZ,
  sso_subject TEXT,           -- OIDC/SAML subject id
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ      -- soft delete
);

CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_role ON users(role) WHERE status = 'Active';
CREATE INDEX idx_users_domain ON users(domain_id) WHERE role = 'DomainOwner';
CREATE TRIGGER t_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

ALTER TABLE domains ADD CONSTRAINT fk_domain_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE SET NULL;

CREATE TABLE email_whitelist (
  pattern TEXT PRIMARY KEY,  -- '@company.com' or 'specific@foo.com'
  added_by UUID NOT NULL REFERENCES users(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,     -- hashed session token
  expires_at TIMESTAMPTZ NOT NULL,
  ip_address INET,
  user_agent TEXT,
  mfa_satisfied_at TIMESTAMPTZ,         -- for sensitive-action gating
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sessions_expires ON sessions(expires_at) WHERE expires_at > now();

-- ============================================================================
-- REQUESTS, BRIEFS, ATTACHMENTS
-- ============================================================================

CREATE TABLE requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id TEXT NOT NULL UNIQUE,      -- SUB-0042 pattern
  submitter_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  type request_type NOT NULL,
  title TEXT NOT NULL,
  status request_status NOT NULL DEFAULT 'Draft',
  domain_id UUID REFERENCES domains(id) ON DELETE SET NULL,  -- AI-inferred or manual
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  released_at TIMESTAMPTZ
);

CREATE INDEX idx_requests_status ON requests(status) WHERE status NOT IN ('Released', 'Rejected', 'Cancelled');
CREATE INDEX idx_requests_submitter ON requests(submitter_id);
CREATE INDEX idx_requests_domain_status ON requests(domain_id, status);
CREATE INDEX idx_requests_public_id ON requests(public_id);
CREATE TRIGGER t_requests_updated BEFORE UPDATE ON requests FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE briefs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
  current_version INT NOT NULL DEFAULT 1,
  lock_status brief_lock_status NOT NULL DEFAULT 'Editable',
  content_md TEXT NOT NULL,            -- source of truth
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (request_id)                  -- one Brief per Request (versions are siblings)
);

CREATE INDEX idx_briefs_lock_status ON briefs(lock_status) WHERE lock_status != 'Superseded';
CREATE TRIGGER t_briefs_updated BEFORE UPDATE ON briefs FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE brief_versions (
  brief_id UUID NOT NULL REFERENCES briefs(id) ON DELETE CASCADE,
  version INT NOT NULL,
  content_md TEXT NOT NULL,
  lock_status brief_lock_status NOT NULL,   -- per-version status
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  superseded_by_version INT,                -- if this version was superseded
  PRIMARY KEY (brief_id, version)
);

CREATE INDEX idx_brief_versions_status ON brief_versions(brief_id, lock_status);

CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,            -- 'brief' | 'prd' | 'rsd' | 'uat_run' | 'bug_report' | 'release_note' | 'replication_attempt'
  entity_id UUID NOT NULL,
  filename TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  s3_key TEXT NOT NULL UNIQUE,
  uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  virus_scan_status TEXT NOT NULL DEFAULT 'Pending',   -- 'Pending' | 'Clean' | 'Infected' | 'Failed'
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_attachments_entity ON attachments(entity_type, entity_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- PRD (for Feature requests)
-- ============================================================================

CREATE TABLE prds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL UNIQUE REFERENCES requests(id) ON DELETE CASCADE,
  current_version INT NOT NULL DEFAULT 1,
  status prd_status NOT NULL DEFAULT 'Draft',
  submission_score INT,                     -- 0-100, cached; authoritative in Redis during live drafting
  submission_score_components JSONB,        -- { completeness, depth, specificity, ai_confidence, blockers[] }
  auto_score NUMERIC(3,2),                  -- pre-evaluation quality estimator (0-5.0)
  final_version INT,                        -- set on Mark as Final
  word_count INT,
  assigned_reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_prds_status ON prds(status);
CREATE INDEX idx_prds_reviewer ON prds(assigned_reviewer_id) WHERE status = 'InReview';
CREATE TRIGGER t_prds_updated BEFORE UPDATE ON prds FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE prd_versions (
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  version INT NOT NULL,
  content_snapshot JSONB NOT NULL,         -- parsed sections: { problem_statement: {...}, user_stories: [...], ... }
  content_md TEXT NOT NULL,                 -- rendered markdown (source of truth for viewer)
  ai_section_confidences JSONB,             -- { section_id: 0..1 } for Submission Score
  author_id UUID REFERENCES users(id),      -- AI versions have author_id NULL
  ai_agent_code agent_code,                  -- 'AI.PRD' for agent-generated versions
  commit_reason TEXT,                       -- 'ai-draft' | 'user-edit' | 'regenerate' | 'finalize'
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (prd_id, version)
);

CREATE INDEX idx_prd_versions_ts ON prd_versions(prd_id, committed_at DESC);

CREATE TABLE prd_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  turn_index INT NOT NULL,
  role TEXT NOT NULL,                      -- 'user' | 'assistant' | 'system'
  content TEXT NOT NULL,
  tool_calls JSONB,                        -- structured tool invocations
  author_id UUID REFERENCES users(id),      -- NULL for assistant turns
  tokens_in INT,
  tokens_out INT,
  cost_cents INT,
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (prd_id, turn_index)
);

CREATE INDEX idx_prd_conv_prd_turn ON prd_conversations(prd_id, turn_index);

CREATE TABLE prd_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE RESTRICT,
  prd_version INT NOT NULL,
  reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_by UUID REFERENCES users(id),
  scores JSONB NOT NULL,                   -- { completeness, strategic_alignment, technical_feasibility, clarity_quality } each 1-5
  score_comments JSONB,                    -- { same_keys: string }
  overall_assessment TEXT NOT NULL,
  decision evaluation_decision NOT NULL,
  decision_rationale TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (length(decision_rationale) >= 20)
);

CREATE INDEX idx_evals_prd ON prd_evaluations(prd_id, created_at DESC);
CREATE INDEX idx_evals_reviewer ON prd_evaluations(reviewer_id, created_at DESC);

-- No UPDATE privilege granted to app role; ensures immutability

-- ============================================================================
-- RSD (for Bug requests) — detail in 02_Bug_Pipeline_Specification.md
-- ============================================================================

CREATE TABLE rsds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL UNIQUE REFERENCES requests(id) ON DELETE CASCADE,
  current_version INT NOT NULL DEFAULT 1,
  status rsd_status NOT NULL DEFAULT 'Draft',
  severity_estimate severity_level,         -- Stakeholder's estimate
  ai_detected_severity severity_level,
  affected_users_estimate INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  triaged_at TIMESTAMPTZ,
  backlog_item_id UUID                     -- set on Triage; FK added below (circular)
);

CREATE INDEX idx_rsds_status ON rsds(status) WHERE status NOT IN ('Triaged', 'CannotReproduce');
CREATE TRIGGER t_rsds_updated BEFORE UPDATE ON rsds FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE rsd_versions (
  rsd_id UUID NOT NULL REFERENCES rsds(id) ON DELETE CASCADE,
  version INT NOT NULL,
  content_snapshot JSONB NOT NULL,         -- { environment, expected, actual, repro_steps: [str], severity_rationale }
  author_id UUID REFERENCES users(id),
  ai_agent_code agent_code,                  -- typically 'AI.RSD'
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (rsd_id, version)
);

CREATE TABLE replication_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rsd_id UUID NOT NULL REFERENCES rsds(id) ON DELETE CASCADE,
  attempt_number INT NOT NULL,
  kind attempt_kind NOT NULL,
  actor_id UUID REFERENCES users(id),      -- NULL for AI attempts
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  result attempt_result,                    -- NULL while in flight
  strategies_used TEXT[],
  evidence_refs JSONB,                      -- [{type, s3_url}]
  reasoning TEXT,
  cost_cents INT,
  llm_cost_entry_id UUID,                   -- FK added below (circular)
  UNIQUE (rsd_id, attempt_number)
);

CREATE INDEX idx_repl_rsd ON replication_attempts(rsd_id, attempt_number);

CREATE TABLE bug_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source bug_source NOT NULL,
  source_uat_run_id UUID,                   -- FK added below
  request_id UUID REFERENCES requests(id) ON DELETE SET NULL,  -- for Stakeholder-filed bugs
  title TEXT NOT NULL,
  description TEXT,
  submitter_id UUID NOT NULL REFERENCES users(id),
  severity severity_level NOT NULL,
  created_rsd_id UUID REFERENCES rsds(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bug_reports_source ON bug_reports(source, created_at DESC);

-- ============================================================================
-- RESEARCH
-- ============================================================================

CREATE TABLE research_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  researcher_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  mode research_mode NOT NULL,
  conversation_jsonb JSONB NOT NULL DEFAULT '[]',  -- [{ role, content, sources[], ts }]
  report_jsonb JSONB NOT NULL DEFAULT '{}',        -- { executive_summary, market_landscape, ... }
  recommendation research_recommendation,
  recommendation_confidence NUMERIC(3,2),
  sources JSONB NOT NULL DEFAULT '[]',             -- [{type, url, relevance_score, title}]
  attached_to_prd BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX idx_research_prd ON research_sessions(prd_id, created_at DESC);
CREATE TRIGGER t_research_updated BEFORE UPDATE ON research_sessions FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ============================================================================
-- RICE
-- ============================================================================

CREATE TABLE rice_assessments (
  prd_id UUID PRIMARY KEY REFERENCES prds(id) ON DELETE CASCADE,
  agent_results_jsonb JSONB NOT NULL,           -- { market: {R,I,C,E,commentary,self_confidence}, technical: {...}, business: {...} }
  consensus_rice JSONB NOT NULL,                 -- { R, I, C, E }
  aggregate_score INT NOT NULL,                  -- 0-100
  confidence_range NUMRANGE NOT NULL,            -- e.g., [78, 85]
  divergence_flags TEXT[],
  manual_override_active BOOLEAN NOT NULL DEFAULT false,
  manual_override_jsonb JSONB,                   -- if active; includes override RICE + audit_note + by/at
  last_computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER t_rice_updated BEFORE UPDATE ON rice_assessments FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE rice_override_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  override_rice JSONB NOT NULL,
  audit_note TEXT NOT NULL,
  overridden_by UUID NOT NULL REFERENCES users(id),
  overridden_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rice_override_prd ON rice_override_history(prd_id, overridden_at DESC);

-- ============================================================================
-- SPECS (SpecKit)
-- ============================================================================

CREATE TABLE spec_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  public_id TEXT NOT NULL,                       -- 'US-101'
  current_version INT NOT NULL DEFAULT 1,
  type spec_type NOT NULL,
  title TEXT NOT NULL,
  content_rich TEXT NOT NULL,                    -- markdown or HTML rich content
  acceptance_criteria_jsonb JSONB NOT NULL DEFAULT '[]',  -- [{id, text, order}]
  edge_cases TEXT[],
  dependencies UUID[],                           -- array of spec_item ids
  source_prd_sections JSONB,                     -- [{section_heading, content_excerpt}]
  ai_confidence ai_confidence,
  status spec_status NOT NULL DEFAULT 'Draft',
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  review_comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (prd_id, public_id)
);

CREATE INDEX idx_specs_prd ON spec_items(prd_id);
CREATE INDEX idx_specs_status ON spec_items(status);
CREATE INDEX idx_specs_type ON spec_items(type);
CREATE TRIGGER t_specs_updated BEFORE UPDATE ON spec_items FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE spec_item_versions (
  spec_id UUID NOT NULL REFERENCES spec_items(id) ON DELETE CASCADE,
  version INT NOT NULL,
  content_snapshot JSONB NOT NULL,
  author_id UUID REFERENCES users(id),
  ai_agent_code agent_code,
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (spec_id, version)
);

-- ============================================================================
-- DESIGNS
-- ============================================================================

CREATE TABLE design_screens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prd_id UUID NOT NULL REFERENCES prds(id) ON DELETE CASCADE,
  screen_name TEXT NOT NULL,
  style design_style NOT NULL,
  linked_prd_sections TEXT[],
  linked_spec_ids UUID[],
  flow_order INT,
  status design_status NOT NULL DEFAULT 'Draft',
  figma_frame_url TEXT,
  active_variant_id UUID,                       -- FK added below (circular)
  annotations JSONB,                             -- [{id, region:{x,y,w,h}, component_name, note}]
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_designs_prd ON design_screens(prd_id);
CREATE TRIGGER t_designs_updated BEFORE UPDATE ON design_screens FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE design_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  design_screen_id UUID NOT NULL REFERENCES design_screens(id) ON DELETE CASCADE,
  image_s3_key TEXT NOT NULL,
  generation_prompt TEXT NOT NULL,
  feedback TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_variants_screen ON design_variants(design_screen_id);

ALTER TABLE design_screens
  ADD CONSTRAINT fk_active_variant FOREIGN KEY (active_variant_id) REFERENCES design_variants(id) ON DELETE SET NULL;

-- ============================================================================
-- BACKLOG & DOMAIN-SCOPED
-- ============================================================================

CREATE TABLE backlog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id TEXT NOT NULL UNIQUE,                -- 'PAY-284'
  type backlog_item_type NOT NULL,
  prd_id UUID REFERENCES prds(id) ON DELETE RESTRICT,      -- Feature
  rsd_id UUID REFERENCES rsds(id) ON DELETE RESTRICT,      -- Bug
  title TEXT NOT NULL,
  domain_id UUID REFERENCES domains(id) ON DELETE SET NULL,
  status backlog_status NOT NULL DEFAULT 'New',
  rice_score INT,                                -- for Feature
  bug_severity_score INT,                        -- for Bug
  research_recommendation research_recommendation,
  target_quarter TEXT,                           -- e.g., 'Q2 2026'
  assignees UUID[],                              -- lightweight assignment refs
  description_excerpt TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (type = 'Feature' AND prd_id IS NOT NULL AND rsd_id IS NULL) OR
    (type = 'Bug'     AND rsd_id IS NOT NULL AND prd_id IS NULL)
  )
);

CREATE INDEX idx_backlog_status ON backlog_items(status);
CREATE INDEX idx_backlog_domain_status ON backlog_items(domain_id, status);
CREATE INDEX idx_backlog_type ON backlog_items(type);
CREATE INDEX idx_backlog_public ON backlog_items(public_id);
CREATE TRIGGER t_backlog_updated BEFORE UPDATE ON backlog_items FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

ALTER TABLE rsds ADD CONSTRAINT fk_rsd_backlog FOREIGN KEY (backlog_item_id) REFERENCES backlog_items(id) ON DELETE SET NULL;

CREATE TABLE domain_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backlog_item_id UUID NOT NULL REFERENCES backlog_items(id) ON DELETE CASCADE,
  domain_id UUID NOT NULL REFERENCES domains(id) ON DELETE CASCADE,
  ranked_position INT,                            -- within-domain rank
  flagged_priority BOOLEAN NOT NULL DEFAULT false,
  domain_notes TEXT,
  flagged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (backlog_item_id, domain_id)
);

CREATE INDEX idx_domain_flags_ranked ON domain_flags(domain_id, ranked_position);
CREATE TRIGGER t_domain_flags_updated BEFORE UPDATE ON domain_flags FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE sprints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  number INT NOT NULL UNIQUE,                    -- 'Sprint 14'
  starts_on DATE NOT NULL,
  ends_on DATE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE sprint_commitments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sprint_id UUID NOT NULL REFERENCES sprints(id) ON DELETE RESTRICT,
  backlog_item_id UUID NOT NULL REFERENCES backlog_items(id) ON DELETE RESTRICT,
  committed_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  rationale TEXT NOT NULL,                        -- per OL-B5: this is the durable decision log
  comparison_selection_ids UUID[],                -- items that were in the comparison that led to this commit (for traceability)
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sprint_id, backlog_item_id),
  CHECK (length(rationale) >= 20)
);

CREATE INDEX idx_commitments_sprint ON sprint_commitments(sprint_id);

-- ============================================================================
-- ROADMAP
-- ============================================================================

CREATE TABLE roadmap_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backlog_item_id UUID NOT NULL REFERENCES backlog_items(id) ON DELETE CASCADE,
  quarter TEXT NOT NULL,                          -- 'Q2 2026'
  domain_id UUID REFERENCES domains(id),
  start_week_num INT NOT NULL,                    -- ISO week
  end_week_num INT NOT NULL,
  status TEXT,                                    -- 'Completed' | 'InProgress' | 'Planned'
  depends_on UUID[],                              -- other roadmap_items
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_roadmap_quarter_domain ON roadmap_items(quarter, domain_id);
CREATE TRIGGER t_roadmap_updated BEFORE UPDATE ON roadmap_items FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE roadmap_notes (
  quarter TEXT PRIMARY KEY,
  objectives_md TEXT,
  resource_shifting_md TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- HANDOVER
-- ============================================================================

CREATE TABLE handover_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backlog_item_id UUID NOT NULL UNIQUE REFERENCES backlog_items(id) ON DELETE RESTRICT,
  checklist_jsonb JSONB NOT NULL,                 -- per-item complete / outstanding
  readiness_pct INT NOT NULL DEFAULT 0,
  assigned_team_id UUID,                           -- future-facing
  tech_lead_id UUID REFERENCES users(id),
  sent_at TIMESTAMPTZ,
  sent_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER t_handover_updated BEFORE UPDATE ON handover_packages FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ============================================================================
-- DELIVERY
-- ============================================================================

CREATE TABLE sprint_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sprint_id UUID NOT NULL REFERENCES sprints(id) ON DELETE RESTRICT,
  backlog_item_id UUID NOT NULL REFERENCES backlog_items(id) ON DELETE RESTRICT,
  lead_id UUID REFERENCES users(id) ON DELETE SET NULL,
  progress_pct INT NOT NULL DEFAULT 0,
  state delivery_state NOT NULL DEFAULT 'OnTrack',
  blockers JSONB NOT NULL DEFAULT '[]',            -- [{id, title, description, severity, added_at, added_by, resolved_at}]
  target_date DATE,
  demo_ready BOOLEAN NOT NULL DEFAULT false,
  uat_ready_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (sprint_id, backlog_item_id)
);

CREATE INDEX idx_tasks_sprint_state ON sprint_tasks(sprint_id, state);
CREATE TRIGGER t_tasks_updated BEFORE UPDATE ON sprint_tasks FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ============================================================================
-- UAT
-- ============================================================================

CREATE TABLE uat_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  backlog_item_id UUID NOT NULL REFERENCES backlog_items(id) ON DELETE RESTRICT,
  tester_id UUID NOT NULL REFERENCES users(id),
  criteria_results_jsonb JSONB NOT NULL DEFAULT '{}',  -- { criterion_id: { result, screenshots[], ts, by } }
  ai_conversation_jsonb JSONB NOT NULL DEFAULT '[]',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at TIMESTAMPTZ,
  all_pass BOOLEAN,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_uat_backlog ON uat_runs(backlog_item_id, started_at DESC);

ALTER TABLE bug_reports ADD CONSTRAINT fk_bug_uat FOREIGN KEY (source_uat_run_id) REFERENCES uat_runs(id) ON DELETE SET NULL;

-- ============================================================================
-- RELEASE NOTES
-- ============================================================================

CREATE TABLE release_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version_label TEXT NOT NULL UNIQUE,              -- 'v2.4.0 — April 2026'
  body_md TEXT NOT NULL DEFAULT '',
  included_prd_ids UUID[],
  included_bug_rsd_ids UUID[],
  status release_note_status NOT NULL DEFAULT 'Draft',
  audiences audience_segment[],
  channels notification_channel[],
  scheduled_at TIMESTAMPTZ,
  published_at TIMESTAMPTZ,
  published_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER t_releases_updated BEFORE UPDATE ON release_notes FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE release_note_versions (
  release_note_id UUID NOT NULL REFERENCES release_notes(id) ON DELETE CASCADE,
  version INT NOT NULL,
  body_md TEXT NOT NULL,
  editor_id UUID REFERENCES users(id),
  committed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (release_note_id, version)
);

-- ============================================================================
-- COMMENTS & ANNOTATIONS
-- ============================================================================

CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL,                        -- 'request', 'prd', 'spec_item', 'design_screen', etc.
  entity_id UUID NOT NULL,
  author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  body TEXT NOT NULL,
  anchor_jsonb JSONB,                                -- section/line anchor for annotations on PRD viewer
  mentions UUID[],                                   -- user_ids mentioned
  parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,  -- for threads
  edited_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_comments_entity ON comments(entity_type, entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_comments_mentions ON comments USING GIN (mentions);

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,                                -- 'review_assigned', 'release_published', 'bug_replication_complete', ...
  payload_jsonb JSONB NOT NULL,                      -- enough to render the notification UI
  related_entity_type TEXT,
  related_entity_id UUID,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notif_user_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;

CREATE TABLE notification_prefs (
  -- v2 scope per OL-3; schema here so backend can be ready
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  channel notification_channel NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  digest_schedule TEXT NOT NULL DEFAULT 'realtime', -- 'realtime' | 'daily_9am' | 'weekly_monday'
  PRIMARY KEY (user_id, event_type, channel)
);

-- ============================================================================
-- LLM COST & AUDIT
-- ============================================================================

CREATE TABLE llm_cost_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature TEXT NOT NULL,                             -- 'PRD Generator' | 'RICE Scoring' | ...
  agent_code agent_code NOT NULL,
  model TEXT NOT NULL,                               -- 'claude-sonnet-4-6' etc.
  tokens_in INT NOT NULL,
  tokens_out INT NOT NULL,
  cost_cents INT NOT NULL,
  latency_ms INT,
  caller_id UUID REFERENCES users(id),               -- null for system-initiated
  entity_type TEXT,
  entity_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_llm_feature_ts ON llm_cost_entries(feature, created_at DESC);
CREATE INDEX idx_llm_agent_ts ON llm_cost_entries(agent_code, created_at DESC);
CREATE INDEX idx_llm_entity ON llm_cost_entries(entity_type, entity_id);

ALTER TABLE replication_attempts
  ADD CONSTRAINT fk_repl_cost FOREIGN KEY (llm_cost_entry_id) REFERENCES llm_cost_entries(id) ON DELETE SET NULL;

-- No UPDATE privilege on llm_cost_entries

CREATE TABLE llm_budgets (
  period_month DATE PRIMARY KEY,                     -- first-of-month date
  budget_cents INT NOT NULL,
  alert_thresholds_jsonb JSONB NOT NULL DEFAULT '{"50": true, "75": true, "90": false}',
  current_spend_cents INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE model_configs (
  feature TEXT PRIMARY KEY,
  model TEXT NOT NULL,                                -- default model for this feature
  max_tokens INT NOT NULL DEFAULT 4000,
  updated_by UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_type TEXT NOT NULL,                           -- 'user' | 'ai_agent' | 'system'
  actor_id UUID,                                      -- user_id or null
  actor_code TEXT,                                    -- agent_code for AI; or service name for 'system'
  action TEXT NOT NULL,                               -- e.g. 'PRDEvaluated', 'BacklogItemStatusChanged'
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  before_jsonb JSONB,
  after_jsonb JSONB,
  ip_address INET,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_log(actor_id, created_at DESC) WHERE actor_id IS NOT NULL;
CREATE INDEX idx_audit_ts ON audit_log(created_at DESC);

-- No UPDATE privilege on audit_log

-- ============================================================================
-- PLATFORM SETTINGS (key-value store)
-- ============================================================================

CREATE TABLE platform_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed examples:
-- INSERT INTO platform_settings (key, value) VALUES
--   ('algo.submission_score.weights', '{"completeness":0.6,"depth":0.2,"specificity":0.1,"ai_confidence":0.1}'),
--   ('algo.submission_score.threshold', '80'),
--   ('algo.submission_score.required_sections', '["problem_statement","target_users","functional_requirements","data_schema","edge_cases","success_metrics","future_iterations"]'),
--   ('algo.bug_replication.cost_cap_cents', '500'),
--   ('algo.bug_replication.max_ai_attempts', '3'),
--   ('algo.bug_severity.source_boost_uat', '0'),
--   ('algo.bug_severity.source_boost_external', '10'),
--   ('brief_lifecycle.default_supersession_choice', '"keep_running"');

-- ============================================================================
-- SEARCH EMBEDDINGS
-- ============================================================================

CREATE TABLE similarity_embeddings (
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  embedding VECTOR(1536),                              -- size depends on embedding model
  model_used TEXT NOT NULL,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (entity_type, entity_id)
);

CREATE INDEX idx_embeddings_vector ON similarity_embeddings USING ivfflat (embedding vector_cosine_ops);

-- ============================================================================
-- ROW-LEVEL SECURITY POLICIES
-- ============================================================================
-- Enabled on a per-table basis. Postgres roles:
--   app_read    — GRANT SELECT only on most tables
--   app_write   — GRANT INSERT/UPDATE/DELETE as appropriate
--   app_super   — GRANT ALL (used by admin migration scripts)
-- Application-level user identity is passed in via SET LOCAL app.current_user_id / app.current_user_role / app.current_user_domain_id

-- Example: backlog_items — Domain Owners see their domain only
ALTER TABLE backlog_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY backlog_select ON backlog_items FOR SELECT USING (
  current_setting('app.current_user_role', true) IN ('Admin', 'ProductLead', 'ProductManager', 'EngineeringLead', 'QA', 'Viewer')
  OR domain_id = current_setting('app.current_user_domain_id', true)::UUID
);

CREATE POLICY backlog_write ON backlog_items FOR UPDATE USING (
  current_setting('app.current_user_role', true) IN ('Admin', 'ProductLead', 'ProductManager', 'EngineeringLead')
);

-- Example: requests — Stakeholders see only their own
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY requests_select ON requests FOR SELECT USING (
  current_setting('app.current_user_role', true) IN ('Admin', 'ProductLead', 'ProductManager', 'EngineeringLead', 'QA')
  OR submitter_id = current_setting('app.current_user_id', true)::UUID
  OR domain_id = current_setting('app.current_user_domain_id', true)::UUID  -- Domain Owner
);

-- Similar policies on other tables — intentionally omitted here for brevity; see `06_RBAC_Security_Observability.md` for the full matrix.

-- ============================================================================
-- REVOKE STRICT POLICIES FOR APPEND-ONLY TABLES
-- ============================================================================

REVOKE UPDATE, DELETE ON audit_log FROM app_write;
REVOKE UPDATE, DELETE ON llm_cost_entries FROM app_write;
REVOKE UPDATE, DELETE ON prd_evaluations FROM app_write;
REVOKE UPDATE, DELETE ON rice_override_history FROM app_write;
REVOKE UPDATE, DELETE ON sprint_commitments FROM app_write;

-- ============================================================================
-- VIEWS (for read-model queries)
-- ============================================================================

CREATE OR REPLACE VIEW v_active_backlog AS
SELECT b.*, d.name AS domain_name, d.color_token AS domain_color,
       p.title AS prd_title, r.title AS rsd_title,
       CASE WHEN b.type = 'Feature' THEN b.rice_score ELSE b.bug_severity_score END AS display_score
FROM backlog_items b
LEFT JOIN domains d ON d.id = b.domain_id
LEFT JOIN prds p ON p.id = b.prd_id
LEFT JOIN rsds r ON r.id = b.rsd_id
WHERE b.status NOT IN ('Released', 'Archived');

CREATE OR REPLACE VIEW v_request_lifecycle AS
SELECT r.*,
       b.lock_status AS brief_lock,
       b.current_version AS brief_version,
       p.id AS prd_id, p.status AS prd_status, p.submission_score,
       rsd.id AS rsd_id, rsd.status AS rsd_status,
       bl.id AS backlog_item_id, bl.status AS backlog_status
FROM requests r
LEFT JOIN briefs b ON b.request_id = r.id
LEFT JOIN prds p ON p.request_id = r.id
LEFT JOIN rsds rsd ON rsd.request_id = r.id
LEFT JOIN backlog_items bl ON (bl.prd_id = p.id OR bl.rsd_id = rsd.id);

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- * This is the v1 baseline schema. Future migrations should be managed by a migration tool (recommended: Flyway or sqitch).
-- * Breaking changes require an ADR in `_SOURCES/ADRs/`.
-- * Index tuning: initial indexes cover canonical access patterns; monitor pg_stat_user_indexes after first 30 days.
-- * Partition candidates: audit_log (by month), llm_cost_entries (by month), comments (by month, if volume justifies).

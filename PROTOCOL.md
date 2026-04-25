# PRD Agent — Protocol Specification

## 1. Scope

This document is the canonical reference for how the PRD Agent framework interacts with user projects. All paths are **relative to the project root** where OpenCode is launched.

The framework itself is installed globally (see `INSTALL.md`). The runtime artefacts (session files, logs, configs) live inside each user project and are never mixed across projects.

## 2. Directory & File Layout

```
{project-root}/
  .prd-config.json                       ← per-project config (see templates/.prd-config.json)
  .prd-sessions/
    metrics.json                          ← aggregated project metrics (feedback, duration, etc.)
    prd-{YYYYMMDD-HHMMSS}/                ← one directory per session
      tmp/
        ledger.json.tmp                   ← atomic write staging
      ledger.json                         ← compressed session state
      ledger.json.bak.1                   ← rotating backup (3 max)
      ledger.json.bak.2
      ledger.json.bak.3
      questions.json                      ← generated question set
      checkpoint.json                     ← interview resumption state
      session.log                         ← structured operation log
      prd.md                              ← current PRD draft
      prd.v1.md                           ← versioned PRD (significant changes only)
      prd.v2.md
```

**Schema source of truth:** `schemas/runtime.schema.json` in this repository.

## 3. Session Lifecycle

### 3.1 Creation
1. User describes an idea.
2. `spec` generates `session-id = prd-{YYYYMMDD-HHMMSS}`.
3. `spec` creates `{project-root}/.prd-sessions/{session-id}/`.
4. If `.prd-config.json` is missing, `spec` copies `templates/.prd-config.json` to project root and informs the user.
5. `spec` validates `.prd-config.json` against the template schema. **Missing fields = hard failure** with a descriptive error.
6. `spec` writes a snapshot of the config into `ledger.json → config_snapshot`.

### 3.2 Atomic Persistence
Any agent that overwrites `ledger.json` or `questions.json` MUST follow the atomic write protocol:

1. Write to `{session-dir}/tmp/{filename}.tmp`.
2. Validate the temp file against its JSON schema (`schemas/ledger.schema.json` or `schemas/questions.schema.json`). **Validation is MANDATORY — not optional.**
3. On validation pass: rename temp file to final destination.
4. On validation fail: stop and report the error. Do NOT rename. Return an error structured output.

### 3.3 Backup Rotation
Before overwriting `ledger.json`, `prd-interviewer` MUST:
1. Copy `ledger.json.bak.2` → `ledger.json.bak.3`
2. Copy `ledger.json.bak.1` → `ledger.json.bak.2`
3. Copy current `ledger.json` → `ledger.json.bak.1`

Maximum backups: **3**. Older backups are discarded.

### 3.4 Checkpointing
`prd-interviewer` writes `checkpoint.json` after every answered question:

```json
{
  "session_id": "prd-20250422-100000",
  "current_question_index": 4,
  "answered_context_snapshot": { ... },
  "timestamp": "2025-04-22T10:05:00Z"
}
```

If OpenCode closes during an interview, `spec` can detect `interview_status: "IN_PROGRESS"` plus an existing `checkpoint.json` and offer resumption.

### 3.5 Cleanup & Retention
- `spec sessions cleanup` deletes session directories older than `retention_days` (default 90).
- This is a **manual command**. No automatic background deletion runs.

## 4. Agent Data Contract

| Agent | Reads | Creates | Updates | Notes |
|---|---|---|---|---|
| `spec` | `.prd-config.json`, `{session}/ledger.json`, `{session}/checkpoint.json` | `.prd-sessions/`, `{session}/`, `{session}/session.log`, `.prd-config.json` (if missing), `.prd-sessions/metrics.json` | `.prd-sessions/metrics.json` | Orchestrator. Handles session commands. |
| `prd-intake` | `.prd-config.json` | `{session}/ledger.json` | — | Validates idea, sanitizes PII. |
| `prd-planner` | `.prd-config.json`, `{session}/ledger.json` | `{session}/questions.json` | `{session}/ledger.json` | Respects `max_questions` and `batch_size`. |
| `prd-interviewer` | `.prd-config.json`, `{session}/ledger.json`, `{session}/questions.json` | `{session}/checkpoint.json`, `{session}/tmp/`, `{session}/ledger.json.bak.*` | `{session}/ledger.json`, `{session}/questions.json`, `{session}/checkpoint.json` | Atomic writes, backups, commands (`!back`, `!skip`, `!fast`). |
| `prd-writer` | `.prd-config.json`, `{session}/ledger.json` | `{session}/prd.md`, `{session}/prd.v{n}.md` | `{session}/ledger.json` | Versioning logic. |
| `prd-validator` | `.prd-config.json`, `{session}/prd.md`, `{session}/ledger.json` | — | `{session}/ledger.json` | Syntax + semantic checks. |

All agents append to `{session}/session.log`.

## 5. Versioning Rules

`prd-writer` decides whether to bump the version:

### Same version (overwrite `prd.md`)
- Formatting fixes.
- Adding items to an existing list (append).
- Typos, TBD additions, minor rewording.
- Changes that do NOT alter `answered_context` semantics.

### New version (`prd.v{n+1}.md`)
- Change in `solution_shape`.
- Addition or removal of `functional_requirements`.
- Change in `core_problem`.
- Change in success metrics or scope.

The current version number is stored in `ledger.json → prd_version`.

## 6. Security & Privacy

### 6.1 PII / Secret Detection (`prd-intake`)
Before validating an idea, scan with regex for:
- Emails: `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`
- API keys: patterns like `sk-[a-zA-Z0-9]{20,}`, `AKIA...`
- Credit cards: `\b(?:\d[ -]*?){13,16}\b`

If detected, warn the user and offer to redact before continuing.

### 6.2 Data Flow Transparency
- All data sent to LLMs is documented in `AGENTS.md`.
- The `--local` flag (when available) routes all LLM calls to local models (e.g., Ollama, LM Studio) so no data leaves the machine.

### 6.3 Retention
- Sessions are retained for `retention_days` (default 90).
- Manual cleanup via `spec sessions cleanup`.

## 7. Configuration

`.prd-config.json` lives at the project root. It is **optional at rest** but **mandatory at runtime**. If missing, `spec` seeds it from the framework template.

### Validation rules
- Every field present in the framework template is required.
- **No partial fallback**: if a field is missing, the agent MUST fail immediately with a message like:
  ```
  Config validation failed: missing field 'models.writer' in .prd-config.json
  Please add it or delete the file to regenerate the default template.
  ```

### Supported fields
See `templates/.prd-config.json` for the full template.

## 8. Observability

### 8.1 Session Log Format
`session.log` uses structured plain text:

```
[2025-04-22T10:00:00Z] [INFO] [prd-intake] START session=prd-20250422-100000
[2025-04-22T10:00:05Z] [INFO] [prd-intake] END result=PASS duration=5s
[2025-04-22T10:00:06Z] [ERROR] [prd-planner] SCHEMA_FAIL detail=questions.json missing 'total_questions'
```

Every agent appends its own lines. Logs are never overwritten, only appended.

### 8.2 Metrics
`.prd-sessions/metrics.json` (per project) accumulates:
- `total_sessions`
- `avg_interview_duration_min`
- `validator_approval_rate`
- `feedback_scores` (from `spec feedback`)

## 9. Runtime Schema Consistency

Any change to runtime paths MUST be reflected in both:
1. `schemas/runtime.schema.json`
2. The Context Contract of every agent that touches the changed path.

The test suite (`tests/test_protocol.py`) parses all agent files and validates that every runtime path mentioned is declared in `runtime.schema.json`.

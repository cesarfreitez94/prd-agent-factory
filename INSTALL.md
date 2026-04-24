# PRD Agent — Installation Guide

## What goes where

```
~/.config/opencode/
  AGENTS.md                    ← global rules (append if file already exists)
  agents/
    spec.md                    ← primary agent (Tab-selectable)
    prd-intake.md              ← subagent (hidden, invoked by spec)
    prd-planner.md             ← subagent (hidden, invoked by spec)
    prd-interviewer.md         ← subagent (hidden, invoked by spec)
    prd-writer.md              ← subagent (hidden, invoked by spec)
    prd-validator.md           ← subagent (hidden, invoked by spec)
```

Sessions and configuration live inside each user project:
```
{your-project}/
  .prd-config.json              ← per-project configuration (auto-created if missing)
  .prd-sessions/
    metrics.json                ← aggregated project metrics
    prd-20250421-143022/
      ledger.json
      questions.json
      checkpoint.json
      session.log
      prd.md
      prd.v1.md
```

---

## Install

```bash
# 1. Create directory structure
mkdir -p ~/.config/opencode/agents

# 2. Copy agents
cp agents/*.md ~/.config/opencode/agents/

# 3. Copy global rules
#    If ~/.config/opencode/AGENTS.md already exists, back it up before overwriting:
#    mv ~/.config/opencode/AGENTS.md ~/.config/opencode/AGENTS.md.bak.$(date +%s)
#    Note: this file will REPLACE the existing AGENTS.md. If you have custom global rules,
#    merge them manually after copying.
cp AGENTS.md ~/.config/opencode/AGENTS.md

# 4. Copy schemas (agents validate outputs against these at runtime)
cp -r schemas/ ~/.config/opencode/schemas/

# 5. Copy templates (used to seed .prd-config.json in new projects)
cp -r templates/ ~/.config/opencode/templates/
```

> **Nota:** Los agentes validan sus outputs contra JSON schemas en runtime y leen el template de config desde el directorio de instalación. Por eso es necesario copiar también las carpetas `schemas/` y `templates/`.

---

## Usage

1. Open OpenCode in your project directory
2. Press **Tab** to switch to the `spec` agent
3. Describe your idea:
   ```
   I want to build a tool that helps freelancers track their invoices
   ```
4. Spec validates, plans, interviews you (1 question at a time), and generates the PRD
5. Your PRD lands at `.prd-sessions/{session-id}/prd.md` inside your project

### Configuration (optional but recommended)

If you want to customize models, question limits, or languages, create `.prd-config.json` at your project root before starting a session. If it doesn't exist, `spec` will copy the default template automatically.

Example `.prd-config.json`:
```json
{
  "project_name": "Invoice Tracker",
  "max_questions": 15,
  "batch_size": 5,
  "interaction_language": "es",
  "output_language": "en",
  "enable_semantic_validation": true,
  "retention_days": 90
}
```

**Validation:** if any required field is missing, the agent will fail immediately with a descriptive error.

### Local mode

To prevent data from leaving your machine, configure all models in `.prd-config.json` to point to a local inference server (e.g., Ollama, LM Studio). The framework does not distinguish between remote and local endpoints — it only reads the model string from the config.

---

## Multiple projects

Each project gets its own `.prd-sessions/` directory and `.prd-config.json`. Sessions never mix.

```
~/projects/invoicing-tool/
  .prd-config.json
  .prd-sessions/
    prd-20250421-143022/    ← PRD for this project

~/projects/analytics-dashboard/
  .prd-config.json
  .prd-sessions/
    prd-20250422-091500/    ← PRD for this project
```

---

## .gitignore

Spec will ask you once whether to add `.prd-sessions/` to `.gitignore`.
To add manually:

```bash
echo ".prd-sessions/" >> .gitignore
```

If you want to commit PRDs to the repo, skip this step.

---

## Schemas (runtime validation)

`schemas/ledger.schema.json`, `schemas/questions.schema.json`, and `schemas/runtime.schema.json` define the structure of session files. Agents validate their outputs against these schemas at runtime. Do not modify them unless you also update the agent instructions.

---

## Testing (optional)

If you want to validate the framework locally:

```bash
# Requires pytest
pytest tests/
```

Tests include:
- Schema validation against example fixtures
- Protocol consistency (paths in agents match runtime.schema.json)

---

## Session Management Commands

While in a project, you can ask `spec` to:

- `spec sessions list` — see all past sessions
- `spec sessions delete {session-id}` — remove a session
- `spec sessions compare {id1} {id2}` — compare two PRD versions
- `spec sessions cleanup` — remove sessions older than 90 days
- `spec feedback` — rate the last PRD quality

See `PROTOCOL.md` for full details.

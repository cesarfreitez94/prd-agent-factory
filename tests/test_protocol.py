"""
Protocol consistency tests.

Ensures that runtime paths mentioned in agent files are declared in
schemas/runtime.schema.json. This prevents agents from drifting away
from the canonical path layout.

Requires: pytest
"""
import json
import os
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = ROOT / "agents"
SCHEMAS_DIR = ROOT / "schemas"
RUNTIME_SCHEMA_PATH = SCHEMAS_DIR / "runtime.schema.json"

# Regex patterns that catch runtime paths inside agent markdown files
PATH_PATTERNS = [
    re.compile(r"\{session-dir\}/[\w./\-{}]+"),
    re.compile(r"\{project-root\}/[\w./\-{}]+"),
    re.compile(r"\.prd-sessions/[\w./\-{}]+"),
    re.compile(r"schemas/[\w.\-]+\.json"),
]

# Paths that are documentation/meta and should not be flagged as missing
ALLOWED_UNDECLARED = {
    "{project-root}/.prd-config.json",  # explicitly documented elsewhere
    # Documentational path examples that use literal .prd-sessions/ instead of {session-dir}
    "prd-sessions/{session-id}/",
    "prd-sessions/{session-id}",
    "prd-sessions/{session-id}/tmp",
    "prd-sessions/{session-id}/prd.md",
    "prd-sessions/prd-20250421-143022/checkpoint.json",
}


def _extract_paths_from_text(text: str) -> set:
    found = set()
    for pattern in PATH_PATTERNS:
        for match in pattern.findall(text):
            # Strip trailing punctuation / markdown
            clean = match.strip(".`'\"()[]")
            if clean:
                found.add(clean)
    return found


def _collect_runtime_schema_paths(schema: dict, collected: set = None) -> set:
    """Recursively collect all 'const' string values from runtime.schema.json."""
    if collected is None:
        collected = set()
    if isinstance(schema, dict):
        for key, value in schema.items():
            if key == "const" and isinstance(value, str):
                collected.add(value)
            else:
                _collect_runtime_schema_paths(value, collected)
    elif isinstance(schema, list):
        for item in schema:
            _collect_runtime_schema_paths(item, collected)
    return collected


def test_runtime_schema_exists():
    assert RUNTIME_SCHEMA_PATH.exists(), "schemas/runtime.schema.json must exist"


def test_all_agent_paths_declared_in_runtime_schema():
    runtime_schema = json.loads(RUNTIME_SCHEMA_PATH.read_text(encoding="utf-8"))
    declared_paths = _collect_runtime_schema_paths(runtime_schema)

    # Also allow schema references as declared
    declared_paths.add("schemas/ledger.schema.json")
    declared_paths.add("schemas/questions.schema.json")
    declared_paths.add("schemas/checkpoint.schema.json")
    declared_paths.add("schemas/runtime.schema.json")

    undeclared_by_agent = {}

    for agent_file in sorted(AGENTS_DIR.glob("*.md")):
        text = agent_file.read_text(encoding="utf-8")
        found = _extract_paths_from_text(text)
        undeclared = []
        for path in found:
            # Check if path or a parent pattern is in declared_paths
            if path in ALLOWED_UNDECLARED:
                continue
            match = any(path in declared or declared in path for declared in declared_paths)
            if not match:
                undeclared.append(path)
        if undeclared:
            undeclared_by_agent[agent_file.name] = undeclared

    if undeclared_by_agent:
        msg_lines = ["Undeclared runtime paths found in agent files:"]
        for agent, paths in undeclared_by_agent.items():
            msg_lines.append(f"  {agent}: {paths}")
        msg_lines.append("Either update the agent to use a declared path, or add the path to schemas/runtime.schema.json.")
        pytest.fail("\n".join(msg_lines))


def test_all_agents_reference_runtime_schema():
    """Every agent that touches runtime files should mention runtime.schema.json."""
    agents_with_runtime_refs = set()
    for agent_file in sorted(AGENTS_DIR.glob("*.md")):
        text = agent_file.read_text(encoding="utf-8")
        if "runtime.schema.json" in text:
            agents_with_runtime_refs.add(agent_file.name)

    # All agents except maybe pure meta docs should reference it
    expected = {"spec.md", "prd-intake.md", "prd-planner.md", "prd-interviewer.md", "prd-writer.md", "prd-validator.md", "prd-revisor.md"}
    missing = expected - agents_with_runtime_refs
    assert not missing, f"Agents missing runtime.schema.json reference: {missing}"


def test_checkpoint_schema_completeness():
    """Ensure checkpoint.json structure is documented in runtime schema or agent contracts."""
    runtime_schema = json.loads(RUNTIME_SCHEMA_PATH.read_text(encoding="utf-8"))
    paths = _collect_runtime_schema_paths(runtime_schema)
    assert any("checkpoint.json" in p for p in paths), "checkpoint.json must be declared in runtime.schema.json"

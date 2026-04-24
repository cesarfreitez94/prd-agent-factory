"""
Validate example fixtures against the JSON schemas.
Requires: pytest, jsonschema
"""
import json
import os
from pathlib import Path

import pytest

# Allow running without jsonschema installed gracefully
try:
    from jsonschema import validate, ValidationError
    HAS_JSONSCHEMA = True
except Exception:  # pragma: no cover
    HAS_JSONSCHEMA = False

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS_DIR = ROOT / "schemas"
FIXTURES_DIR = ROOT / "tests" / "fixtures"


def load_json(path: Path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


@pytest.mark.skipif(not HAS_JSONSCHEMA, reason="jsonschema not installed")
def test_ledger_schema_validates_mock_ledger():
    schema = load_json(SCHEMAS_DIR / "ledger.schema.json")
    fixture = load_json(FIXTURES_DIR / "mock_ledger.json")
    validate(instance=fixture, schema=schema)


@pytest.mark.skipif(not HAS_JSONSCHEMA, reason="jsonschema not installed")
def test_questions_schema_validates_mock_questions():
    schema = load_json(SCHEMAS_DIR / "questions.schema.json")
    fixture = load_json(FIXTURES_DIR / "mock_questions.json")
    validate(instance=fixture, schema=schema)


def test_mock_ledger_has_required_fields():
    """Lightweight structural validation without jsonschema dependency."""
    fixture = load_json(FIXTURES_DIR / "mock_ledger.json")
    required = ["session_id", "general_summary", "intake_status", "answered_context"]
    for key in required:
        assert key in fixture, f"Missing required field: {key}"
    assert fixture["session_id"].startswith("prd-")
    assert isinstance(fixture["answered_context"], dict)
    assert "prd_version" in fixture
    assert "config_snapshot" in fixture


def test_mock_questions_has_required_fields():
    fixture = load_json(FIXTURES_DIR / "mock_questions.json")
    required = ["session_id", "generated_at", "total_questions", "questions", "mode"]
    for key in required:
        assert key in fixture, f"Missing required field: {key}"
    assert isinstance(fixture["questions"], list)
    assert len(fixture["questions"]) > 0
    first = fixture["questions"][0]
    assert "batchable" in first


def test_runtime_schema_is_valid_json():
    schema = load_json(SCHEMAS_DIR / "runtime.schema.json")
    assert schema.get("title") == "PRD Agent Runtime Structure"
    assert "properties" in schema

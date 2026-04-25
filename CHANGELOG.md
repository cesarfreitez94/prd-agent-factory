# Changelog

Todos los cambios significativos se documentan aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- GitHub Issues workflow (`.github/`) con templates para features e improvements
- CONTRIBUTING.md con guía de contribución
- Sección "Flujo del Pipeline" en README.md
- Telemetry de tokens (`tokens_in`, `tokens_out`) en logs de sesión para todos los agentes

### Changed
- `raw_idea_hash` ahora usa SHA-256 fingerprint (16 hex chars) en lugar de truncate de 100 chars
- Interviewer ahora colecta y presenta preguntas en batch (hasta `batch_size`) en una sola invocación del question tool
- Context Contract del interviewer ahora especifica exactamente qué cargar por turno

### Fixed
- Validator I8: ahora rechaza menciones de technology stack (React, PostgreSQL, etc.) a menos que estén en `answered_context.constraints`
- Validation en atomic writes ahora es **MANDATORY** — no opcional (PROTOCOL.md §3.2)

## [1.0.0] — 2025-04-24

### Added
- Framework completo con 5 agentes: spec, prd-intake, prd-planner, prd-interviewer, prd-writer, prd-validator
- Sesiones persistidas en `.prd-sessions/{session-id}/` dentro del proyecto
- Versionado automático de PRDs (`prd.v1.md`, `prd.v2.md`, etc.)
- Checkpoint y resumption de sesiones interrumpidas
- 18 syntactic checks + validación semántica en validator
- PII/secrets scanning en intake
- Backup rotativo (3 máximo) para ledger.json
- Schema validation en todos los archivos JSON

### Fixed
- Estado terminal `BLOCKED` y `NEEDS_REVIEW` ahora respetados por spec (no re-intenta automáticamente)

[Unreleased]: https://github.com/cesarfreitez94/prd-agent-factory/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/cesarfreitez94/prd-agent-factory/releases/tag/v1.0.0
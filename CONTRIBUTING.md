# Contributing to PRD Agent

Gracias por contribuir. Este documento explica cómo trabajar con issues y PRs en este repo.

## Quick Start

1. Fork el repo
2. Crea un branch desde `dev`: `git checkout -b feature/42-my-feature`
3. Trabaja en tu feature
4. Abre PR con `Fixes #N` en la descripción
5. Después de merge, actualiza CHANGELOG.md

## GitHub Issues Workflow

Lee [.github/README_issues.md](.github/README_issues.md) para el flujo completo.

Resumen:

- Usa los **templates de issue** para reportar problemas o sugerir mejoras
- Asigna labels (`bug`, `feature`, `improvement`, `documentation`, `question`)
- Asigna priority (`priority:high`, `priority:medium`, `priority:low`)
- Para cerrar automáticamente, incluye `Fixes #N` en la descripción del PR

## Rama protegida: `dev`

El branch `dev` es el destino default para PRs de features. No hacer push directo.

## Commits

Usa mensajes descriptivos:
- `feat: ...` — nueva funcionalidad
- `fix: ...` — bug fix
- `docs: ...` — solo documentación
- `refactor: ...` — cambios sin comportamiento nuevo

Ejemplo:
```
feat: add batch questions support in interviewer

- Collect up to batch_size questions and present in one question tool call
- Write checkpoint once per batch, not per question
- Progress field now shows "Q4-7/13" format

Fixes #9
```

## Tests

Antes de abrir PR, corre:

```bash
pytest tests/ -v
```

Todos los tests deben pasar. Tests skippeados son ok.

## Code Style

- Máximo ~100 chars por línea
- Sin comentarios a menos que el código sea complejo
- Usa frontmatter en archivos `.md` de agentes (hidden: true, etc.)
- JSON schemas van en `schemas/`, nunca inline en agentes

## Regla de implementación

- Todo cambio de código debe estar asociado a un issue GitHub abierto
- Antes de invocar cualquier subagent o modificar archivos del framework, verificar que existe un issue activo que justifique la acción
- Si no hay issue, halt y solicitar al usuario que cree uno primero
- Commits deben seguir el formato: `type: description (Fixes #N)`
- PRs sin issue asociado serán cerrados sin revisión
- Excepciones: hotfixes críticos (label `hotfix` + aprobación de 2 maintainers)

## Pre-commit hook

El hook `scripts/validate-commit-issue.sh` valida que el mensaje de commit incluya un número de issue (`#N`). Si no lo tiene, el commit falla.

Para activar el hook:
```bash
cp scripts/validate-commit-issue.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Questions?

Abre un issue con label `question`.

---

created by caflsolution (Fixes #11)
# GitHub Issues — PRD Agent Framework

Cómo报告 y trabajar con issues en este repo.

## Workflow

```
Reportero crea issue
       ↓
Mantainer asigna labels + priority
       ↓
Discusión en comments según necesidad
       ↓
Dev trabaja en branch: `feature/#{issue}` o `fix/#{issue}`
       ↓
PR descripción incluye: `Fixes #N` o `Closes #N`
       ↓
Code review → merge
       ↓
GitHub cierra issue automáticamente
       ↓
Dev actualiza CHANGELOG.md
```

## Templates

Usa el template correspondiente al tipo de issue:

- **[Feature Request](.github/ISSUE_TEMPLATE/feature_request.md)** — nueva funcionalidad
- **[Improvement](.github/ISSUE_TEMPLATE/improvement.md)** — mejora al framework existente

Para bugs, usa el template `improvement` con label `bug`.

## Labels

| Label | Uso |
|-------|-----|
| `bug` | Algo no funciona |
| `feature` | Nueva funcionalidad |
| `improvement` | Mejora al framework existente |
| `documentation` | Docs, readme, comments |
| `question` | Discusión |
| `priority:high` | Alta prioridad |
| `priority:medium` | Media prioridad |
| `priority:low` | Baja prioridad |

## Proceso de contribución

1. **Crear issue** — usa el template apropiado
2. **Esperar triage** — mantainer asigna labels y priority
3. **Desarrollar** — crea branch desde `dev`, ej: `feature/42-batch-questions`
4. **PR** — descripción debe tener `Fixes #N` para cerrar automáticamente
5. **Merge** — code review aprobado → merge a `dev`
6. **Changelog** — actualiza `CHANGELOG.md` en el mismo commit del merge

## Closing issues automáticamente

En la descripción del PR incluye:

```
Fixes #42
```

o

```
Closes #42
```

Cuando el PR se mergea a `dev`, GitHub cierra el issue automáticamente.

## Reglas

- Issues sin template pueden ser cerrados sin comentario
- Preguntas vagass → label `question`, esperar respuesta
- Si un issue no tiene actividad por 30 días → considerar cerrar
- El branch `dev` es el destino default para PRs de features
- No hacer push directo a `main` o `dev`
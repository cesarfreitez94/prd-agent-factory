# PRD Agent

Framework de agentes especializados para generar PRDs production-ready desde una idea cruda, sin asumir funcionalidad no confirmada.

Diseñado para correr en **OpenCode** como instalación global.

---

## Cómo funciona

Le das una idea. El agente te hace preguntas una por una. Al terminar, tienes un PRD listo.

```
tú → idea
spec → valida → planifica preguntas → te entrevista (1x1) → genera PRD → valida
tú → .prd-sessions/{session}/prd.md
```

Todo el estado persiste en archivos dentro del proyecto — no en la conversación. El contexto de cada agente es mínimo por diseño.

## ¿Cómo se usa este framework?

Este repositorio contiene el **código fuente** del framework. No clones este repo para cada PRD que quieras generar.

### Para instalar el framework (una sola vez)
Sigue `INSTALL.md` para copiar los agentes a `~/.config/opencode/`.

### Para crear un PRD
1. Crea un directorio vacío para tu proyecto.
2. Abre OpenCode dentro de ese directorio.
3. Presiona **Tab** para seleccionar el agente `spec`.
4. Describe tu idea.

Tu proyecto solo contendrá `.prd-config.json` (opcional) y `.prd-sessions/` (generado automáticamente). Los agentes (`agents/`, `schemas/`, `tests/`) viven en la instalación global, no en tu proyecto.

---

## Principios de diseño

**Zero assumption** — ningún agente inventa o infiere funcionalidad que el usuario no haya confirmado explícitamente.

**Contexto mínimo** — cada agente lee solo lo que necesita. El estado vive en `ledger.json` y `questions.json`, no en el historial de conversación.

**1 pregunta a la vez** — reduce carga cognitiva y mantiene el contexto comprimido.

**Sesiones por proyecto** — `.prd-sessions/` vive dentro del proyecto, no globalmente. Varios proyectos en paralelo no se mezclan.

**Persistencia robusta** — escrituras atómicas (temp + rename), hasta 3 backups rotativos, y validación de schema en cada paso. Ver `PROTOCOL.md` §3.2–3.3.

---

## Estructura

### Framework (instalación global)

```
~/.config/opencode/
  AGENTS.md                  ← reglas globales del orquestador
  agents/
    spec.md                  ← agente primario (el que ves con Tab)
    prd-intake.md            ← valida la idea
    prd-planner.md           ← genera el set de preguntas
    prd-interviewer.md       ← conduce la entrevista 1x1
    prd-writer.md            ← genera el PRD desde el ledger
    prd-validator.md         ← verifica el PRD contra 18 checks

  schemas/
    ledger.schema.json         ← schema del contexto comprimido
    questions.schema.json      ← schema del set de preguntas
    runtime.schema.json        ← schema de validación en runtime
  templates/
    .prd-config.json           ← template de configuración por defecto
```

### Por proyecto

```
{proyecto}/
  .prd-config.json           ← configuración por proyecto (auto-creada si falta)
  .prd-sessions/
    metrics.json             ← métricas y feedback agregados
    prd-20250421-143022/
      ledger.json            ← estado comprimido (se sobreescribe por turno)
      questions.json         ← set de preguntas con estado por pregunta
      checkpoint.json        ← punto de recuperación para sesiones interrumpidas
      session.log            ← log de la sesión
      prd.md                 ← output final
      prd.v1.md              ← versiones anteriores (versionado automático)
```

---

## Instalación

```bash
# 1. Crear estructura de directorios
mkdir -p ~/.config/opencode/agents

# 2. Copiar agentes
cp agents/*.md ~/.config/opencode/agents/

# 3. Copiar reglas globales
cp AGENTS.md ~/.config/opencode/AGENTS.md

# 4. Copiar schemas (validación en runtime)
cp -r schemas/ ~/.config/opencode/schemas/

# 5. Copiar templates (config por defecto)
cp -r templates/ ~/.config/opencode/templates/
```

Ver `INSTALL.md` para instrucciones completas, incluyendo:
- Configuración opcional vía `.prd-config.json`
- Modo local (Ollama, LM Studio)
- Múltiples proyectos
- Tests locales con `pytest`

---

## Uso

1. Abre OpenCode en tu proyecto
2. Presiona **Tab** para cambiar al agente `spec`
3. Describe tu idea

```
Quiero construir una herramienta que ayude a freelancers a gestionar sus facturas
```

4. Responde las preguntas una a una — la mayoría son de selección
5. El PRD queda en `.prd-sessions/{session-id}/prd.md`

### Características del flujo

- **Validación de idea:** `prd-intake` rechaza ideas vagas y escanea PII/secrets antes de procesar.
- **Entrevista resumible:** si se interrumpe, `spec` detecta el `checkpoint.json` y pregunta si quieres continuar.
- **Versionado de PRDs:** cambios significativos generan `prd.v1.md`, `prd.v2.md`, etc. en lugar de sobrescribir.
- **18 checks de validación:** sintaxis + semántica. Aprueba, pide 1 revisión, o bloquea con reporte completo.

---

## Agentes

| Agente | Modo | Rol |
|---|---|---|
| `spec` | primary | Orquestador. El único con el que interactúas. |
| `prd-intake` | subagent (hidden) | Valida la idea. Rechaza si es muy vaga o fuera de límites. Escanea PII/secrets. |
| `prd-planner` | subagent (hidden) | Genera máx. 15 preguntas priorizadas por dependencia. |
| `prd-interviewer` | subagent (hidden) | Entrevista 1x1. Verifica congruencia. Máx. 3 reintentos por pregunta. |
| `prd-writer` | subagent (hidden) | Lee solo `ledger.json`. Escribe el PRD. Nunca inventa contenido. |
| `prd-validator` | subagent (hidden) | 18 checks fijos. Aprueba, pide 1 revisión, o bloquea con reporte. |

---

## Gestión de sesiones

Durante una sesión o después de ella, puedes pedirle a `spec`:

```
spec sessions list                    # listar todas las sesiones con estado y progreso
spec sessions delete {session-id}     # eliminar una sesión (pide confirmación)
spec sessions compare {id1} {id2}     # diff semántico entre dos versiones de PRD
spec sessions cleanup                 # borrar sesiones más antiguas que retention_days
spec feedback                         # calificar el último PRD (1–5) + comentario
```

Las sesiones no se borran automáticamente. Para limpiar manualmente:

```bash
rm -rf .prd-sessions/prd-20250101-*
```

Para no commitear sesiones al repo:

```bash
echo ".prd-sessions/" >> .gitignore
```

`spec` te preguntará si quieres hacer esto automáticamente al iniciar la primera sesión.

---

## Documentación

| Archivo | Contenido |
|---|---|
| `README.md` | Este documento. Visión general del framework. |
| `INSTALL.md` | Guía de instalación completa, configuración, modo local y tests. |
| `AGENTS.md` | Reglas operativas del orquestador `spec`. Referencia para desarrolladores. |
| `PROTOCOL.md` | Especificación técnica: atomic writes, backups, schemas, pipeline detallado. |
| `REVIEW_PROMPT.md` | Prompt para auditoría del framework. Genera `REVIEW.md` con hallazgos priorizados. |

---

## Tests (opcional)

```bash
pytest tests/
```

Incluye validación de schemas contra fixtures y consistencia del protocolo (`agents/` vs `runtime.schema.json`).

---

## Mantenimiento

Para revisar el framework y detectar mejoras usa `REVIEW_PROMPT.md`:

```
# En OpenCode, parado en este directorio:
pega el contenido de REVIEW_PROMPT.md como mensaje
```

El agente analiza el repo completo y genera `REVIEW.md` con hallazgos organizados por prioridad crítica / alta / media / baja.

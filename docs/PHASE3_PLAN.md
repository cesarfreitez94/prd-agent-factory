# PRD Agent — Plan de Mejoras Fases 3-5

> Este documento contiene el plan de trabajo para las fases restantes del PRD Agent framework.
> Cada issue tiene: root cause, fix requerido, archivos a modificar, y detalles de implementación.

---

## Phase 3: Batch Questions + Minimal Context + Silent Intake + Validation

### #9 — Interviewer: batch de preguntas en lugar de 1x1

**Problema actual:**
El interviewer lanza 1 pregunta, espera, valida, escribe checkpoint por cada turno. Multiplica los ciclos de LLM innecesariamente. Cada turno = un round-trip de red.

**Fix requerido:**
Modificar el Interview Loop a:
1. Recolectar N preguntas batcheables juntas (según `batch_size` del config)
2. Presentarlas todas juntas usando el question tool
3. Recibir todas las respuestas
4. Validar congruencia de cada una
5. Escribir checkpoint UNA SOLA VEZ al cierre del batch completo

**Archivos:**
- `agents/prd-interviewer.md`

**Detalles de implementación:**
- En el Interview Loop, después de "Determine if batching applies":
  - Recolectar hasta `batch_size` preguntas que tengan `batchable: true` Y misma `prd_section` Y `status: PENDING`
  - Presentarlas juntas: Header `[Interview | Batch Q{n}-{m}/{total} | {pct}%]`
  - Cada pregunta mantiene sus propios `options` y `free_text_if`
- Al recibir respuestas:
  - Validar congruencia de cada respuesta individualmente
  - Si alguna falla congruence: mostrar cuál falló y por qué (sin abortar todo el batch)
  - Escribir ledger.json y checkpoint.json UNA SOLA VEZ al final del batch
- El checkpoint solo se actualiza al final del batch, no por pregunta individual
- El campo `progress` en ledger.json se actualiza al final del batch: `Q4-7/13`

**Verificar:**
- Que el question tool soporte múltiples preguntas en una sola invocación
- Que el checkpoint tenga el índice de la última pregunta del batch, no la primera

---

### #10 — Interviewer: carga mínima por turno

**Problema actual:**
El interviewer dice "load per turn only" pero el Interview Loop actual carga ledger completo + todas las preguntas en cada iteración. Esto infla el contexto innecesariamente.

**Fix requerido:**
Cambiar la lógica de carga en cada iteración del loop:
- Ledger: cargar SOLO `general_summary` + `answered_context` (no todo el ledger)
- Questions: cargar SOLO la pregunta actual o el batch de preguntas batcheables (nunca el array completo)
- Nunca cargar el full ledger ni el full questions array

**Archivos:**
- `agents/prd-interviewer.md` — Context Contract + Interview Loop

**Detalles de implementación:**
- La sección "Context Contract" ya dice esto pero no está implementado consistentemente
- Modificar el loop pseudocode:
  ```
  En cada iteración:
    1. Leer solo general_summary + answered_context del ledger
    2. Leer solo las N preguntas batcheables del questions.json (por ID, no array completo)
    3. NO leer planning_status, prd_status, config_snapshot, etc.
  ```
- El checkpoint sigue guardando `answered_context` completo para resumption
- Para congruencia checks, solo comparar contra `answered_context`, no contra todo el ledger

**Verificar:**
- Que ninguna parte del loop haga `load JSON completo del archivo`

---

### #11 — prd-intake: agente silencioso

**Problema actual:**
El intake hace preguntas al usuario (confirmación de redaction de PII). Debe ser totalmente silencioso — solo valida, redacta, escribe ledger, retorna PASS/FAIL.

**Fix requerido:**
El intake ya fue parcialmente corregido en Phase 2 (redaction automática + log warning). Falta:
1. Confirmar que NO hay ningún prompt al usuario en ningún path
2. Agregar output estructurado sin narrativas

**Archivos:**
- `agents/prd-intake.md` — Step 1, Output

**Detalles de implementación:**
- En Step 1 (PII): ya tiene redaction automática + log. Confirmar que NO hay `question tool` ni `input()` ni ningún prompt
- Output debe ser ESTRICTAMENTE estructurado:
  ```
  INTAKE_RESULT: PASS
  SUMMARY: {one line summary}
  SESSION: {session-id}
  ```
  o
  ```
  INTAKE_RESULT: FAIL
  REASON: {reason}
  DETAIL: {detail}
  RETRY: true|false
  ```
- No hay output narrativo. No hay logs visibles al usuario. Solo estos outputs estructurados.
- El intake debe retornar, no "esperar" respuesta del usuario

**Verificar:**
- Buscar cualquier string que parezca prompt: "?", "¿", "Do you", "Want to", "Continue", etc.

---

### #13 — Validación de output por agente al cerrar ciclo

**Problema actual:**
Errores silenciosos se arrastran al siguiente agente. No hay validación del output antes de escribir. Si un agente escribe JSON inválido, el siguiente agente falla sin contexto.

**Fix requerido:**
Cada agente debe:
1. Escribir output a tmp file
2. Validar contra el schema correspondiente
3. Solo si validation PASS: rename tmp → final
4. Si validation FAIL: delete tmp file + return error estructurado

**Archivos:**
- Todos los agentes: `prd-intake.md`, `prd-planner.md`, `prd-interviewer.md`, `prd-writer.md`, `prd-validator.md`
- `PROTOCOL.md` §3.2

**Detalles de implementación:**
- prd-intake: ya tiene esto en atomic write protocol. Verificar que también valide antes del rename
- prd-planner: necesita implementar validación de questions.json antes del rename
- prd-interviewer: necesita validar ledger.json antes del rename (ya lo hace parcialmente)
- prd-writer: NO reescribe prd.md sin validar que el contenido esté bien
- prd-validator: NO actualiza ledger.json sin validar el prd_status

Para cada agente, agregar al final del ciclo:
```
1. Write to tmp/
2. Validate against schema
3. On pass: rename to final
4. On fail: rm tmp/, return ERROR: {detail}
```

Actualizar PROTOCOL.md §3.2 para explicitar que la validación es OBLIGATORIA, no opcional.

**Verificar:**
- Cada agente tiene Try/Except alrededor del rename
- Si validation fail, el agente no se queda colgado

---

## Phase 4: UX Status + Verbosity + General Summary + Telemetry

### #7 — Status visible del pipeline para el usuario

**Problema actual:**
El usuario no sabe si debe actuar o esperar. No hay ningún indicador de progreso por etapa. Solo ve logs internos de spec.

**Fix requerido:**
Spec debe hacer output visible al usuario después de cada etapa:
- `✅ Idea validada — generando preguntas...`
- `📋 13 preguntas generadas — iniciando entrevista`
- `❓ [3/13] ¿Quién es el usuario primario?`
- `✅ Entrevista completa — generando PRD...`
- `📄 PRD generado — validando...`

**Archivos:**
- `agents/spec.md` — Pipeline Sequence + Handling Results
- `PROTOCOL.md` §7 (actualizar para incluir UX del pipeline)

**Detalles de implementación:**
- Agregar después de cada invoke de subagente:
  ```
  Si intake PASS → print: "✅ Idea validada — creando sesión..."
  Si planner COMPLETE → print: "📋 {n} preguntas generadas — iniciando entrevista"
  Si interview IN_PROGRESS → print per question: "❓ [{n}/{total}] {question_text}"
  Si interview COMPLETE → print: "✅ Entrevista completa ({answered}/{total}) — generando PRD..."
  Si writer COMPLETE → print: "📄 PRD v{n} generado — validando..."
  Si validator APPROVED → print: "✅ PRD APLICADO — tu archivo está en .prd-sessions/{id}/prd.md"
  ```
- NO usar logs internos para el usuario. Los logs son para debugging, el output estructurado es para el usuario.
- Opcional: agregar `pipeline_status` field en ledger.json para debugging

**Verificar:**
- Que el output sea visible para el usuario (no solo en session.log)
- Que no sea tan verboso como para inflar el contexto

---

### #8 — Agentes silenciosos (12–14k tokens eliminables)

**Problema actual:**
spec e interviewer generan output muy verboso (12-14k tokens). Los agentes deben ser silenciosos — solo output estructurado hacia spec, no narrativas innecesarias.

**Fix requerido:**
- spec: solo delega y reporta resultado. No narrar qué hace ni por qué.
- interviewer: solo presenta pregunta, recibe respuesta, escribe checkpoint. No explicar congruencia, no narrar acciones.

**Archivos:**
- `agents/spec.md` — Tone
- `agents/prd-interviewer.md` — Interview Loop, Congruence Check

**Detalles de implementación:**
- spec.md: eliminar toda narrativa tipo "Voy a validar tu idea...", "Ahora voy a crear la sesión...", etc.
  - Solo: validate config → invoke intake → on PASS: invoke planner → etc.
  - El output al usuario es solo: "¿Cuál es tu idea?" (antes de intake) y luego los status messages de #7
- prd-interviewer.md: eliminar explicaciones de congruencia en el output
  - El output al usuario es SOLO la pregunta en formato estructurado
  - Si congruence fail: re-presentar la pregunta con contexto mínimo
  - No narrar "Checking if answer is congruent...", "Updating ledger...", etc.

Regla: cada agente debe poder ejecutar sin generar más de 500 tokens de output no estructurado por ciclo.

**Verificar:**
- Contar tokens de output en un ciclo típico de cada agente
- Asegurar que el output sea estructurado y minimal

---

### #12 — general_summary evolutivo

**Problema actual:**
`general_summary` se escribe en intake y nunca cambia. Si el interview contradice la idea original (ej: usuario dice que quiere B2C pero en preguntas revela B2B), el writer genera desde un summary desactualizado.

**Fix requerido:**
Actualizar `general_summary` al final del interview basándose en `answered_context` final.

**Archivos:**
- `agents/prd-interviewer.md` — On Completion
- `agents/prd-writer.md` — Context Contract

**Detalles de implementación:**
- En "On Completion" del interviewer, antes de setear `interview_status: "COMPLETE"`:
  1. Generar nuevo `general_summary` desde `answered_context` final
  2. Comparar con el `general_summary` original del intake
  3. Si hay contradicción (ej: target_user cambió drásticamente), marcar en ledger: `general_summary_stale: true`
  4. Escribir el nuevo summary al ledger

El nuevo summary debe ser:
```
"One sentence. Derived from answered_context. Refleja lo que el usuario confirmó, no lo que pensó al inicio."
```

- prd-writer.md: si `general_summary_stale: true`, recalcular el Executive Summary desde `answered_context` en lugar de usar `general_summary`.

**Verificar:**
- Que el writer detecte si el summary está stale
- Que el nuevo summary sea consistente con answered_context

---

### #14 — Telemetría de tokens

**Problema actual:**
No hay forma de saber cuánto gastó cada agente. Sin métricas de costos.

**Fix requerido:**
Agregar tracking de tokens por agente en session.log.

**Archivos:**
- `agents/spec.md` — Logging
- Todos los agentes — Output sections
- `PROTOCOL.md` §8 (Observability)
- `schemas/runtime.schema.json` — session_log format

**Detalles de implementación:**
- Cada agente, al cerrar, reporta al log:
  ```
  [{timestamp}] [INFO] [prd-intake] END result=PASS tokens_in={n} tokens_out={n} session={id}
  ```
- Opcional: acumular en `metrics.json` del proyecto:
  ```json
  {
    "total_sessions": 5,
    "avg_tokens_per_session": 45000,
    "by_agent": {
      "intake": { "avg_in": 1000, "avg_out": 800 },
      "planner": { "avg_in": 2000, "avg_out": 3000 },
      ...
    }
  }
  ```
- Para implementar: los agentes deben obtener tokens_used de la respuesta del LLM y escribirlo al log
- spec es quien agrega las entradas al log, no cada agente individualmente (los agentes escriben a session.log vía append)

**Verificar:**
- Que el log tenga el formato correcto
- Que los números sean razonables

---

## Phase 5: Tech Stack Check + Hash + User Docs

### #15 — Check de tecnología/implementación en validator

**Problema actual:**
El writer puede mencionar stack o implementación en el PRD (ej: "usa React", "guarda en PostgreSQL"). No hay check en el validator para esto.

**Fix requerido:**
1. Agregar regla I8 en prd-validator.md (Content Integrity)
2. Reforzar en prd-writer.md que no debe mencionar tecnología

**Archivos:**
- `agents/prd-validator.md` — Content Integrity (I1-I7)
- `agents/prd-writer.md` — Generation Rules

**Detalles de implementación:**
- En prd-validator.md, agregar:
  ```
  ### Content Integrity (adicional)
  - [ ] **I8** — No mention of specific technology stack, architecture, or implementation decisions (DB, framework, cloud provider) unless explicitly confirmed in `answered_context.constraints`
  ```
- En prd-writer.md, reforzar:
  ```
  **No implementation decisions.** Define what and why. Never specify how (architecture, DB, tech stack) unless explicitly in `answered_context.constraints`.
  ```

**Verificar:**
- Probar con PRD que mencione "React" o "PostgreSQL" sin estar en constraints → debe fallar I8

---

### #16 — Hash mejorado para deduplicación

**Problema actual:**
`raw_idea_hash` trunca los primeros 100 chars. No identifica la esencia, no sirve para deduplicación. Dos ideas similares con diferente开局 producirían hashes diferentes.

**Fix requerido:**
Cambiar el hash de "primeros 100 chars" a un fingerprint más representativo.

**Archivos:**
- `agents/prd-intake.md` — Step 3 (ledger content)
- `schemas/ledger.schema.json` — raw_idea_hash description

**Detalles de implementación:**
- Cambiar el cálculo de `raw_idea_hash`:
  - Opción A (recomendada): SHA-256 de la idea completa, tomar los primeros 16 hex chars
  - Opción B: fingerprint = normalize(primera oración) + "|" + normalize(última oración) + "|" + length
- En prd-intake.md Step 3:
  ```
  "raw_idea_hash": "{sha256(raw_idea)[:16]}"
  ```
- En ledger.schema.json: actualizar description del campo
- Para calcular: usar python/bash para sha256, no hay librería needed

**Verificar:**
- Dos ideas similares deben producir hashes idénticos
- Hash debe ser deterministic (misma idea = mismo hash)

---

### #17 — Documentación de workflow para el usuario

**Problema actual:**
El usuario no tiene una vista del flujo completo: qué hace cada agente, cuándo interviene, qué esperar.

**Fix requerido:**
Agregar sección clara en README.md con el flujo del pipeline.

**Archivos:**
- `README.md` — agregar sección "Flujo del Pipeline"
- `INSTALL.md` —referencia a la sección

**Detalles de implementación:**
En README.md, después de "¿Cómo se usa este framework?":
```
## Flujo del Pipeline

El pipeline tiene 5 etapas. Tú solo interactúas con spec — los subagentes trabajan silenciosamente.

### Etapas

| Etapa | Agente | Qué hace | Tu intervención |
|-------|--------|----------|-----------------|
| 1. Validación | prd-intake | Valida tu idea, detecta PII, crea sesión | Solo la idea inicial |
| 2. Planificación | prd-planner | Genera preguntas prioritizadas | Ninguna |
| 3. Entrevista | prd-interviewer | Te hace preguntas una por una | Respuestas a preguntas |
| 4. Escritura | prd-writer | Genera el PRD desde tus respuestas | Ninguna |
| 5. Validación | prd-validator | Verifica 18 checks + semántica | Ninguna |

### Estados del pipeline

- `INTAKE_FAIL` → Tu idea fue rechazada (vaga o fuera de límites). Reformula.
- `IN_PROGRESS` → La entrevista está en curso. Sigue respondiendo.
- `NEEDS_REVIEW` → El PRD requiere revisión manual después de 2 intentos fallidos.
- `BLOCKED` → El PRD tiene errores críticos que no se pueden auto-corregir.
- `FINAL` → El PRD está listo.

### Cuándo intervienes

Solo en dos momentos:
1. **Al inicio:** Describe tu idea
2. **Durante la entrevista:** Responde las preguntas de selección

Todo lo demás es automático y silencioso.
```

**Verificar:**
- Que la sección sea clara para alguien que no conoce el framework
- Que los estados estén correctamente descritos

---

## Resumen de cambios por archivo

| Archivo | Phase 3 | Phase 4 | Phase 5 |
|---------|---------|---------|---------|
| `agents/spec.md` | — | #7, #8 | — |
| `agents/prd-intake.md` | #11, #13 | — | #16 |
| `agents/prd-planner.md` | #13 | #14 | — |
| `agents/prd-interviewer.md` | #9, #10, #13 | #8, #12, #14 | — |
| `agents/prd-writer.md` | #13 | #12 | #15 |
| `agents/prd-validator.md` | #13 | — | #15 |
| `schemas/ledger.schema.json` | — | — | #16 |
| `PROTOCOL.md` | #13 | #7, #14 | — |
| `README.md` | — | — | #17 |
| `INSTALL.md` | — | — | #17 |

---

## estado actual

### Completado (Phase 1 + Phase 2)

**Phase 1 - Críticos:**
- #1: `revision_count` en ledger.schema.json + validator state machine (max 1 revision, terminal en NEEDS_REVIEW/BLOCKED)
- #4: `bash: allow` en prd-validator.md
- #6: spec.md trata BLOCKED y NEEDS_REVIEW como estados terminales

**Phase 2 - Arquitectura:**
- #2: spec.md ahora solo delega; sesión se crea después de intake PASS
- #3: runtime.schema.json documenta resolución de .prd-config.json
- #5: runtime.schema.json tiene `schema_resolution` con search order

### Pendiente

**Phase 3:**
- #9, #10, #11, #13

**Phase 4:**
- #7, #8, #12, #14

**Phase 5:**
- #15, #16, #17

---

## Tests

Después de cada fase, ejecutar:
```bash
pytest tests/ -v
```

Los tests incluyen:
- `test_all_agent_paths_declared_in_runtime_schema` — paths en agentes vs runtime.schema.json
- `test_all_agents_reference_runtime_schema` — todos referencian el schema
- `test_checkpoint_schema_completeness` — checkpoint.json documentado
- `test_mock_ledger_has_required_fields` — campos requeridos en ledger
- `test_mock_questions_has_required_fields` — campos requeridos en questions
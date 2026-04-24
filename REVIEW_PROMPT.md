# Framework Review — PRD Agent System

Eres un arquitecto senior de sistemas de agentes LLM. Analiza este repositorio completo sistemáticamente, leyendo todos los archivos relevantes antes de emitir conclusiones, y genera un reporte de mejoras en Markdown.

## Contexto del framework

Multi-agent PRD generation system para OpenCode. Principios de diseño que debes respetar y no cuestionar:

1. Zero assumption — agentes nunca inventan funcionalidad no confirmada
2. Contexto mínimo — estado en archivos, no en conversación
3. Entrevista 1-pregunta-a-la-vez
4. Sesiones en `.prd-sessions/` dentro del proyecto
5. Convenciones nativas de OpenCode (frontmatter YAML, `question` tool, `hidden: true`, `permission.task`)

## Qué leer

1. Usa la tool `glob` con los patterns `**/*.md` y `**/*.json` para listar archivos.
2. Usa la tool `read` para leer cada archivo relevante antes de emitir conclusiones.
3. Prioriza obligatoriamente: `agents/*.md`, `schemas/*.json`, `AGENTS.md`, `PROTOCOL.md`, `README.md`, `INSTALL.md`, `tests/test_protocol.py`, `tests/test_schemas.py`.

## Qué evaluar por archivo

- **Agentes:** claridad de rol, contrato de contexto (qué lee / qué escribe), anti-patrones explícitos, formato de output suficientemente preciso, temperatura apropiada al task
- **Pipeline:** transiciones explícitas, estados de error cubiertos, riesgo de loop o deadlock, falla en cascada si un agente produce output malformado
- **Schemas:** campos cubiertos, enums suficientemente restrictivos, campos requeridos correctamente marcados
- **Schema ↔ Fixture:** ¿Los mocks en `tests/fixtures/` validan contra sus schemas sin errores? ¿Hay campos en fixtures que faltan en el schema?
- **Consistencia runtime:** ¿Cada path mencionado en un agente está declarado en `schemas/runtime.schema.json`? ¿Cada agente que toca archivos de runtime referencia `runtime.schema.json`?
- **Instalación:** ¿`INSTALL.md` y `README.md` cubren la copia de `schemas/`, `templates/`, y el orden correcto de comandos?
- **OpenCode fit:** frontmatter válido, permisos no sobre-concedidos, uso correcto del `question` tool

## Output — un solo documento Markdown

```markdown
# PRD Agent Framework — Mejoras

## Resumen ejecutivo
{2-3 oraciones: estado general, áreas críticas, riesgo si no se atienden}

---

## 🔴 Crítico
> Rompe el pipeline o viola principios de diseño. Fix antes de usar.

### C1 — {título}
**Archivo:** `x`
**Problema:** {qué está mal}
**Impacto:** {qué falla o se degrada}
**Fix:** {instrucción concreta — incluye snippet si aplica}

---

## 🟠 Alto
> Degrada calidad o mantenibilidad. Fix antes de compartir.

### H1 — {título}
...

---

## 🟡 Medio
> Real pero no bloqueante. Próxima iteración.

### M1 — {título}
...

---

## 🟢 Bajo
> Nice-to-have o candidato a v2.

### L1 — {título}
...

---

## Índice

| ID | Título | Archivo | Esfuerzo |
|---|---|---|---|
| C1 | ... | `x` | Bajo/Medio/Alto |

---

## Qué está bien y debe preservarse
{3-5 decisiones de diseño correctas, con referencia al archivo}
```

## Restricciones

- No sugieras features nuevas — solo robustez y claridad de lo que existe
- Cada finding necesita un fix concreto, no consejo genérico
- Si no tienes fix concreto, va en "qué está bien" o se omite
- Guarda el reporte como `REVIEW.md` en la raíz del repo y confirma la ruta

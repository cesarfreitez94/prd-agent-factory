#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PRD Agent Framework — Instalador / Actualizador
# =============================================================================
# Uso:
#   ./install.sh              Instala o actualiza el framework
#   ./install.sh --dry-run    Simula sin modificar archivos
#   ./install.sh --uninstall  Elimina la instalación (pide confirmación)
#   ./install.sh --help       Muestra ayuda
# =============================================================================

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${HOME}/.config/opencode"
BACKUP_DIR="${TARGET_DIR}/backup"
TIMESTAMP=$(date +%s)
BACKUP_NAME="prd-agent-backup-${TIMESTAMP}.tar.gz"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

DRY_RUN=false
UNINSTALL=false

# Colores
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'
C_DIM='\033[2m'

# Componentes
COMPONENTS=("AGENTS.md" "agents" "schemas" "templates")

# ============================================================================
# Logging
# ============================================================================
log_info()  { echo -e "${C_CYAN}[INFO]${C_RESET}  $1"; }
log_ok()    { echo -e "${C_GREEN}[OK]${C_RESET}    $1"; }
log_warn()  { echo -e "${C_YELLOW}[AVISO]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET}  $1"; }

print_header() {
    echo
    echo -e "${C_BOLD}$1${C_RESET}"
    echo -e "${C_DIM}$(printf '=%.0s' $(seq 1 ${#1}))${C_RESET}"
    echo
}

# ============================================================================
# Ayuda
# ============================================================================
print_help() {
    cat <<'EOF'
PRD Agent Framework — Instalador / Actualizador

Uso:
  ./install.sh [opciones]

Opciones:
  --dry-run     Simula la instalación sin modificar archivos
  --uninstall   Elimina la instalación del framework (pide confirmación)
  --help        Muestra esta ayuda

Ejemplos:
  ./install.sh            Instala o actualiza con menú interactivo
  ./install.sh --dry-run  Simula sin tocar nada
  ./install.sh --uninstall  Desinstala el framework

Flujo interactivo:
  Si ya existe una instalación previa, se creará un respaldo .tar.gz
  y se mostrará un menú para elegir:
    1) Actualizar TODO
    2) Revisar uno por uno (s/N/a/q)
    3) Seleccionar componentes
    4) Cancelar

  Tras copiar los archivos, se consultará OpenRouter para configurar
  el modelo de cada agente (o dejar el valor por defecto).
EOF
}

# ============================================================================
# Validación de entorno fuente
# ============================================================================
verify_source() {
    local missing=()
    for item in agents schemas templates AGENTS.md; do
        if [[ ! -e "${SOURCE_DIR}/${item}" ]]; then
            missing+=("${item}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Faltan archivos/directorios necesarios en el repo:"
        printf '  - %s\n' "${missing[@]}"
        exit 1
    fi
}

# ============================================================================
# Detectar instalación previa
# ============================================================================
detect_existing() {
    local found=0
    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            ((found++)) || true
        fi
    done
    echo "${found}"
}

# ============================================================================
# Mostrar estado de componentes instalados
# ============================================================================
show_components_status() {
    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            echo -e "  ${C_GREEN}✓${C_RESET} ${comp}"
        else
            echo -e "  ${C_DIM}✗ ${comp}${C_RESET}"
        fi
    done
}

# ============================================================================
# Crear backup completo .tar.gz
# ============================================================================
create_backup() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Se crearía respaldo: ${BACKUP_PATH/#${HOME}/~}"
        return
    fi

    mkdir -p "${BACKUP_DIR}"

    # Solo incluir lo que existe
    local existing=()
    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            existing+=("${comp}")
        fi
    done

    if [[ ${#existing[@]} -eq 0 ]]; then
        log_warn "No hay nada que respaldar."
        return
    fi

    log_info "Creando respaldo completo..."
    (cd "${TARGET_DIR}" && tar -czf "${BACKUP_PATH}" "${existing[@]}")
    log_ok "Respaldo creado: ${BACKUP_PATH/#${HOME}/~}"
}

# ============================================================================
# Copiar un componente
# ============================================================================
copy_component() {
    local comp="$1"
    local src="${SOURCE_DIR}/${comp}"
    local dst="${TARGET_DIR}/${comp}"

    if [[ "${DRY_RUN}" == true ]]; then
        if [[ -d "${src}" ]]; then
            log_info "[dry-run] Copiar: ${comp}/ → ~/.config/opencode/${comp}/"
        else
            log_info "[dry-run] Copiar: ${comp} → ~/.config/opencode/${comp}"
        fi
        return
    fi

    # Si existe en destino, eliminar primero (para reemplazo limpio)
    if [[ -e "${dst}" ]]; then
        rm -rf "${dst}"
    fi

    # Asegurar que el directorio padre existe
    mkdir -p "$(dirname "${dst}")"

    cp -a "${src}" "${dst}"
}

# ============================================================================
# Verificación post-instalación
# ============================================================================
verify_installation() {
    local errors=0
    local files=(
        "${TARGET_DIR}/AGENTS.md"
        "${TARGET_DIR}/agents/spec.md"
        "${TARGET_DIR}/agents/prd-intake.md"
        "${TARGET_DIR}/agents/prd-planner.md"
        "${TARGET_DIR}/agents/prd-interviewer.md"
        "${TARGET_DIR}/agents/prd-writer.md"
        "${TARGET_DIR}/agents/prd-validator.md"
        "${TARGET_DIR}/schemas/ledger.schema.json"
        "${TARGET_DIR}/schemas/questions.schema.json"
        "${TARGET_DIR}/schemas/checkpoint.schema.json"
        "${TARGET_DIR}/schemas/runtime.schema.json"
        "${TARGET_DIR}/templates/.prd-config.json"
    )

    log_info "Verificando instalación..."
    for f in "${files[@]}"; do
        if [[ -e "${f}" ]]; then
            log_ok "Existe: ${f/#${HOME}/~}"
        else
            log_error "Falta: ${f/#${HOME}/~}"
            ((errors++)) || true
        fi
    done

    return "${errors}"
}

# ============================================================================
# Tests opcionales con pytest
# ============================================================================
run_optional_tests() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Se saltaría validación con pytest"
        return
    fi

    if ! command -v pytest &>/dev/null; then
        log_warn "pytest no está instalado. Se omite validación."
        return
    fi

    if [[ ! -d "${SOURCE_DIR}/tests" ]]; then
        log_warn "No se encontró tests/. Se omite validación."
        return
    fi

    echo
    read -r -p "¿Ejecutar pytest para validar integridad? [s/N]: " resp
    if [[ "${resp}" =~ ^[Ss]$ ]]; then
        log_info "Ejecutando pytest..."
        if (cd "${SOURCE_DIR}" && pytest tests/ -v); then
            log_ok "Validación con pytest exitosa."
        else
            log_warn "pytest reportó errores. Revisa arriba."
        fi
    else
        log_info "Validación omitida."
    fi
}

# ============================================================================
# Opción 1: Actualizar TODO
# ============================================================================
update_all() {
    print_header "Actualizando TODO"
    create_backup

    for comp in "${COMPONENTS[@]}"; do
        copy_component "${comp}"
    done

    log_ok "Todos los componentes actualizados."
}

# ============================================================================
# Opción 2: Uno por uno (s/N/a/q)
# ============================================================================
update_one_by_one() {
    print_header "Revisando uno por uno"
    create_backup

    local auto_yes=false

    for comp in "${COMPONENTS[@]}"; do
        if [[ ! -e "${TARGET_DIR}/${comp}" ]]; then
            # No existe → copiar directamente
            log_info "'${comp}' no existe → se instalará."
            copy_component "${comp}"
            continue
        fi

        if [[ "${auto_yes}" == true ]]; then
            log_info "Sobrescribiendo: ${comp}"
            copy_component "${comp}"
            continue
        fi

        echo
        read -r -p "'${comp}' ya existe. ¿Sobrescribir? [s/N/a(all)/q(uit)]: " choice
        case "${choice}" in
            [sS])
                copy_component "${comp}"
                ;;
            [aA])
                auto_yes=true
                copy_component "${comp}"
                ;;
            [qQ])
                log_info "Cancelado por el usuario."
                return 1
                ;;
            *)
                log_info "Saltado: ${comp}"
                ;;
        esac
    done

    return 0
}

# ============================================================================
# Opción 3: Seleccionar componentes
# ============================================================================
update_select() {
    print_header "Seleccionar componentes"

    echo "Componentes disponibles:"
    local i=1
    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            echo -e "  ${i}. ${comp} ${C_YELLOW}(existente)${C_RESET}"
        else
            echo -e "  ${i}. ${comp} ${C_DIM}(nuevo)${C_RESET}"
        fi
        ((i++)) || true
    done
    echo "  a. Todos"
    echo "  q. Cancelar"
    echo

    read -r -p "Selecciona (números separados por espacio): " selection

    if [[ "${selection}" =~ ^[qQ]$ ]]; then
        log_info "Cancelado."
        return 1
    fi

    create_backup

    if [[ "${selection}" =~ ^[aA]$ ]]; then
        for comp in "${COMPONENTS[@]}"; do
            copy_component "${comp}"
        done
        log_ok "Todos los componentes actualizados."
        return 0
    fi

    local selected=()
    for num in ${selection}; do
        if [[ "${num}" =~ ^[0-9]+$ && "${num}" -ge 1 && "${num}" -le ${#COMPONENTS[@]} ]]; then
            local idx=$((num - 1))
            selected+=("${COMPONENTS[idx]}")
        else
            log_warn "Opción ignorada: ${num}"
        fi
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        log_warn "Ningún componente seleccionado."
        return 1
    fi

    for comp in "${selected[@]}"; do
        copy_component "${comp}"
    done

    log_ok "Componentes seleccionados actualizados."
    return 0
}

# ============================================================================
# Menú interactivo principal
# ============================================================================
show_menu() {
    print_header "Instalación previa detectada"

    echo "Componentes existentes:"
    show_components_status
    echo

    if [[ "${DRY_RUN}" == false ]]; then
        echo -e "Se creará respaldo en: ${C_DIM}${BACKUP_PATH/#${HOME}/~}${C_RESET}"
        echo
    fi

    echo "¿Qué deseas hacer?"
    echo
    echo "  1) Actualizar TODO (respaldar y reemplazar todo)"
    echo "  2) Revisar uno por uno (preguntar por cada componente)"
    echo "  3) Seleccionar componentes a actualizar"
    echo "  4) Cancelar"
    echo

    read -r -p "Opción [1-4]: " choice
    echo

    case "${choice}" in
        1)
            update_all
            ;;
        2)
            update_one_by_one
            ;;
        3)
            update_select
            ;;
        4)
            log_info "Cancelado."
            exit 0
            ;;
        *)
            log_warn "Opción inválida."
            exit 1
            ;;
    esac
}

# ============================================================================
# Instalación limpia (sin menú)
# ============================================================================
run_fresh_install() {
    print_header "Instalando PRD Agent Framework"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "=== MODO SIMULACIÓN (--dry-run) ==="
        log_info "No se modificará ningún archivo."
        echo
    fi

    # Crear target
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Crear directorio: ~/.config/opencode"
    else
        mkdir -p "${TARGET_DIR}"
    fi

    for comp in "${COMPONENTS[@]}"; do
        copy_component "${comp}"
    done
}

# ============================================================================
# Desinstalación
# ============================================================================
run_uninstall() {
    echo
    print_header "Desinstalar PRD Agent Framework"

    echo "Se eliminarán los siguientes elementos de:"
    echo "  ${TARGET_DIR/#${HOME}/~}"
    echo

    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            echo -e "  ${C_RED}✗${C_RESET} ${comp}"
        fi
    done
    echo

    read -r -p "Escribe 'yes' para confirmar la desinstalación: " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Desinstalación cancelada."
        exit 0
    fi

    local removed=0
    for comp in "${COMPONENTS[@]}"; do
        if [[ -e "${TARGET_DIR}/${comp}" ]]; then
            rm -rf "${TARGET_DIR:?}/${comp}"
            log_ok "Eliminado: ${comp}"
            ((removed++)) || true
        fi
    done

    if [[ "${removed}" -eq 0 ]]; then
        log_warn "No se encontró nada que desinstalar."
    else
        log_ok "Desinstalación completada."
    fi
}

# ============================================================================
# Fetch modelos desde OpenRouter
# ============================================================================
fetch_models() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Se consultaría OpenRouter para modelos"
        return
    fi

    log_info "Descargando catálogo de modelos desde OpenRouter..."

    if ! command -v curl &>/dev/null; then
        log_error "curl no está instalado. Es requerido para obtener modelos."
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        log_error "python3 no está instalado. Es requerido para procesar modelos."
        exit 1
    fi

    local tmp_response
    tmp_response=$(mktemp)

    if ! curl -s --fail https://openrouter.ai/api/v1/models -o "${tmp_response}"; then
        rm -f "${tmp_response}"
        log_error "No se pudo conectar a OpenRouter. Verifica tu conexión."
        exit 1
    fi

    python3 - "${tmp_response}" "${SOURCE_DIR}/models.json" <<'PYEOF'
import json, sys

with open(sys.argv[1], 'r') as f:
    data = json.load(f)

models = data.get('data', [])
providers = {}

for m in models:
    mid = m.get('id', '')
    if '/' not in mid:
        continue
    prov = mid.split('/')[0]
    if prov not in providers:
        providers[prov] = []
    pricing = m.get('pricing', {})
    providers[prov].append({
        'id': mid,
        'name': m.get('name', mid),
        'prompt': pricing.get('prompt', '?'),
        'completion': pricing.get('completion', '?')
    })

priority = ['anthropic', 'openai', 'google', 'moonshotai']
ordered = []

for p in priority:
    if p in providers:
        ordered.append({'name': p, 'models': providers.pop(p)})

for p in sorted(providers.keys(), key=lambda x: -len(providers[x])):
    ordered.append({'name': p, 'models': providers[p]})

output = {'providers': ordered}
with open(sys.argv[2], 'w') as f:
    json.dump(output, f, indent=2)

print(len(models))
PYEOF

    local py_status=$?
    rm -f "${tmp_response}"

    if [[ $py_status -ne 0 ]]; then
        log_error "Error procesando respuesta de OpenRouter."
        exit 1
    fi

    log_ok "Catálogo descargado exitosamente."
}

# ============================================================================
# Variables globales para selección
# ============================================================================
SELECTED_VALUE=""

# ============================================================================
# Seleccionar compañía (paginado)
# ============================================================================
# Guarda el índice del proveedor en SELECTED_VALUE.
# Return: 0 = éxito, 1 = cancelado
# ============================================================================
select_company() {
    SELECTED_VALUE=""
    local models_file="${SOURCE_DIR}/models.json"

    local providers_info
    providers_info=$(python3 - "${models_file}" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for i, p in enumerate(data['providers']):
    print(f"{i}|{p['name']}|{len(p['models'])}")
PYEOF
)

    local all_names=()
    local all_counts=()
    local total=0
    while IFS='|' read -r idx name count; do
        all_names+=("$name")
        all_counts+=("$count")
        ((total++)) || true
    done <<< "$providers_info"

    local offset=4
    local per_page=10
    local page=0

    while true; do
        echo
        echo "Compañías disponibles:"
        echo

        for i in $(seq 0 $((offset - 1))); do
            if [[ $i -lt $total ]]; then
                printf "  %2d. %-25s %3s modelos\n" "$((i+1))" "${all_names[$i]}" "${all_counts[$i]}"
            fi
        done

        echo "  ---"

        local start=$((offset + page * per_page))
        local end=$((start + per_page))
        for i in $(seq $start $((end - 1))); do
            if [[ $i -lt $total ]]; then
                printf "  %2d. %-25s %3s modelos\n" "$((i+1))" "${all_names[$i]}" "${all_counts[$i]}"
            fi
        done

        local rest_total=$((total - offset))
        local total_pages=0
        if [[ $rest_total -gt 0 ]]; then
            total_pages=$(((rest_total + per_page - 1) / per_page))
        fi
        local current_page=$((page + 1))

        echo
        if [[ $total_pages -gt 1 ]]; then
            echo "  Página ${current_page}/${total_pages}"
        fi
        if [[ $((page + 1)) -lt $total_pages ]]; then
            echo "  n. Siguiente página"
        fi
        if [[ $page -gt 0 ]]; then
            echo "  p. Página anterior"
        fi
        echo "  q. Cancelar / Saltar"
        echo

        read -r -p "Selecciona compañía [1-${total}, n, p, q]: " choice

        case "$choice" in
            [qQ])
                return 1
                ;;
            [nN])
                if [[ $((page + 1)) -lt $total_pages ]]; then
                    ((page++)) || true
                fi
                ;;
            [pP])
                if [[ $page -gt 0 ]]; then
                    ((page--)) || true
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $total ]]; then
                    SELECTED_VALUE="$((choice - 1))"
                    return 0
                fi
                log_warn "Opción inválida."
                ;;
        esac
    done
}

# ============================================================================
# Seleccionar modelo (paginado, con precios, volver atrás)
# ============================================================================
# Guarda el id del modelo en SELECTED_VALUE.
# Return: 0 = éxito, 1 = cancelado, 2 = volver atrás
# ============================================================================
select_model() {
    SELECTED_VALUE=""
    local provider_idx="$1"
    local models_file="${SOURCE_DIR}/models.json"

    local models_info
    models_info=$(python3 - "$provider_idx" "$models_file" <<'PYEOF'
import json, sys
idx = int(sys.argv[1])
with open(sys.argv[2]) as f:
    data = json.load(f)
p = data['providers'][idx]
for i, m in enumerate(p['models']):
    print(f"{i}|{m['id']}|{m['name']}|{m['prompt']}|{m['completion']}")
PYEOF
)

    local all_ids=()
    local all_names=()
    local all_prompts=()
    local all_completions=()
    local total=0
    while IFS='|' read -r idx id name prompt completion; do
        all_ids+=("$id")
        all_names+=("$name")
        all_prompts+=("$prompt")
        all_completions+=("$completion")
        ((total++)) || true
    done <<< "$models_info"

    local per_page=10
    local page=0
    local total_pages=$(((total + per_page - 1) / per_page))

    while true; do
        echo
        echo "Modelos disponibles:"
        echo

        local start=$((page * per_page))
        local end=$((start + per_page))
        for i in $(seq $start $((end - 1))); do
            if [[ $i -lt $total ]]; then
                local name="${all_names[$i]}"
                local prompt="${all_prompts[$i]}"
                local completion="${all_completions[$i]}"
                printf "  %2d. %-45s  prompt \$%s  completion \$%s\n" "$((i+1))" "$name" "$prompt" "$completion"
                echo "      ID: ${all_ids[$i]}"
            fi
        done

        local current_page=$((page + 1))

        echo
        if [[ $total_pages -gt 1 ]]; then
            echo "  Página ${current_page}/${total_pages}"
        fi
        if [[ $((page + 1)) -lt $total_pages ]]; then
            echo "  n. Siguiente página"
        fi
        if [[ $page -gt 0 ]]; then
            echo "  p. Página anterior"
        fi
        echo "  b. Volver a compañías"
        echo "  q. Cancelar / Saltar"
        echo

        read -r -p "Selecciona modelo [1-${total}, n, p, b, q]: " choice

        case "$choice" in
            [qQ])
                return 1
                ;;
            [bB])
                return 2
                ;;
            [nN])
                if [[ $((page + 1)) -lt $total_pages ]]; then
                    ((page++)) || true
                fi
                ;;
            [pP])
                if [[ $page -gt 0 ]]; then
                    ((page--)) || true
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $total ]]; then
                    SELECTED_VALUE="${all_ids[$((choice - 1))]}"
                    return 0
                fi
                log_warn "Opción inválida."
                ;;
        esac
    done
}

# ============================================================================
# Configurar modelos de agentes
# ============================================================================
configure_agent_models() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Se saltaría configuración de modelos"
        return
    fi

    if [[ ! -f "${SOURCE_DIR}/models.json" ]]; then
        log_warn "No se encontró models.json. Se omite configuración de modelos."
        return
    fi

    # Detectar agentes en destino
    local agents=()
    for f in "${TARGET_DIR}"/agents/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .md)
        agents+=("$name")
    done

    if [[ ${#agents[@]} -eq 0 ]]; then
        log_warn "No se encontraron agentes en ${TARGET_DIR}/agents/"
        return
    fi

    echo
    print_header "Configuración de Modelos para Agentes"
    echo

    echo "Agentes detectados:"
    for agent in "${agents[@]}"; do
        local current_model
        current_model=$(grep -m1 '^model:' "${TARGET_DIR}/agents/${agent}.md" | sed 's/^model: *//' || true)
        if [[ -z "$current_model" ]]; then
            current_model="(no definido)"
        fi
        printf "  %-20s → %s\n" "$agent" "$current_model"
    done
    echo

    read -r -p "¿Qué deseas hacer? [a(todos*) / s(uno a uno) / N(dejar)]: " choice
    choice=${choice:-a}

    local selected_model=""

    case "$choice" in
        [aA])
            while true; do
                local sc_status=0
                select_company || sc_status=$?

                if [[ $sc_status -ne 0 ]]; then
                    log_info "Configuración de modelos cancelada."
                    return
                fi

                local provider_idx="$SELECTED_VALUE"

                local sm_status=0
                select_model "$provider_idx" || sm_status=$?

                if [[ $sm_status -eq 0 ]]; then
                    selected_model="$SELECTED_VALUE"
                    break
                elif [[ $sm_status -eq 2 ]]; then
                    continue
                else
                    log_info "Configuración de modelos cancelada."
                    return
                fi
            done

            log_info "Aplicando '$selected_model' a todos los agentes..."
            for agent in "${agents[@]}"; do
                if sed -i "s|^model: .*|model: ${selected_model}|" "${TARGET_DIR}/agents/${agent}.md" 2>/dev/null; then
                    log_ok "  $agent"
                else
                    log_error "  Falló: $agent"
                fi
            done
            ;;
        [sS])
            for agent in "${agents[@]}"; do
                local current_model
                current_model=$(grep -m1 '^model:' "${TARGET_DIR}/agents/${agent}.md" | sed 's/^model: *//' || true)
                if [[ -z "$current_model" ]]; then
                    current_model="(no definido)"
                fi
                echo
                read -r -p "Agente '$agent' — actual: $current_model. ¿Cambiar? [s/N]: " change
                if [[ "$change" =~ ^[sS]$ ]]; then
                    while true; do
                        local sc_status=0
                        select_company || sc_status=$?

                        if [[ $sc_status -ne 0 ]]; then
                            break
                        fi

                        local provider_idx="$SELECTED_VALUE"

                        local sm_status=0
                        select_model "$provider_idx" || sm_status=$?

                        if [[ $sm_status -eq 0 ]]; then
                            local model="$SELECTED_VALUE"
                            if sed -i "s|^model: .*|model: ${model}|" "${TARGET_DIR}/agents/${agent}.md" 2>/dev/null; then
                                log_ok "  $agent → $model"
                            else
                                log_error "  Falló: $agent"
                            fi
                            break
                        elif [[ $sm_status -eq 2 ]]; then
                            continue
                        else
                            break
                        fi
                    done
                fi
            done
            ;;
        *)
            log_info "Modelos no modificados."
            ;;
    esac
}

# ============================================================================
# Parseo de argumentos
# ============================================================================
parse_args() {
    for arg in "$@"; do
        case "${arg}" in
            --dry-run)
                DRY_RUN=true
                ;;
            --uninstall)
                UNINSTALL=true
                ;;
            --help)
                print_help
                exit 0
                ;;
            *)
                log_error "Opción desconocida: ${arg}"
                print_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Main
# ============================================================================
main() {
    parse_args "$@"

    verify_source

    if [[ "${UNINSTALL}" == true ]]; then
        run_uninstall
        rm -f "${SOURCE_DIR}/models.json"
        exit 0
    fi

    # Crear target si no existe
    if [[ "${DRY_RUN}" == false ]]; then
        mkdir -p "${TARGET_DIR}"
    fi

    # Fetch catálogo de modelos desde OpenRouter
    fetch_models

    local existing_count
    existing_count=$(detect_existing)

    if [[ "${existing_count}" -gt 0 && "${DRY_RUN}" == false ]]; then
        # Hay instalación previa → mostrar menú
        show_menu
    else
        # Instalación limpia o dry-run
        run_fresh_install
    fi

    # Configurar modelos de agentes (después de copiar archivos)
    configure_agent_models

    # Limpiar models.json temporal siempre
    rm -f "${SOURCE_DIR}/models.json"

    # Verificación post-instalación (solo si no es dry-run)
    if [[ "${DRY_RUN}" == false ]]; then
        echo
        if ! verify_installation; then
            echo
            log_error "La verificación post-instalación encontró errores."
            exit 1
        fi

        echo
        run_optional_tests

        echo
        log_ok "Operación completada exitosamente."
        echo
        echo -e "${C_BOLD}Resumen:${C_RESET}"
        echo "  Origen : ${SOURCE_DIR}"
        echo "  Destino: ${TARGET_DIR/#${HOME}/~}"
        if [[ -e "${BACKUP_PATH}" ]]; then
            echo "  Respaldo: ${BACKUP_PATH/#${HOME}/~}"
        fi
        echo
        echo -e "${C_BOLD}Próximos pasos:${C_RESET}"
        echo "  1. Abre OpenCode en el directorio de tu proyecto."
        echo "  2. Presiona Tab para seleccionar el agente 'spec'."
        echo "  3. Describe tu idea y empieza el pipeline."
        echo
    else
        echo
        log_info "=== Fin de simulación ==="
    fi
}

main "$@"

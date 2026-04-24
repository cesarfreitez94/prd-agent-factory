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
        exit 0
    fi

    # Crear target si no existe
    if [[ "${DRY_RUN}" == false ]]; then
        mkdir -p "${TARGET_DIR}"
    fi

    local existing_count
    existing_count=$(detect_existing)

    if [[ "${existing_count}" -gt 0 && "${DRY_RUN}" == false ]]; then
        # Hay instalación previa → mostrar menú
        show_menu
    else
        # Instalación limpia o dry-run
        run_fresh_install
    fi

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

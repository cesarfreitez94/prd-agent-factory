#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# PRD Agent Framework — Instalador
# =============================================================================
# Uso:
#   ./install.sh              Instala el framework en ~/.config/opencode/
#   ./install.sh --dry-run    Muestra qué haría sin modificar nada
#   ./install.sh --skip-backup  No respalda AGENTS.md existente
#   ./install.sh --uninstall  Elimina lo instalado (pide confirmación)
#   ./install.sh --help       Muestra esta ayuda
# =============================================================================

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${HOME}/.config/opencode"
BACKUP_SUFFIX=".bak.$(date +%s)"

DRY_RUN=false
SKIP_BACKUP=false
UNINSTALL=false

# Colores
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_CYAN='\033[36m'

print_help() {
    cat <<'EOF'
PRD Agent Framework — Instalador

Uso:
  ./install.sh [opciones]

Opciones:
  --dry-run        Muestra qué haría sin modificar archivos
  --skip-backup    No respalda AGENTS.md si ya existe
  --uninstall      Elimina la instalación del framework (pide confirmación)
  --help           Muestra esta ayuda

Ejemplos:
  ./install.sh              Instalación normal con respaldo automático
  ./install.sh --dry-run    Simula la instalación
  ./install.sh --uninstall  Desinstala el framework
EOF
}

log_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1"
}

log_ok() {
    echo -e "${C_GREEN}[OK]${C_RESET}   $1"
}

log_warn() {
    echo -e "${C_YELLOW}[AVISO]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1"
}

# ---------------------------------------------------------------------------
# Validación de entorno fuente
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Backup condicional
# ---------------------------------------------------------------------------
backup_if_exists() {
    local path="$1"
    if [[ -e "${path}" ]]; then
        if [[ "${SKIP_BACKUP}" == true ]]; then
            log_warn "Se sobrescribirá sin respaldo: ${path}"
            return
        fi
        local bak="${path}${BACKUP_SUFFIX}"
        if [[ "${DRY_RUN}" == true ]]; then
            log_info "[dry-run] Respaldo: ${path} → ${bak}"
        else
            cp -a "${path}" "${bak}"
            log_ok "Respaldo creado: ${bak}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Copiar archivo o directorio
# ---------------------------------------------------------------------------
copy_item() {
    local src="$1"
    local dst="$2"
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ -d "${src}" ]]; then
            log_info "[dry-run] Copiar directorio: ${src}/ → ${dst}/"
        else
            log_info "[dry-run] Copiar archivo: ${src} → ${dst}"
        fi
        return
    fi

    # Crear directorio destino si no existe
    local dst_dir
    dst_dir="$(dirname "${dst}")"
    mkdir -p "${dst_dir}"

    if [[ -d "${src}" ]]; then
        cp -r "${src}" "${dst}"
    else
        cp "${src}" "${dst}"
    fi
}

# ---------------------------------------------------------------------------
# Verificación post-instalación
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Ejecutar tests opcionales
# ---------------------------------------------------------------------------
run_optional_tests() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Se saltaría la validación con pytest"
        return
    fi

    if ! command -v pytest &>/dev/null; then
        log_warn "pytest no está instalado. Se omite validación opcional."
        return
    fi

    if [[ ! -d "${SOURCE_DIR}/tests" ]]; then
        log_warn "No se encontró directorio tests/. Se omite validación."
        return
    fi

    echo
    read -r -p "¿Quieres ejecutar pytest para validar integridad del framework? [s/N]: " resp
    if [[ "${resp}" =~ ^[Ss]$ ]]; then
        log_info "Ejecutando pytest..."
        if (cd "${SOURCE_DIR}" && pytest tests/ -v); then
            log_ok "Validación con pytest exitosa."
        else
            log_warn "pytest reportó errores. Revisa los detalles arriba."
        fi
    else
        log_info "Validación omitida."
    fi
}

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
run_install() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "=== MODO SIMULACIÓN (--dry-run) ==="
        log_info "No se modificará ningún archivo.\n"
    else
        log_info "=== Instalando PRD Agent Framework ===\n"
    fi

    verify_source

    # Crear target
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[dry-run] Crear directorio si no existe: ${TARGET_DIR/#${HOME}/~}"
    else
        mkdir -p "${TARGET_DIR}"
    fi

    # Backup de AGENTS.md
    backup_if_exists "${TARGET_DIR}/AGENTS.md"

    # Copiar todo
    copy_item "${SOURCE_DIR}/agents" "${TARGET_DIR}/agents"
    copy_item "${SOURCE_DIR}/schemas" "${TARGET_DIR}/schemas"
    copy_item "${SOURCE_DIR}/templates" "${TARGET_DIR}/templates"
    copy_item "${SOURCE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"

    echo
    if ! verify_installation; then
        echo
        log_error "La verificación post-instalación encontró errores."
        exit 1
    fi

    echo
    run_optional_tests

    echo
    log_ok "Instalación completada exitosamente."
    echo
    echo -e "${C_BOLD}Resumen:${C_RESET}"
    echo "  Origen : ${SOURCE_DIR}"
    echo "  Destino: ${TARGET_DIR/#${HOME}/~}"
    if [[ -e "${TARGET_DIR}/AGENTS.md${BACKUP_SUFFIX}" ]]; then
        echo "  Respaldo: ${TARGET_DIR/#${HOME}/~}/AGENTS.md${BACKUP_SUFFIX}"
    fi
    echo
    echo -e "${C_BOLD}Próximos pasos:${C_RESET}"
    echo "  1. Abre OpenCode en el directorio de tu proyecto."
    echo "  2. Presiona Tab para seleccionar el agente 'spec'."
    echo "  3. Describe tu idea y empieza el pipeline."
    echo
}

# ---------------------------------------------------------------------------
# Desinstalación
# ---------------------------------------------------------------------------
run_uninstall() {
    echo
    log_warn "Estás a punto de eliminar el PRD Agent Framework de:"
    echo "  ${TARGET_DIR/#${HOME}/~}"
    echo
    echo "Se eliminarán los siguientes elementos:"
    echo "  - agents/"
    echo "  - schemas/"
    echo "  - templates/"
    echo "  - AGENTS.md"
    echo
    read -r -p "Escribe 'yes' para confirmar la desinstalación: " confirm

    if [[ "${confirm}" != "yes" ]]; then
        log_info "Desinstalación cancelada."
        exit 0
    fi

    local removed=0
    for item in "${TARGET_DIR}/agents" "${TARGET_DIR}/schemas" "${TARGET_DIR}/templates" "${TARGET_DIR}/AGENTS.md"; do
        if [[ -e "${item}" ]]; then
            rm -rf "${item}"
            log_ok "Eliminado: ${item/#${HOME}/~}"
            ((removed++)) || true
        fi
    done

    if [[ "${removed}" -eq 0 ]]; then
        log_warn "No se encontró nada que desinstalar."
    else
        log_ok "Desinstalación completada."
    fi
}

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
parse_args() {
    for arg in "$@"; do
        case "${arg}" in
            --dry-run)
                DRY_RUN=true
                ;;
            --skip-backup)
                SKIP_BACKUP=true
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

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    if [[ "${UNINSTALL}" == true ]]; then
        run_uninstall
    else
        run_install
    fi
}

main "$@"

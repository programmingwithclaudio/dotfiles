#!/bin/bash
# verify-installation.sh - Script para verificar la instalación del entorno

set -eo pipefail
IFS=$'\n\t'

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables de configuración
NVIM_VERSION="v0.10.3"
NERD_FONT="Iosevka"
REQUIRED_PROGRAMS=(nvim zsh node java docker rustc)
REQUIRED_NPM_PKGS=(typescript typescript-language-server prettier)
REQUIRED_PY_PKGS=(pyright ruff black isort)
MASON_PKGS=(jdtls java-test java-debug-adapter)

# Estado global de verificación
ALL_OK=true

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%b[%s]%b ${timestamp} - ${message}\n" \
        "${!level}" "${level}" "${NC}"
}

check_installed() {
    if ! command -v $1 &> /dev/null; then
        log "ERROR" "$1 no está instalado"
        ALL_OK=false
    else
        log "INFO" "$1 encontrado: $(command -v $1)"
    fi
}

check_version() {
    local program=$1
    local expected=$2
    local actual=$($program --version | head -n1)
    
    if [[ ! "$actual" =~ "$expected" ]]; then
        log "ERROR" "Versión de $program incorrecta. Esperada: ${expected}, Actual: ${actual}"
        ALL_OK=false
    else
        log "INFO" "Versión de $program correcta: ${expected}"
    fi
}

check_path() {
    local path=$1
    local desc=$2
    
    if [ ! -e "$path" ]; then
        log "ERROR" "${desc} no encontrado: ${path}"
        ALL_OK=false
    else
        log "INFO" "${desc} encontrado: ${path}"
    fi
}

check_nvim_config() {
    local config_files=(
        "$HOME/.config/nvim/init.lua"
        "$HOME/.local/share/nvim/mason/packages"
    )
    
    for file in "${config_files[@]}"; do
        check_path "$file" "Archivo de configuración de Neovim"
    done
    
    # Verificar plugins de Mason
    for pkg in "${MASON_PKGS[@]}"; do
        local pkg_path="$HOME/.local/share/nvim/mason/packages/$pkg"
        if [ ! -d "$pkg_path" ]; then
            log "ERROR" "Paquete Mason no instalado: $pkg"
            ALL_OK=false
        fi
    done
}

check_wezterm_config() {
    local wezterm_config="$HOME/.config/wezterm/wezterm.lua"
    check_path "$wezterm_config" "Configuración de WezTerm"
    
    if [ -f "$wezterm_config" ]; then
        if ! grep -q "Iosevka Nerd Font" "$wezterm_config"; then
            log "ERROR" "Fuente no configurada correctamente en WezTerm"
            ALL_OK=false
        fi
    fi
}

check_java_env() {
    if [ -z "$JAVA_HOME" ]; then
        log "ERROR" "JAVA_HOME no está configurado"
        ALL_OK=false
    else
        check_path "$JAVA_HOME" "JAVA_HOME"
        check_path "$JAVA_HOME/bin/java" "Java Runtime"
    fi
    
    check_installed "mvn"
    check_installed "gradle"
}

check_node_env() {
    if [ -z "$(which fnm)" ]; then
        log "ERROR" "fnm no instalado"
        ALL_OK=false
    else
        log "INFO" "fnm encontrado: $(which fnm)"
        local node_version=$(node --version)
        if [[ ! "$node_version" =~ "v20" ]]; then
            log "ERROR" "Versión de Node.js incorrecta: ${node_version}"
            ALL_OK=false
        fi
    fi
    
    for pkg in "${REQUIRED_NPM_PKGS[@]}"; do
        if ! npm list -g | grep -q "$pkg"; then
            log "ERROR" "Paquete npm no instalado: $pkg"
            ALL_OK=false
        fi
    done
}

check_python_tools() {
    for pkg in "${REQUIRED_PY_PKGS[@]}"; do
        if ! pip show "$pkg" &> /dev/null; then
            log "ERROR" "Paquete Python no instalado: $pkg"
            ALL_OK=false
        fi
    done
}

check_fonts() {
    if ! fc-list | grep -qi "Iosevka Nerd Font"; then
        log "ERROR" "Fuente Iosevka Nerd Font no instalada"
        ALL_OK=false
    fi
}

check_docker() {
    if ! docker info &> /dev/null; then
        log "ERROR" "Docker no funciona correctamente"
        ALL_OK=false
    fi
    
    if ! groups | grep -q docker; then
        log "ERROR" "Usuario no está en el grupo docker"
        ALL_OK=false
    fi
}

main() {
    log "INFO" "Iniciando verificación del sistema..."
    
    # Verificar programas base
    for program in "${REQUIRED_PROGRAMS[@]}"; do
        check_installed "$program"
    done
    
    # Verificar versiones específicas
    check_version "nvim" "$NVIM_VERSION"
    
    # Verificar configuraciones
    check_nvim_config
    check_wezterm_config
    check_java_env
    check_node_env
    check_python_tools
    check_fonts
    check_docker
    
    # Resultado final
    if $ALL_OK; then
        log "INFO" "¡Todas las verificaciones pasaron correctamente!"
        exit 0
    else
        log "ERROR" "Se encontraron problemas en la configuración"
        exit 1
    fi
}

main "$@"

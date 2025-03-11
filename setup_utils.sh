#!/bin/bash

# Establecer modo estricto de bash pero permitiendo variables no definidas para SDKMAN
set -eo pipefail
IFS=$'\n\t'

# Variables globales
NVIM_VERSION="v0.10.3"
NERD_FONT="Iosevka"
FONT_VERSION="v3.3.0"
JAVA_VERSION="21.0.5-oracle"
JAVA_LTS_VERSION="17.0.12-oracle"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función mejorada para logs
log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2
            ;;
    esac
}

# Función mejorada para verificar errores
check_error() {
    if [ $? -ne 0 ]; then
        log "ERROR" "$1"
        exit 1
    fi
}

# Verificar si se ejecuta como root
if [ "$EUID" -eq 0 ]; then
    log "ERROR" "No ejecutes este script como root o con sudo"
    exit 1
fi

# Función para verificar si un binario existe
is_installed() {
    command -v "$1" &> /dev/null
}

# Función para hacer backup de archivos de configuración
backup_config() {
    local file=$1
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Creando backup de $file en $backup"
        cp "$file" "$backup"
    fi
}

# Función para agregar línea a archivo si no existe
append_if_not_exists() {
    local line=$1
    local file=$2
    if [ -f "$file" ]; then
        grep -qxF "$line" "$file" || echo "$line" >> "$file"
    else
        mkdir -p "$(dirname "$file")"
        echo "$line" > "$file"
    fi
}

# Función para detectar distribución
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID}"
        if [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ]; then
            PACKAGE_MANAGER="apt"
        elif [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; then
            PACKAGE_MANAGER="pacman"
        else
            log "ERROR" "Distribución no soportada: $DISTRO"
            exit 1
        fi
    else
        log "ERROR" "No se pudo detectar la distribución"
        exit 1
    fi
    log "INFO" "Distribución detectada: $DISTRO, Gestor de paquetes: $PACKAGE_MANAGER"
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        if [ "$(sudo apt-get update 2>&1 | grep -c "packages can be upgraded")" -eq 0 ]; then
            log "INFO" "Paquetes ya actualizados, omitiendo actualización del sistema"
        else
            log "INFO" "Actualizando el sistema..."
            sudo apt update && sudo apt upgrade -y
            check_error "No se pudo actualizar el sistema"
        fi

        log "INFO" "Instalando dependencias requeridas..."
        local deps=(
            ninja-build gettext libtool libtool-bin autoconf 
            automake cmake g++ pkg-config unzip curl git 
            build-essential lua5.4 luarocks zsh ripgrep 
            fd-find fzf bat
        )
        
        # Verificar qué paquetes ya están instalados
        local missing_deps=()
        for dep in "${deps[@]}"; do
            if ! dpkg -s $dep >/dev/null 2>&1; then
                missing_deps+=("$dep")
            fi
        done
        
        if [ ${#missing_deps[@]} -eq 0 ]; then
            log "INFO" "Todas las dependencias ya están instaladas"
        else
            log "INFO" "Instalando dependencias faltantes: ${missing_deps[*]}"
            sudo apt install -y "${missing_deps[@]}"
            check_error "No se pudieron instalar las dependencias"
        fi
    elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
        log "INFO" "Actualizando el sistema..."
        sudo pacman -Syu --noconfirm

        log "INFO" "Instalando dependencias requeridas..."
        local deps=(
            ninja gettext libtool autoconf automake 
            cmake gcc pkg-config unzip curl git 
            base-devel lua luarocks zsh ripgrep 
            fd fzf bat
        )
        
        # Verificar qué paquetes ya están instalados
        local missing_deps=()
        for dep in "${deps[@]}"; do
            if ! pacman -Q $dep >/dev/null 2>&1; then
                missing_deps+=("$dep")
            fi
        done
        
        if [ ${#missing_deps[@]} -eq 0 ]; then
            log "INFO" "Todas las dependencias ya están instaladas"
        else
            log "INFO" "Instalando dependencias faltantes: ${missing_deps[*]}"
            sudo pacman -S --needed --noconfirm "${missing_deps[@]}"
            check_error "No se pudieron instalar las dependencias"
        fi
    fi
}

# Función para instalar SDKMAN y Java de manera segura
setup_java() {
    if ! command -v sdk &> /dev/null; then
        log "INFO" "Instalando SDKMAN..."
        # Crear archivo temporal para el script de instalación
        local tmp_install="/tmp/sdkman_install.sh"
        curl -s "https://get.sdkman.io" > "$tmp_install"
        bash "$tmp_install"
        rm -f "$tmp_install"
        
        # Configurar SDKMAN de manera segura
        local sdkman_init="$HOME/.sdkman/bin/sdkman-init.sh"
        if [ -f "$sdkman_init" ]; then
            # Asegurarnos de que las variables de shell estén definidas
            export BASH_VERSION=${BASH_VERSION:-}
            export ZSH_VERSION=${ZSH_VERSION:-}
            
            # Sourcear SDKMAN de manera segura
            set +u  # Temporalmente permitir variables no definidas
            source "$sdkman_init"
            set -u  # Restaurar modo estricto
        fi
    else
        log "INFO" "SDKMAN ya está instalado"
    fi

    # Verificar que SDKMAN está disponible
    if ! command -v sdk &> /dev/null; then
        log "ERROR" "SDKMAN no se instaló correctamente"
        exit 1
    fi

    log "INFO" "Verificando versiones de Java..."
    # Temporalmente permitir variables no definidas para SDKMAN
    set +u
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    
    # Instalar Java solo si no está ya instalado
    if ! sdk list java | grep -q "$JAVA_VERSION"; then
        log "INFO" "Instalando Java $JAVA_VERSION..."
        sdk install java "$JAVA_VERSION" || true
    else
        log "INFO" "Java $JAVA_VERSION ya está instalado"
    fi
    
    if ! sdk list java | grep -q "$JAVA_LTS_VERSION"; then
        log "INFO" "Instalando Java $JAVA_LTS_VERSION..."
        sdk install java "$JAVA_LTS_VERSION" || true
    else
        log "INFO" "Java $JAVA_LTS_VERSION ya está instalado"
    fi
    
    # Configurar versión por defecto
    sdk default java "$JAVA_VERSION"
    set -u
}

# Función para instalar y configurar Zsh
setup_zsh() {
    log "INFO" "Verificando configuración de Zsh..."
    
    # Instalar Zsh si no está instalado
    if ! is_installed zsh; then
        log "INFO" "Instalando Zsh..."
        if [ "$PACKAGE_MANAGER" == "apt" ]; then
            sudo apt install -y zsh
        elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
            sudo pacman -S --noconfirm zsh
        fi
        check_error "No se pudo instalar Zsh"
    else
        log "INFO" "Zsh ya está instalado"
    fi

    # Instalar Oh My Zsh si no está instalado
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Instalando Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        check_error "No se pudo instalar Oh My Zsh"
    else
        log "INFO" "Oh My Zsh ya está instalado"
    fi

    # Backup y creación de nuevo .zshrc solo si no existe o no tiene la configuración esperada
    if [ ! -f "$HOME/.zshrc" ] || ! grep -q "SDKMAN_DIR" "$HOME/.zshrc"; then
        backup_config "$HOME/.zshrc"
        
        # Crear nuevo .zshrc con configuración segura
        cat > "$HOME/.zshrc" <<'EOL'
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git node npm)

# Configuración de SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
    # Asegurar que las variables están definidas
    export BASH_VERSION=${BASH_VERSION:-}
    export ZSH_VERSION=${ZSH_VERSION:-}
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Sourcing Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Path configurations
export PATH="/opt/nvim/bin:$PATH"
export PATH="$HOME/.local/share/fnm:$PATH"

# Alias útiles
alias vim='nvim'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOL
        log "INFO" "Archivo .zshrc configurado"
    else
        log "INFO" "Archivo .zshrc ya contiene configuración"
    fi

    # Cambiar shell por defecto a Zsh de manera segura
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "INFO" "Cambiando shell por defecto a Zsh..."
        sudo chsh -s "$(which zsh)" "$USER"
        check_error "No se pudo cambiar la shell por defecto"
    else
        log "INFO" "Zsh ya es la shell por defecto"
    fi
}

# Función para instalar Neovim
install_neovim() {
    if is_installed nvim && nvim --version | grep -q "$NVIM_VERSION"; then
        log "INFO" "Neovim ${NVIM_VERSION} ya está instalado"
        return 0
    fi

    log "INFO" "Instalando Neovim ${NVIM_VERSION}..."
    local nvim_tarball="nvim-linux64.tar.gz"
    
    # Descargar solo si no existe
    if [ ! -f "$nvim_tarball" ]; then
        curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_tarball}"
        check_error "No se pudo descargar Neovim"
    fi
    
    tar -xzf "$nvim_tarball"
    sudo rm -rf /opt/nvim
    sudo mkdir -p /opt/nvim
    sudo cp -r nvim-linux64/* /opt/nvim/
    rm -rf nvim-linux64 "$nvim_tarball"

    # Configurar PATH para Neovim
    append_if_not_exists 'export PATH="/opt/nvim/bin:$PATH"' "$HOME/.profile"
    
    # Actualizar PATH en la sesión actual
    export PATH="/opt/nvim/bin:$PATH"
    
    log "INFO" "Neovim instalado correctamente"
}

install_nerd_fonts() {
    if fc-list | grep -i "$NERD_FONT" &> /dev/null; then
        log "INFO" "Nerd Font ($NERD_FONT) ya está instalada"
        return 0
    fi

    log "INFO" "Instalando Nerd Font ($NERD_FONT)..."
    local font_zip="${NERD_FONT}.zip"
    
    # Descargar solo si no existe
    if [ ! -f "$font_zip" ]; then
        curl -LO "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${font_zip}"
        check_error "No se pudo descargar la fuente"
    fi
    
    unzip -o "$font_zip" -d "$NERD_FONT"
    mkdir -p "$HOME/.local/share/fonts/"
    cp "$NERD_FONT"/*.ttf "$HOME/.local/share/fonts/"
    fc-cache -fv
    rm -rf "$NERD_FONT" "$font_zip"
    
    log "INFO" "Nerd Font instalada correctamente"
}


# Función para crear directorios base de Neovim sin configurar
setup_neovim_dirs() {
    log "INFO" "Creando directorios base para Neovim..."
    
    # Crear directorios necesarios
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.vim/undodir"
    
    # Solo instalar vim-plug si no está presente
    local PLUG_FILE="$HOME/.local/share/nvim/site/autoload/plug.vim"
    if [ ! -f "$PLUG_FILE" ]; then
        log "INFO" "Instalando vim-plug..."
        curl -fLo "$PLUG_FILE" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        log "INFO" "vim-plug ya está instalado"
    fi
    
    log "INFO" "Directorios base de Neovim creados"
}

# Función para instalar Rust
install_rust() {
    if is_installed rustc; then
        log "INFO" "Rust ya está instalado"
        return 0
    fi

    log "INFO" "Instalando Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    log "INFO" "Rust instalado correctamente"
}

# Función para instalar Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log "INFO" "Docker ya está instalado"
        return 0
    fi

    log "INFO" "Iniciando la instalación de Docker..."
    
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        # Instalar dependencias necesarias
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        
        # Agregar la clave GPG de Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Agregar el repositorio de Docker a las fuentes de apt
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Actualizar los repositorios nuevamente
        sudo apt update
        
        # Instalar Docker
        sudo apt install -y docker-ce docker-ce-cli containerd.io
    elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
        # Instalar Docker desde los repositorios de Arch
        sudo pacman -S --noconfirm docker
    fi
    
    log "INFO" "Docker instalado correctamente"
}

configure_docker() {
    log "INFO" "Configurando Docker y Docker Compose..."

    # Verificar si el servicio Docker está activo
    if ! sudo systemctl is-active --quiet docker; then
        sudo systemctl start docker
        log "INFO" "Docker no estaba en funcionamiento, se ha iniciado"
    else
        log "INFO" "Docker ya está en funcionamiento"
    fi

    # Verificar si el usuario ya está en el grupo docker
    if ! groups | grep -q "\bdocker\b"; then
        # Crear el grupo Docker si no existe
        if ! getent group docker; then
            sudo groupadd docker
            log "INFO" "Grupo Docker creado"
        fi

        # Agregar al usuario al grupo Docker
        sudo usermod -aG docker $USER
        log "INFO" "Usuario añadido al grupo docker"
    else
        log "INFO" "Usuario ya pertenece al grupo docker"
    fi

    # Cambiar la propiedad de /var/run/docker.sock
    sudo chown "$USER":"$USER" /var/run/docker.sock

    # Establecer permisos adecuados para el socket de Docker
    sudo chmod g+rw /var/run/docker.sock

    # Verificar si Docker Compose ya está instalado
    if ! command -v docker-compose &> /dev/null; then
        # Descargar e instalar Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

        # Hacer Docker Compose ejecutable
        sudo chmod +x /usr/local/bin/docker-compose
        log "INFO" "Docker Compose instalado correctamente"
    else
        log "INFO" "Docker Compose ya está instalado"
    fi
}

# Función para instalar Visual Studio Code
install_vscode() {
    if command -v code &> /dev/null; then
        log "INFO" "Visual Studio Code ya está instalado"
        return 0
    fi

    log "INFO" "Instalando Visual Studio Code..."

    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        # Instalar dependencias
        sudo apt install -y software-properties-common apt-transport-https wget

        # Importar la clave GPG de Microsoft
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
        rm -f packages.microsoft.gpg

        # Agregar el repositorio de Visual Studio Code
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list

        # Instalar Visual Studio Code
        sudo apt update
        sudo apt install -y code
    elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
        # En Arch Linux, instalar desde AUR
        yay -S --noconfirm code
    fi

    log "INFO" "Visual Studio Code instalado correctamente"
}

# Función para instalar WezTerm sin configuración
install_wezterm() {
    if command -v wezterm &> /dev/null; then
        log "INFO" "WezTerm ya está instalado"
        return 0
    fi

    log "INFO" "Instalando WezTerm..."
    
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        # Instalar clave GPG y configurar repositorio
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" | \
            sudo tee /etc/apt/sources.list.d/wezterm.list

        sudo apt update
        sudo apt install -y wezterm-nightly
    elif [ "$PACKAGE_MANAGER" == "pacman" ]; then
        # Instalar desde AUR
        yay -S --noconfirm wezterm
    fi
    
    # Crear directorio de configuración sin añadir archivos de configuración
    mkdir -p "$HOME/.config/wezterm"
    
    log "INFO" "WezTerm instalado correctamente"
}

# Función para crear archivos básicos de configuración
create_basic_config_files() {
    log "INFO" "Creando archivos básicos de configuración..."
    
    # Crear directorios si no existen
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.config/wezterm"
    
    # Comprobar si los archivos existen antes de crearlos
    if [ ! -f "$HOME/.config/nvim/init.lua" ]; then
        log "INFO" "Creando archivo básico init.lua para Neovim"
        cat > "$HOME/.config/nvim/init.lua" <<EOL
-- Este es un archivo básico de configuración para Neovim
-- Creado por el script de instalación
-- Puedes personalizarlo según tus necesidades

-- Configuración básica
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.wrap = false
EOL
    else
        log "INFO" "El archivo init.lua ya existe, no se modificará"
    fi
    
    if [ ! -f "$HOME/.config/wezterm/wezterm.lua" ]; then
        log "INFO" "Creando archivo básico wezterm.lua"
        cat > "$HOME/.config/wezterm/wezterm.lua" <<EOL
-- Este es un archivo básico de configuración para WezTerm
-- Creado por el script de instalación
-- Puedes personalizarlo según tus necesidades

local wezterm = require 'wezterm'

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Configuración básica
config.font = wezterm.font('Iosevka Nerd Font')
config.font_size = 14.0
config.color_scheme = 'Gruvbox Dark'

return config
EOL
    else
        log "INFO" "El archivo wezterm.lua ya existe, no se modificará"
    fi
}

# Función principal modificada
main() {
    log "INFO" "Iniciando instalación del entorno de desarrollo..."

    # Detectar la distribución
    detect_distro
    
    # Ejecutar instalaciones en orden seguro
    install_system_dependencies
    install_neovim
    install_nerd_fonts
    setup_java
    install_wezterm
    install_rust
    setup_neovim_dirs  # Solo crea directorios, no configura
    install_docker
    configure_docker
    install_vscode
    setup_zsh
    
    # Crear archivos básicos de configuración
    create_basic_config_files

    log "INFO" "¡Instalación completada!"
    log "WARN" "Por favor, cierra esta terminal y abre una nueva para aplicar todos los cambios"
    log "INFO" "Tu shell por defecto ha sido cambiada a Zsh"
    log "INFO" "Se han creado archivos básicos de configuración. Personalízalos según tus necesidades."
}

# Ejecutar el script
main "$@"

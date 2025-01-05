#!/bin/bash

# Establecer modo estricto de bash pero permitiendo variables no definidas para SDKMAN
set -eo pipefail
IFS=$'\n\t'

# Variables globales
NVIM_VERSION="v0.10.3"
NERD_FONT="Iosevka"
FONT_VERSION="v3.3.0"
NODE_LTS_VERSION="20.11.1"
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
    grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

# Función para instalar dependencias del sistema
install_system_dependencies() {
    log "INFO" "Actualizando el sistema..."
    sudo apt update && sudo apt upgrade -y
    check_error "No se pudo actualizar el sistema"

    log "INFO" "Instalando dependencias requeridas..."
    local deps=(
        ninja-build gettext libtool libtool-bin autoconf 
        automake cmake g++ pkg-config unzip curl git 
        build-essential lua5.4 luarocks zsh ripgrep 
        fd-find fzf bat
    )
    sudo apt install -y "${deps[@]}"
    check_error "No se pudieron instalar las dependencias"
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
    fi

    # Verificar que SDKMAN está disponible
    if ! command -v sdk &> /dev/null; then
        log "ERROR" "SDKMAN no se instaló correctamente"
        exit 1
    fi

    log "INFO" "Instalando versiones de Java..."
    # Temporalmente permitir variables no definidas para SDKMAN
    set +u
    sdk install java "$JAVA_VERSION" || true
    sdk install java "$JAVA_LTS_VERSION" || true
    sdk default java "$JAVA_VERSION"
    set -u
}

# Función para instalar y configurar Zsh
setup_zsh() {
    log "INFO" "Configurando Zsh..."
    
    # Instalar Zsh si no está instalado
    if ! is_installed zsh; then
        sudo apt install -y zsh
        check_error "No se pudo instalar Zsh"
    fi

    # Instalar Oh My Zsh si no está instalado
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Instalando Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        check_error "No se pudo instalar Oh My Zsh"
    fi

    # Backup y creación de nuevo .zshrc
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
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# Alias útiles
alias vim='nvim'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOL

    # Cambiar shell por defecto a Zsh de manera segura
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "INFO" "Cambiando shell por defecto a Zsh..."
        sudo chsh -s "$(which zsh)" "$USER"
        check_error "No se pudo cambiar la shell por defecto"
    fi
}


# Las funciones install_neovim, install_nerd_fonts, setup_node, setup_neovim, install_wezterm, e install_rust permanecen exactamente igual que en la versión anterior

# Función para instalar Neovim
install_neovim() {
    if is_installed nvim; then
        log "INFO" "Neovim ya está instalado"
        return 0
    fi

    log "INFO" "Instalando Neovim ${NVIM_VERSION}..."
    curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
    check_error "No se pudo descargar Neovim"
    
    tar -xzf nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo mv nvim-linux64 /opt/nvim
    rm nvim-linux64.tar.gz

    # Configurar PATH para Neovim
    append_if_not_exists 'export PATH="/opt/nvim/bin:$PATH"' "$HOME/.profile"
    source "$HOME/.profile"
}

install_nerd_fonts() {
    if fc-list | grep -i "$NERD_FONT" &> /dev/null; then
        log "INFO" "Nerd Font ($NERD_FONT) ya está instalada"
        return 0
    fi

    log "INFO" "Instalando Nerd Font ($NERD_FONT)..."
    curl -LO "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${NERD_FONT}.zip"
    unzip "$NERD_FONT.zip" -d "$NERD_FONT"
    mkdir -p "$HOME/.local/share/fonts/"
    mv "$NERD_FONT"/*.ttf "$HOME/.local/share/fonts/"
    fc-cache -fv
    rm -rf "$NERD_FONT" "$NERD_FONT.zip"
}

# Función para instalar y configurar Volta y Node.js
setup_node() {
    if ! is_installed volta; then
        log "INFO" "Instalando Volta..."
        curl https://get.volta.sh | bash -s -- --skip-setup
        
        export VOLTA_HOME="$HOME/.volta"
        export PATH="$VOLTA_HOME/bin:$PATH"
    fi

    if ! volta list node | grep -q "$NODE_LTS_VERSION"; then
        log "INFO" "Instalando Node.js ${NODE_LTS_VERSION}..."
        volta install "node@${NODE_LTS_VERSION}"
    fi
}

# Función para configurar Neovim
setup_neovim() {
    log "INFO" "Configurando Neovim..."
    
    # Instalar vim-plug si no está instalado
    local PLUG_FILE="$HOME/.local/share/nvim/site/autoload/plug.vim"
    if [ ! -f "$PLUG_FILE" ]; then
        curl -fLo "$PLUG_FILE" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi

    # Crear configuración de Neovim
    mkdir -p "$HOME/.config/nvim"
    mkdir -p "$HOME/.vim/undodir"
    local NVIM_CONFIG="$HOME/.config/nvim/init.vim"
    
    if [ ! -f "$NVIM_CONFIG" ]; then
        cat > "$NVIM_CONFIG" <<EOL
call plug#begin('~/.vim/plugged')
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'morhetz/gruvbox'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'tpope/vim-fugitive'
call plug#end()

" Configuración básica
set number
set relativenumber
set expandtab
set tabstop=4
set shiftwidth=4
set smartindent
set nowrap
set ignorecase
set smartcase
set noswapfile
set nobackup
set undodir=~/.vim/undodir
set undofile
set incsearch
set termguicolors
set scrolloff=8
set noshowmode
set completeopt=menuone,noinsert,noselect
set signcolumn=yes
set cmdheight=2
set updatetime=50
set shortmess+=c
set colorcolumn=80

" Tema
colorscheme gruvbox
set background=dark

" Keymaps
let mapleader = " "
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>
EOL
    fi

    # Instalar plugins
    nvim --headless +PlugInstall +qall

    # Verificar que los plugins se hayan instalado correctamente
    if ! nvim --headless -c 'colorscheme gruvbox' -c 'qa!' &>/dev/null; then
        log "ERROR" "El esquema de colores 'gruvbox' no se pudo cargar. Verifique la instalación de los plugins."
        return 1
    fi

    log "INFO" "Neovim configurado correctamente."
} 


# Función para instalar SDKMAN y Java
setup_java() {
    if ! command -v sdk &> /dev/null; then
        log "INFO" "Instalando SDKMAN..."
        curl -s "https://get.sdkman.io" | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
    fi

    log "INFO" "Instalando versiones de Java..."
    sdk install java "$JAVA_VERSION"
    sdk install java "$JAVA_LTS_VERSION"
    sdk default java "$JAVA_VERSION"
}

# Función para instalar WezTerm
install_wezterm() {
    log "INFO" "Instalando WezTerm..."
    
    # Instalar clave GPG y configurar repositorio
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" | \
        sudo tee /etc/apt/sources.list.d/wezterm.list

    sudo apt update
    sudo apt install -y wezterm-nightly
   
}

# Función para instalar Rust
install_rust() {
    if ! is_installed rustc; then
        log "INFO" "Instalando Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
}

# Función para instalar Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        log "INFO" "Iniciando la instalación de Docker..."
 
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
    else
        log "INFO" "Docker ya está instalado."
    fi
}


configure_docker() {
    log "INFO" "Configurando Docker y Docker Compose..."

    # Verificar si el servicio Docker está activo
    if ! sudo systemctl is-active --quiet docker; then
        sudo systemctl start docker
        log "INFO" "Docker no estaba en funcionamiento, se ha iniciado."
    else
        log "INFO" "Docker ya está en funcionamiento."
    fi

    # Crear el grupo Docker si no existe
    if ! getent group docker; then
        sudo groupadd docker
        log "INFO" "Grupo Docker creado."
    fi

    # Agregar al usuario al grupo Docker
    sudo usermod -aG docker $USER

    # Cambiar la propiedad de /var/run/docker.sock
    sudo chown "$USER":"$USER" /var/run/docker.sock

    # Establecer permisos adecuados para el socket de Docker
    sudo chmod g+rw /var/run/docker.sock

    # Descargar e instalar Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # Hacer Docker Compose ejecutable
    sudo chmod +x /usr/local/bin/docker-compose

    log "INFO" "Docker Compose instalado correctamente."
}

# Función para instalar Visual Studio Code
install_vscode() {
    log "INFO" "Instalando Visual Studio Code..."

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

    log "INFO" "Visual Studio Code instalado correctamente."
}


# Función principal modificada
main() {
    log "INFO" "Iniciando instalación del entorno de desarrollo..."

    # Ejecutar instalaciones en orden seguro
    install_system_dependencies
    install_neovim
    install_nerd_fonts
    setup_node
    setup_java    # SDKMAN ahora es más seguro
    install_wezterm
    install_rust
    setup_neovim
    install_docker
    configure_docker
    install_vscode
    setup_zsh     # Zsh configuración mejorada

    log "INFO" "¡Instalación completada!"
    log "WARN" "Por favor, cierra esta terminal y abre una nueva para aplicar todos los cambios"
    log "INFO" "Tu shell por defecto ha sido cambiada a Zsh"
}

# Ejecutar el script
main "$@"

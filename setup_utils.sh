#!/bin/bash

# Establecer modo estricto de bash
set -eo pipefail
IFS=$'\n\t'

# Variables globales
NVIM_VERSION="v0.10.3"
NERD_FONT="Iosevka"
FONT_VERSION="v3.3.0"
NODE_LTS_VERSION="20.11.1"
JAVA_VERSION="21.0.5-oracle"
JAVA_LTS_VERSION="17.0.12-oracle"
DOTFILES_REPO="https://github.com/programmingwithclaudio/dotfiles.git"

# Detectar distribución
DISTRO=""
if grep -qEi 'debian|ubuntu' /etc/os-release; then
    DISTRO="debian"
elif grep -qEi 'arch' /etc/os-release; then
    DISTRO="arch"
else
    echo "Distribución no soportada!"
    exit 1
fi

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
        "INFO") echo -e "${GREEN}[INFO]${NC} ${timestamp} - $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2 ;;
    esac
}

check_error() {
    if [ $? -ne 0 ]; then
        log "ERROR" "$1"
        exit 1
    fi
}

is_installed() {
    command -v "$1" &> /dev/null
}

backup_config() {
    local file=$1
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Creando backup de $file en $backup"
        cp "$file" "$backup"
    fi
}

setup_dotfiles() {
    if [ ! -d "$HOME/dotfiles" ]; then
        log "INFO" "Clonando repositorio de dotfiles..."
        git clone "$DOTFILES_REPO" "$HOME/dotfiles"
        check_error "Error al clonar el repositorio de dotfiles"
    else
        log "INFO" "Actualizando dotfiles..."
        (cd "$HOME/dotfiles" && git pull)
        check_error "Error al actualizar el repositorio de dotfiles"
    fi
}


install_system_dependencies() {
    log "INFO" "Actualizando el sistema..."
    if [ "$DISTRO" = "debian" ]; then
        sudo apt update && sudo apt upgrade -y
    else
        sudo pacman -Syu --noconfirm
    fi
    check_error "No se pudo actualizar el sistema"

    log "INFO" "Instalando dependencias requeridas..."
    local deps_debian=(
        ninja-build gettext libtool libtool-bin autoconf automake 
        cmake g++ pkg-config unzip curl git build-essential 
        lua5.4 luarocks zsh ripgrep fd-find fzf bat python3-pip
    )
    local deps_arch=(
        ninja gettext libtool autoconf automake cmake gcc pkgconf 
        unzip curl git base-devel lua luarocks zsh ripgrep 
        fd fzf bat python-pip
    )

    if [ "$DISTRO" = "debian" ]; then
        sudo apt install -y "${deps_debian[@]}"
        [ ! -f /usr/bin/fd ] && sudo ln -s $(which fdfind) /usr/bin/fd
    else
        sudo pacman -S --noconfirm "${deps_arch[@]}"
    fi
    check_error "No se pudieron instalar las dependencias"
}

install_neovim() {
    if is_installed nvim; then
        log "INFO" "Neovim ya está instalado"
        return 0
    fi

    log "INFO" "Instalando Neovim ${NVIM_VERSION}..."
    curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
    tar -xzf nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim
    sudo mv nvim-linux64 /opt/nvim
    rm nvim-linux64.tar.gz
    
    echo 'export PATH="/opt/nvim/bin:$PATH"' | tee -a "$HOME/.bashrc" "$HOME/.zshrc" >/dev/null
}

install_wezterm() {
    log "INFO" "Instalando WezTerm..."
    
    if [ "$DISTRO" = "debian" ]; then
        curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
        echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" | \
            sudo tee /etc/apt/sources.list.d/wezterm.list
        sudo apt update && sudo apt install -y wezterm-nightly
    else
        sudo pacman -S --noconfirm wezterm
    fi
    check_error "Error instalando WezTerm"
}

setup_node() {
    if ! is_installed fnm; then
        log "INFO" "Instalando fnm..."
        curl -fsSL https://fnm.vercel.app/install | bash
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env --shell=bash)"
    fi

    log "INFO" "Instalando Node.js ${NODE_LTS_VERSION}..."
    fnm install "$NODE_LTS_VERSION"
    fnm default "$NODE_LTS_VERSION"
    fnm use default
    
    log "INFO" "Instalando paquetes globales de npm..."
    npm install -g typescript typescript-language-server prettier @prisma/language-server
}

install_language_servers() {
    log "INFO" "Instalando servidores de lenguaje Python..."
    
    if [ "$DISTRO" = "debian" ]; then
        # For Debian/Ubuntu, continue using pip
        pip3 install --user pyright ruff black isort
    else
        # For Arch Linux, use pipx
        sudo pacman -S --noconfirm python-pipx
        
        # Install language servers using pipx
        pipx install pyright
        pipx install ruff
        pipx install black
        pipx install isort
        
        # Add pipx bin directory to PATH if not already there
        echo 'export PATH="$HOME/.local/bin:$PATH"' | tee -a "$HOME/.bashrc" "$HOME/.zshrc" >/dev/null
    fi
}

setup_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "INFO" "Instalando Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    if [ "$SHELL" != "$(which zsh)" ]; then
        log "INFO" "Cambiando shell por defecto a Zsh..."
        sudo chsh -s "$(which zsh)" "$USER"
    fi
}

install_docker() {
    if ! is_installed docker; then
        log "INFO" "Instalando Docker..."
        
        if [ "$DISTRO" = "debian" ]; then
            # Configurar repositorio para Debian/Ubuntu
            sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io
        else
            # Instalación para Arch Linux
            sudo pacman -S --noconfirm docker
            sudo systemctl start docker.service
            sudo systemctl enable docker.service
        fi
        check_error "Error en la instalación de Docker"
        
        # Agregar usuario al grupo docker
        sudo usermod -aG docker $USER
    fi
}

configure_docker() {
    log "INFO" "Configurando Docker..."
    
    # Instalar Docker Compose
    if ! is_installed docker-compose; then
        log "INFO" "Instalando Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Configurar permisos
    if [ ! -S "/var/run/docker.sock" ]; then
        log "ERROR" "Socket de Docker no encontrado"
        exit 1
    fi
    
    sudo chown $USER:docker /var/run/docker.sock
    sudo chmod 660 /var/run/docker.sock
}

setup_java() {
    if ! is_installed java; then
        log "INFO" "Configurando Java..."
        
        # Instalar SDKMAN si no existe
        if [ ! -d "$HOME/.sdkman" ]; then
            curl -s "https://get.sdkman.io" | bash
            source "$HOME/.sdkman/bin/sdkman-init.sh"
        fi
        
        # Instalar versiones de Java
        sdk install java $JAVA_VERSION
        sdk install java $JAVA_LTS_VERSION
        sdk default java $JAVA_VERSION
        
        # Configurar variables de entorno
        echo 'export JAVA_HOME="$HOME/.sdkman/candidates/java/current"' >> $HOME/.zshrc
        echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> $HOME/.zshrc
    fi
}

install_rust() {
    if ! is_installed rustc; then
        log "INFO" "Instalando Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> $HOME/.zshrc
    fi
}

# Añadir estas nuevas funciones al script
install_java_dependencies() {
    log "INFO" "Instalando dependencias Java..."
    
    if [ "$DISTRO" = "debian" ]; then
        sudo apt install -y openjdk-17-jdk maven gradle
        local java_home=$(update-alternatives --list java | head -1 | sed 's/\/bin\/java//')
    else
        sudo pacman -S --noconfirm jdk-openjdk maven gradle
        # Corregir ruta para Arch Linux
        local java_home="/usr/lib/jvm/default"
        if [ ! -d "$java_home" ]; then
            java_home=$(ls -d /usr/lib/jvm/java-*-openjdk | head -1)
        fi
    fi
    
    # Validación mejorada de JAVA_HOME
    if [ -d "$java_home" ]; then
        echo "export JAVA_HOME='$java_home'" | tee -a "$HOME/.bashrc" "$HOME/.zshrc"
        export JAVA_HOME="$java_home"
        log "INFO" "JAVA_HOME configurado en: $java_home"
    else
        log "ERROR" "No se pudo determinar JAVA_HOME - Directorio no encontrado: $java_home"
        exit 1
    fi
}

install_nerd_fonts() {
    log "INFO" "Instalando Iosevka Nerd Font..."
    
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Iosevka.zip"
    local font_dir="$HOME/.local/share/fonts"
    
    mkdir -p "$font_dir"
    curl -L -o "/tmp/Iosevka.zip" "$font_url"
    unzip -o "/tmp/Iosevka.zip" -d "$font_dir"
    rm "/tmp/Iosevka.zip"
    
    # Corregir nombres de archivos con espacios
    find "$font_dir" -name "* *" -exec rename 's/ /-/g' {} \;
    
    # Forzar actualización de caché de fuentes
    fc-cache -fv
    
    # Verificación adicional
    if ! fc-list | grep -i "Iosevka" >/dev/null; then
        log "ERROR" "La instalación de la fuente falló"
        exit 1
    fi
}


configure_jdtls() {
    log "INFO" "Configurando JDTLS para Neovim..."
    
    # Instalación forzada y limpieza previa
    nvim --headless -c "MasonInstall --force jdtls java-test java-debug-adapter" -c 'qall'
    
    # Configuración mejorada
    local jdtls_config='
local jdtls = require("jdtls")
local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", vim.fn.stdpath("data") .. "/jdtls_workspace"
    },
    root_dir = jdtls.setup.find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "'$JAVA_HOME'",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        if vim.bo.filetype == "java" and vim.fn.bufname() ~= "" then
            jdtls.start_or_attach(config)
        end
    end,
})'

    # Manejo seguro de la configuración
    if [ -f "$HOME/dotfiles/init.lua" ]; then
        # Eliminar configuraciones antiguas
        sed -i '/jdtls\.start_or_attach/,/})/d' "$HOME/dotfiles/init.lua"
        sed -i '/require("jdtls")/d' "$HOME/dotfiles/init.lua"
        
        # Añadir nueva configuración
        echo "$jdtls_config" >> "$HOME/dotfiles/init.lua"
    else
        log "ERROR" "Archivo init.lua no encontrado en dotfiles"
        exit 1
    fi
}

configure_wezterm() {
    log "INFO" "Configurando WezTerm..."
    
    local wezterm_config='
local wezterm = require("wezterm")
return {
    font = wezterm.font("Iosevka Nerd Font", {weight="Regular", stretch="Normal", style="Normal"}),
    font_size = 12.0,
    color_scheme = "Gruvbox Dark",
    hide_tab_bar_if_only_one_tab = true,
    enable_scroll_bar = false,
    default_prog = { "zsh", "-l" },
    warn_about_missing_glyphs = false
}'
    
    if [ -f "$HOME/dotfiles/wezterm.lua" ]; then
        echo "$wezterm_config" > "$HOME/dotfiles/wezterm.lua"
    else
        log "ERROR" "Archivo wezterm.lua no encontrado en dotfiles"
        exit 1
    fi
}

configure_jdtls() {
    log "INFO" "Configurando JDTLS para Neovim..."
    
    # Instalación forzada y limpieza previa
    nvim --headless -c "MasonInstall --force jdtls java-test java-debug-adapter" -c 'qall'
    
    # Configuración mejorada
    local jdtls_config='
local jdtls = require("jdtls")
local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", vim.fn.stdpath("data") .. "/jdtls_workspace"
    },
    root_dir = jdtls.setup.find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "'$JAVA_HOME'",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        if vim.bo.filetype == "java" and vim.fn.bufname() ~= "" then
            jdtls.start_or_attach(config)
        end
    end,
})'

    # Manejo seguro de la configuración
    if [ -f "$HOME/dotfiles/init.lua" ]; then
        # Eliminar configuraciones antiguas
        sed -i '/jdtls\.start_or_attach/,/})/d' "$HOME/dotfiles/init.lua"
        sed -i '/require("jdtls")/d' "$HOME/dotfiles/init.lua"
        
        # Añadir nueva configuración
        echo "$jdtls_config" >> "$HOME/dotfiles/init.lua"
    else
        log "ERROR" "Archivo init.lua no encontrado en dotfiles"
        exit 1
    fi
}

configure_wezterm() {
    log "INFO" "Configurando WezTerm..."
    
    local wezterm_config='
local wezterm = require("wezterm")
return {
    font = wezterm.font("Iosevka Nerd Font", {weight="Regular", stretch="Normal", style="Normal"}),
    font_size = 12.0,
    color_scheme = "Gruvbox Dark",
    hide_tab_bar_if_only_one_tab = true,
    enable_scroll_bar = false,
    default_prog = { "zsh", "-l" },
    warn_about_missing_glyphs = false
}'
    
    if [ -f "$HOME/dotfiles/wezterm.lua" ]; then
        echo "$wezterm_config" > "$HOME/dotfiles/wezterm.lua"
    else
        log "ERROR" "Archivo wezterm.lua no encontrado en dotfiles"
        exit 1
    fi
}

configure_neovim() {
    log "INFO" "Configurando Neovim..."
    
    local nvim_dir="$HOME/.config/nvim"
    local wezterm_dir="$HOME/.config/wezterm"
    
    # Crear directorios si no existen
    mkdir -p "$nvim_dir" "$wezterm_dir"
    
    # Configuración de Neovim
    if [ -f "$HOME/dotfiles/init.lua" ]; then
        backup_config "$nvim_dir/init.lua"
        ln -sf "$HOME/dotfiles/init.lua" "$nvim_dir/init.lua"
    else
        log "ERROR" "Archivo init.lua no encontrado en dotfiles"
        exit 1
    fi
    
    # Configuración de WezTerm
    if [ -f "$HOME/dotfiles/wezterm.lua" ]; then
        backup_config "$wezterm_dir/wezterm.lua"
        ln -sf "$HOME/dotfiles/wezterm.lua" "$wezterm_dir/wezterm.lua"
    else
        log "WARN" "Archivo wezterm.lua no encontrado en dotfiles"
    fi
    
    # Asegurarse de que Neovim esté en el PATH
    export PATH="/opt/nvim/bin:$PATH"
    
    # Instalar plugins de Neovim
    log "INFO" "Instalando plugins de Neovim..."
    if is_installed nvim; then
        nvim --headless "+Lazy! sync" +qa
    else
        log "WARN" "Neovim no está disponible en el PATH. Se omitirá la instalación de plugins."
        log "INFO" "Ejecuta manualmente 'nvim' después de reiniciar la terminal para instalar los plugins."
    fi
}

configure_jdtls() {
    log "INFO" "Configurando JDTLS para Neovim..."
    
    # Instalación forzada y limpieza previa
    nvim --headless -c "MasonInstall --force jdtls java-test java-debug-adapter" -c 'qall'
    
    # Configuración mejorada
    local jdtls_config='
local jdtls = require("jdtls")
local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xmx4g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "-jar", vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
        "-configuration", vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_linux",
        "-data", vim.fn.stdpath("data") .. "/jdtls_workspace"
    },
    root_dir = jdtls.setup.find_root({".git", "mvnw", "gradlew"}),
    settings = {
        java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = "fernflower" },
            configuration = {
                runtimes = {
                    {
                        name = "JavaSE-17",
                        path = "'$JAVA_HOME'",
                    }
                }
            }
        }
    },
    init_options = {
        bundles = {}
    }
}

vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        if vim.bo.filetype == "java" and vim.fn.bufname() ~= "" then
            jdtls.start_or_attach(config)
        end
    end,
})'

    # Manejo seguro de la configuración
    if [ -f "$HOME/dotfiles/init.lua" ]; then
        # Eliminar configuraciones antiguas
        sed -i '/jdtls\.start_or_attach/,/})/d' "$HOME/dotfiles/init.lua"
        sed -i '/require("jdtls")/d' "$HOME/dotfiles/init.lua"
        
        # Añadir nueva configuración
        echo "$jdtls_config" >> "$HOME/dotfiles/init.lua"
    else
        log "ERROR" "Archivo init.lua no encontrado en dotfiles"
        exit 1
    fi
}
main() {
    log "INFO" "Iniciando instalación del entorno de desarrollo..."
    
    # Orden de ejecución corregido
    install_system_dependencies
    setup_dotfiles
    install_nerd_fonts
    install_neovim
    configure_wezterm
    install_wezterm
    setup_node
    install_language_servers
    setup_zsh
    install_docker
    configure_docker
    setup_java
    install_rust
    install_java_dependencies
    configure_jdtls
    configure_neovim

    log "INFO" "¡Instalación completada!"
    log "WARN" "Por favor, cierra esta terminal y abre una nueva"
    log "INFO" "Ejecuta 'nvim' para completar la configuración de plugins"
}
# Ejecutar el script
main "$@"

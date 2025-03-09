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
    log "INFO" "Instalando/Actualizando Neovim ${NVIM_VERSION}..."
    sudo rm -rf /opt/nvim* # Limpiar instalaciones previas
    curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
    tar -xzf nvim-linux64.tar.gz
    sudo mv nvim-linux64 /opt/nvim-${NVIM_VERSION}
    sudo ln -sf /opt/nvim-${NVIM_VERSION} /opt/nvim
    echo 'export PATH="/opt/nvim/bin:$PATH"' | tee -a ~/.bashrc ~/.zshrc
    source ~/.zshrc
    rm nvim-linux64.tar.gz
}


install_wezterm() {
    log "INFO" "Instalando WezTerm..."
    if is_installed wezterm; then
        log "INFO" "WezTerm ya está instalado"
        return 0
    fi

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
    log "INFO" "Configurando entorno Node.js..."
    
    # Instalación robusta de fnm
    if ! command -v fnm &>/dev/null; then
        log "INFO" "Instalando fnm..."
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir "$HOME/.fnm"
        echo 'export PATH="$HOME/.fnm:$PATH"' >> ~/.zshrc
        echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc
        source ~/.zshrc
    fi

    # Instalación específica de versión Node.js
    log "INFO" "Instalando Node.js v${NODE_LTS_VERSION}..."
    fnm install --lts=erbium
    fnm default "$NODE_LTS_VERSION"
    fnm use default

    # Configuración de npm segura
    local NPM_PACKAGES=(typescript typescript-language-server prettier @prisma/language-server)
    log "INFO" "Instalando paquetes globales de npm..."
    npm install -g --prefix "$HOME/.npm-global" "${NPM_PACKAGES[@]}" 2>&1 | while read line; do log "NPM" "$line"; done
    
    # Añadir npm al PATH
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zshrc
    export PATH="$HOME/.npm-global/bin:$PATH"
}


install_language_servers() {
    log "INFO" "Instalando herramientas Python..."
    
    # Sistema tipo para pipx
    if [ "$DISTRO" = "arch" ]; then
        python -m pip install --user pipx
        python -m pipx ensurepath
        for pkg in pyright ruff black isort; do
            pipx install $pkg --force
        done
    else
        pip3 install --user --upgrade ${REQUIRED_PY_PKGS[@]}
    fi
    
    # Verificar instalación
    for pkg in ${REQUIRED_PY_PKGS[@]}; do
        if ! pipx list | grep -q $pkg; then
            log "ERROR" "Paquete Python $pkg no instalado"
            exit 1
        fi
    done
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
    
    # Verificación y configuración de grupos
    if ! groups | grep -q docker; then
        log "INFO" "Añadiendo usuario al grupo docker..."
        sudo usermod -aG docker "$USER"
        newgrp docker <<< "echo 'Grupo docker actualizado'"
    fi
    
    # Reinicio seguro del servicio
    if ! systemctl is-active --quiet docker; then
        log "INFO" "Iniciando servicio Docker..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi
    
    # Verificación final
    if ! docker info &>/dev/null; then
        log "ERROR" "No se pudo inicializar Docker correctamente"
        exit 1
    fi
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


configure_jdtls() {
    log "INFO" "Configurando JDTLS para Neovim..."
    
    # Intento de instalación con reintentos mejorado
    MAX_RETRIES=3
    RETRY_DELAY=5
    for ((i=1; i<=$MAX_RETRIES; i++)); do
        log "INFO" "Intento de instalación $i/$MAX_RETRIES"
        nvim --headless -c "MasonInstall --force jdtls java-test java-debug-adapter" -c "qall" 2>/dev/null
        
        if [ -d "$HOME/.local/share/nvim/mason/packages/jdtls" ]; then
            log "INFO" "Paquetes de JDTLS instalados correctamente"
            break
        else
            log "WARN" "Fallo en el intento $i. Reintentando en $RETRY_DELAY segundos..."
            sleep $RETRY_DELAY
        fi
    done
    
    # Verificación final robusta
    local REQUIRED_PACKAGES=(jdtls java-test java-debug-adapter)
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if [ ! -d "$HOME/.local/share/nvim/mason/packages/$pkg" ]; then
            log "ERROR" "Paquete crítico faltante: $pkg"
            exit 1
        fi
    done

    # Configuración consolidada sin duplicados
    local JDTLS_CONFIG='
    -- Configuración única y completa para JDTLS
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
        end
    })'

    # Manejo de configuración mejorado
    local NVIM_CONFIG="$HOME/dotfiles/init.lua"
    if [ -f "$NVIM_CONFIG" ]; then
        # Limpieza de configuraciones antiguas
        sed -i '/jdtls\.start_or_attach/,/})/d' "$NVIM_CONFIG"
        sed -i '/require("jdtls")/d' "$NVIM_CONFIG"
        
        # Inserción segura de nueva configuración
        echo "$JDTLS_CONFIG" | tee -a "$NVIM_CONFIG" >/dev/null
    else
        log "ERROR" "Archivo de configuración principal no encontrado: $NVIM_CONFIG"
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
# Función principal optimizada
main() {
    log "INFO" "Iniciando instalación completa..."
    
    # Secuencia de instalación optimizada
    install_system_dependencies
    setup_dotfiles
    install_nerd_fonts
    install_wezterm
    install_neovim
    configure_neovim
    setup_node
    install_language_servers
    setup_zsh
    install_docker
    configure_docker
    setup_java
    install_java_dependencies
    install_rust
    configure_jdtls
    configure_wezterm
    
    log "SUCCESS" "¡Instalación completada con éxito!"
    log "INFO" "Por favor, cierra y reinicia tu terminal"
}

# Ejecución principal
main "$@"

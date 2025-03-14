
# Available with Ubuntu/Debian | Archlinux 
# Dotfiles

[![Tema de Colores](https://img.shields.io/badge/theme-gruvbox%20dark-brightgreen)](https://github.com/morhetz/gruvbox)
[![Neovim](https://img.shields.io/badge/Neovim-v0.10.3-blueviolet)](https://neovim.io)
[![Estado](https://img.shields.io/badge/estado-stand%20by-yellowgreen)](https://github.com/programmingwithclaudio/dotfiles)
[![Licencia](https://img.shields.io/badge/licencia-MIT-blue)](https://opensource.org/licenses/MIT)

- **Requirements**:
 -  Git
 -  Node
 -  yay

- **Clone dotfiles or download**
  Ejecuta el siguiente comando en tu terminal para clonar el repositorio que contiene tus configuraciones personalizadas:
  ```bash
  git clone https://github.com/programmingwithclaudio/dotfiles.git
  ```
- **EXEC script settings**:
  Una vez clonado el repositorio, ejecuta el script que configura tu entorno:
  ```bash
  chmod +x ~/dotfiles/setup_utils.sh
  ~/dotfiles/setup_utils.sh
  ```
  - Reemplaza los files basicos de configuracion por los de la repo
  ```bash
  python3 -m venv ~/.venvs/nvim
  npm install -g typescript typescript-language-server prettier @prisma/language-server pyright

  
  mkdir -p ~/.local/share/nvim/mason/packages/jdtls
  cd ~/.local/share/nvim/mason/packages/jdtls
  wget -O jdtls.tar.gz https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz
  tar -xzf jdtls.tar.gz

  ```
  - Reemplaza los files basicos de configuracion por los de la repo
  ```bash
  rm -f ~/.config/nvim/init.lua ~/.config/wezterm/wezterm.lua
  mv ~/dotfiles/init.lua ~/.config/nvim/init.lua
  mv ~/dotfiles/wezterm.lua ~/.config/wezterm/wezterm.lua
  ```

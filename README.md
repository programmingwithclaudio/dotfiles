# Ubuntu/Debian
### config
- Iniciar la configuración de la terminal de desarrollo
```bash
~/dotfiles/setup_environment.sh
```
- Configurar el init.lua
```bash
rm ~/.config/nvim/init.vim
mv ~/dotfiles/init.lua ~/.config/nvim/init.lua
nvim
:Mason
```

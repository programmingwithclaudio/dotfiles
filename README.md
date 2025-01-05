# Configuración de la Terminal de Desarrollo en Ubuntu/Debian

Debes seguir estos pasos:

- **Clonar el repositorio de dotfiles**
   Ejecuta el siguiente comando en tu terminal para clonar el repositorio que contiene tus configuraciones personalizadas:
   ```bash
   git clone git@github.com:programmingwithclaudio/dotfiles.git
   ```
- **Ejecutar el script de configuración**:
   Una vez clonado el repositorio, ejecuta el script que configura tu entorno:
   ```bash
   ~/dotfiles/setup_environment.sh
   ```

#### Configuración de Neovim

Para configurar Neovim con un archivo `init.lua`, sigue estos pasos:

- **Eliminar la configuración anterior**:
   Primero, elimina el archivo de configuración existente de Neovim:
   ```bash
   rm ~/.config/nvim/init.vim
   ```

- **Mover el nuevo archivo de configuración**:
   Luego, mueve el archivo `init.lua` desde tu repositorio de dotfiles a la ubicación de configuración de Neovim:
   ```bash
   mv ~/dotfiles/init.lua ~/.config/nvim/init.lua
   ```

- **Iniciar Neovim**:
   Abre Neovim para asegurarte de que la configuración se ha aplicado correctamente:
   ```bash
   nvim
   ```

- **Instalar complementos**:
   Dentro de Neovim, ejecuta el comando para instalar los complementos necesarios:
   ```vim
   :Mason
   ```

#### Notas Finales

Esta configuración es un buen punto de partida para tu entorno de desarrollo. A medida que avances, puedes ir agregando mejoras y personalizaciones según tus necesidades. ¡Buena suerte con tu configuración!

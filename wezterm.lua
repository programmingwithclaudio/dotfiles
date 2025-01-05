local wezterm = require 'wezterm'
local act = wezterm.action

-- Función auxiliar para el formato de pestañas
local function tab_title(tab_info)
  local title = tab_info.tab_title
  if title and #title > 0 then
    return title
  end
  return tab_info.active_pane.title
end

local config = {}

-- Obtener configuración específica del sistema operativo
function config:init()
  config = {
    -- Esquema de colores y tema
    color_scheme = "Catppuccin Mocha",
    -- Configuración avanzada de colores
    colors = {
      background = '#1a1b26',
      foreground = '#c0caf5',
      cursor_bg = '#c0caf5',
      cursor_border = '#c0caf5',
      cursor_fg = '#1a1b26',
      selection_bg = '#33467c',
      selection_fg = '#c0caf5',
    },

    -- Configuración de fuente avanzada
    font = wezterm.font_with_fallback({
      {
        family = "Iosevka Nerd Font",
        weight = "Regular",
        harfbuzz_features = {"calt=1", "clig=1", "liga=1"},
      },
      "JetBrainsMono Nerd Font",
      "Symbols Nerd Font",
    }),
    font_size = 12.0,
    line_height = 1.1,
    
    -- Configuración del cursor
    default_cursor_style = "SteadyBar",
    cursor_blink_rate = 500,
    force_reverse_video_cursor = true,

    -- Configuración de pestañas mejorada
    use_fancy_tab_bar = true,
    hide_tab_bar_if_only_one_tab = false,
    tab_bar_at_bottom = true,
    tab_max_width = 25,
    show_tab_index_in_tab_bar = true,
    switch_to_last_active_tab_when_closing_tab = true,

    -- Atajos de teclado extendidos
    keys = {
      -- Gestión de pestañas
      {key="t", mods="CTRL", action=act{SpawnTab="CurrentPaneDomain"}},
      {key="w", mods="CTRL", action=act{CloseCurrentTab={confirm=true}}},
      {key="Tab", mods="CTRL", action=act{ActivateTabRelative=1}},
      {key="Tab", mods="CTRL|SHIFT", action=act{ActivateTabRelative=-1}},
      
      -- Gestión de paneles
      {key="v", mods="CTRL|SHIFT", action=act{SplitVertical={domain="CurrentPaneDomain"}}},
      {key="h", mods="CTRL|SHIFT", action=act{SplitHorizontal={domain="CurrentPaneDomain"}}},
      {key="LeftArrow", mods="CTRL|SHIFT", action=act{ActivatePaneDirection="Left"}},
      {key="RightArrow", mods="CTRL|SHIFT", action=act{ActivatePaneDirection="Right"}},
      {key="UpArrow", mods="CTRL|SHIFT", action=act{ActivatePaneDirection="Up"}},
      {key="DownArrow", mods="CTRL|SHIFT", action=act{ActivatePaneDirection="Down"}},
      
      -- Funcionalidades adicionales
      {key="f", mods="CTRL|SHIFT", action=act.ToggleFullScreen},
      {key="c", mods="CTRL|SHIFT", action=act.CopyTo("Clipboard")},
      {key="v", mods="CTRL|SHIFT", action=act.PasteFrom("Clipboard")},
      {key="=", mods="CTRL", action=act.IncreaseFontSize},
      {key="-", mods="CTRL", action=act.DecreaseFontSize},
      {key="0", mods="CTRL", action=act.ResetFontSize},
    },

    -- Configuración avanzada de ventana
    window_decorations = "RESIZE",
    window_background_opacity = 0.95,
    text_background_opacity = 1.0,
    window_padding = {
      left = 8,
      right = 8,
      top = 8,
      bottom = 8,
    },
    window_frame = {
      font = wezterm.font({family = "Iosevka Nerd Font", weight = "Bold"}),
      font_size = 11.0,
    },

    -- Opciones de rendimiento y comportamiento
    scrollback_lines = 10000,
    enable_scroll_bar = true,
    scroll_to_bottom_on_input = true,
    exit_behavior = "Close",
    quick_select_patterns = {
      -- Patrones personalizados para QuickSelect
      [[\b\w+@[\w-]+\.\w+\b]], -- direcciones de correo
      [[\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b]], -- direcciones IP
      [[\b[0-9a-f]{7,40}\b]], -- hashes git
      [[\b\d+\b]], -- números
    },

    -- Configuración de shell
    default_prog = {"/bin/zsh", "-l"},
    set_environment_variables = {
      TERM = "wezterm",
      COLORTERM = "truecolor",
    },
  }

  return config
end

return config:init()

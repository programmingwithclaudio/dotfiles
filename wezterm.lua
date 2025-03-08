
local wezterm = require("wezterm")
return {
    font = wezterm.font("Iosevka Nerd Font", {weight="Regular", stretch="Normal", style="Normal"}),
    font_size = 12.0,
    color_scheme = "Catppuccin Mocha",
    hide_tab_bar_if_only_one_tab = true,
    enable_scroll_bar = false,
    default_prog = { "zsh", "-l" },
    warn_about_missing_glyphs = false
}

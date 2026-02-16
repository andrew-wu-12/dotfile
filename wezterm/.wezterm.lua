local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.enable_tab_bar = false
config.initial_rows = 50
config.initial_cols = 180
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.8
config.macos_window_background_blur = 20
return config

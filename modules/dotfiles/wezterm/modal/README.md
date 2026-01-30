# Modal Plugin - Local Version

This is a local copy of the [modal.wezterm](https://github.com/MLFlexer/modal.wezterm) plugin, integrated directly into the wezterm configuration.

## Structure

```
modal/
├── init.lua           # Core modal functionality
└── modes/            # Modal modes
    ├── ui_mode.lua
    ├── scroll_mode.lua
    ├── copy_mode.lua
    ├── search_mode.lua
    └── visual_mode.lua
```

## Changes from Original

- **init.lua**: Modified `enable_defaults()` to load modes from local `modes/` directory instead of plugin URL
- **modes/*.lua**: Changed `wezterm.plugin.require()` to `require('modal')` for local module resolution

## Usage

The module is loaded in `config/modal.lua`:

```lua
local modal = require("modal")
modal.enable_defaults()
```

## Upstream

Based on: https://github.com/MLFlexer/modal.wezterm

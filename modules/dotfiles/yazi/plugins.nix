# Yazi plugins - declarative configuration
# Add plugins here and ils seront installés automatiquement via home-manager

{
  # Plugins from yazi-rs/plugins
  plugins = [
    "git"
    "diff"
    "toggle-pane"
    "smart-filter"
    "ouch"
    "mactag"
    "folder-rules"
  ];

  # Flavors (themes) from yazi-rs/flavors
  flavors = [
    "catppuccin-frappe-lavender"
  ];
}

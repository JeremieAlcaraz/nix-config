{ ... }:

let
  yaziSource = ../modules/dotfiles/yazi;
  yaziConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/yazi.toml");
  keymapConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/keymap.toml");
  themeConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/theme.toml");
in
{
  programs.yazi = {
    enable = true;
    # package géré via brew (voir .local/bin/yazi dans marigold.nix)
  };

  # yaziPlugins: gérés via brew (non compatible avec le package brew)
  # Pour installer les plugins: ya pkg add yazi-git yazi-starship

  programs.yazi.settings = yaziConfig;
  programs.yazi.keymap = keymapConfig;
  programs.yazi.theme = themeConfig;
}

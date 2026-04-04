{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    wezterm
  ];

  # Migré vers Dotbot pour lien direct repo -> ~/.config/wezterm.
}

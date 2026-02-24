{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    wezterm
  ];

  xdg.configFile."wezterm".source = config.jeremie.dotfiles.source "wezterm";
}

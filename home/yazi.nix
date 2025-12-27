{ config, lib, pkgs, ... }:

let
  yaziSource = ../modules/dotfiles/yazi;
  yaziConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/yazi.toml");
  keymapConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/keymap.toml");
  themeConfig = builtins.fromTOML (builtins.readFile "${yaziSource}/theme.toml");
in
{
  programs.yazi = {
    enable = true;
    package = lib.mkForce (pkgs.unstable.yazi.override {
      extraPackages = config.programs.yazi.yaziPlugins.runtimeDeps;
    });
  };

  programs.yazi.yaziPlugins = {
    enable = true;
    plugins = {
      git.enable = true;
      starship.enable = true;
    };
  };

  programs.yazi.settings = {
    yazi = yaziConfig;
    keymap = keymapConfig;
    theme = themeConfig;
  };
}

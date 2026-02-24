{ config, pkgs, ... }:
let
  dotfilesSource = config.jeremie.dotfiles.source;
in {
  programs.zsh.enable = true;
  home.file = {
    ".zshrc".source = dotfilesSource "zsh/.zshrc";
    ".zshenv".source = dotfilesSource "zsh/.zshenv";
  };
}

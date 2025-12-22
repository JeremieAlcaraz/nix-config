{ config, pkgs, ... }:
let
  dotfilesPath = "/Users/jeremiealcaraz/Development/_programmation/_production/_services/nix-config/modules/dotfiles";
in
{
  programs.zsh.enable = true;
  home.file = {
    ".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.zshrc";
    ".zshenv".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/zsh/.zshenv";
  };
}

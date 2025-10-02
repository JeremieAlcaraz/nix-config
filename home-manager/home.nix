# Configuration utilisateur avec Home Manager
{ config
, pkgs
, inputs
, ...
}: {
  # ╭──────────────────────────────────────────────────────────────╮
  # │                       IDENTITÉ UTILISATEUR                   │
  # ╰──────────────────────────────────────────────────────────────╯
  home.username = "jeremie";
  home.homeDirectory = "/home/jeremie";

  # ╭──────────────────────────────────────────────────────────────╮
  # │               IMPORTS MODULES HOME-MANAGER                   │
  # ╰──────────────────────────────────────────────────────────────╯
  # 🔧 N'itère QUE dans modules/home (évite les modules système)
  imports =
    let
      root = inputs.self + "/modules/home";
      entries = builtins.readDir root;
      names = builtins.attrNames entries;
      dirs = builtins.filter (n: entries.${n} == "directory") names;
      sorted = builtins.sort builtins.lessThan dirs;
    in
    builtins.map (n: root + "/${n}") sorted;

  # ╭──────────────────────────────────────────────────────────────╮
  # │                 PAQUETS SANS MODULE HOME-MANAGER             │
  # ╰──────────────────────────────────────────────────────────────╯
  home.packages = with pkgs; [
    # Outils de développement
    inputs.neovim.packages.${pkgs.system}.default
    gh
    cowsay
    tree
    fzf
    ripgrep
    delta # pager utilisé par lazygit
  ];

  # ╭──────────────────────────────────────────────────────────────╮
  # │                 VARIABLES & FICHIERS PERSONNELS              │
  # ╰──────────────────────────────────────────────────────────────╯
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # home.file = {};

  # ╭──────────────────────────────────────────────────────────────╮
  # │                       MÉTA-CONFIG HM                         │
  # ╰──────────────────────────────────────────────────────────────╯
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
}

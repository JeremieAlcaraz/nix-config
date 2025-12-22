{ config, pkgs, ... }:

{
  home.stateVersion = "23.11";
  home.username = "jeremiealcaraz";
  home.homeDirectory = "/Users/jeremiealcaraz";

  # 1. Installation de cowsay
  home.packages = [
    pkgs.cowsay
  ];

  # 2. Création d'un fichier de test (XDG compliant)
  # Ce fichier sera créé dans ~/.config/nix-test.txt
  xdg.enable = true;
  xdg.configFile."nix-test.txt".text = ''
    Test de Home Manager pour Marigold.
    Date : 22 décembre 2025
    Statut : En cours de déploiement.
  '';
}

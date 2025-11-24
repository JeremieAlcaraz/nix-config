# ============================================================================
# Module commun "base.nix"
# ---------------------------------------------------------------------------
# Ce module est chargé sur toutes les machines virtuelles définies dans ce
# dépôt. Il regroupe les paquets et options de base qui doivent être présents
# partout pour l'administration et le débogage.
# ============================================================================

{ pkgs, ... }:
{
  imports = [
    ./git.nix
  ];

  time.timeZone = "Europe/Paris";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Binary caches : sources de packages pré-compilés
    # Évite de recompiler depuis les sources (gain de temps énorme !)
    substituters = [
      "https://cache.nixos.org"  # Cache officiel NixOS (par défaut mais explicite)
    ];

    # Clés publiques pour vérifier les signatures des packages téléchargés
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];

    # Optimisation des builds
    max-jobs = "auto";  # Utilise tous les cores disponibles
    cores = 0;          # Tous les cores par job (0 = auto)
  };

  programs = {
    fish.enable = true;
    tmux.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    wget
    jq
  ];
}

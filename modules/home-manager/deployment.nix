# ============================================================================
# Module "deployment.nix"
# ---------------------------------------------------------------------------
# Configure une clé SSH privée pour permettre à ce serveur de déployer
# sur d'autres hôtes (via nixos-rebuild) et d'accéder à GitHub.
#
# Usage:
#   - La clé privée est stockée dans sops-nix (chiffrée) sous "private-ssh-key"
#   - La clé publique correspondante doit être dans les authorized_keys des cibles
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # Installer Git si ce n'est pas déjà fait (requis pour nixos-rebuild avec flakes)
  environment.systemPackages = with pkgs; [
    git
  ];

  # Configuration de la clé SSH privée
  # Le secret est déchiffré par sops-nix dans /run/secrets/
  sops.secrets."private-ssh-key" = {
    mode = "0600";
    owner = "jeremie";
    group = "users";
  };

  # Configuration SSH pour utiliser cette clé
  programs.ssh.extraConfig = ''
    # Configuration pour GitHub (accès aux repos privés / push)
    Host github.com
      HostName github.com
      User git
      IdentityFile /run/secrets/private-ssh-key
      IdentitiesOnly yes

    # Configuration par défaut pour les déploiements vers d'autres hôtes
    # On utilise la même clé pour se connecter aux autres serveurs
    Host *
      IdentityFile /run/secrets/private-ssh-key
  '';

  # Configuration Git globale pour jeremie (utile pour les commits automatiques)
  environment.etc."gitconfig".text = ''
    [user]
      name = Jeremie Alcaraz
      email = jeremie@alcaraz.dev

    [init]
      defaultBranch = main

    [core]
      editor = vim

    [safe]
      directory = /home/jeremie/nixos
  '';
}

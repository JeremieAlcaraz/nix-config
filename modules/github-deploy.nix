# ============================================================================
# Module "github-deploy.nix"
# ---------------------------------------------------------------------------
# Configure une Deploy Key pour permettre à un serveur de pusher vers GitHub.
# Utilisé principalement pour que Magnolia puisse commit/push le flake.lock
# après avoir buildé.
#
# Usage:
#   - La clé privée est stockée dans sops-nix (chiffrée)
#   - La clé publique doit être ajoutée comme Deploy Key sur GitHub
#   - Git est configuré pour utiliser cette clé automatiquement
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # Installer Git si ce n'est pas déjà fait
  environment.systemPackages = with pkgs; [
    git
  ];

  # Configuration de la Deploy Key SSH
  sops.secrets."github-deploy-key" = {
    sopsFile = ../../secrets/magnolia.yaml;
    mode = "0600";
    owner = "jeremie";
    group = "users";
    path = "/home/jeremie/.ssh/github-deploy";
  };

  # Configuration SSH pour utiliser la Deploy Key avec GitHub
  programs.ssh.extraConfig = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile /home/jeremie/.ssh/github-deploy
      IdentitiesOnly yes
  '';

  # Configuration Git globale pour jeremie
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

  # Assure que le répertoire .ssh existe avec les bonnes permissions
  systemd.tmpfiles.rules = [
    "d /home/jeremie/.ssh 0700 jeremie users - -"
  ];
}

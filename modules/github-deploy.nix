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
  # Le secret est déchiffré par sops-nix dans /run/secrets/
  sops.secrets."github-deploy-key" = {
    mode = "0600";
    owner = "jeremie";
    group = "users";
  };

  # Configuration SSH pour utiliser la Deploy Key avec GitHub
  # Le secret est dans /run/secrets/ (géré par sops-nix)
  # Un lien symbolique est créé dans ~/.ssh/ pour faciliter l'utilisation
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
  # et crée un lien symbolique vers le secret déchiffré
  systemd.tmpfiles.rules = [
    "d /home/jeremie/.ssh 0700 jeremie users - -"
    "L+ /home/jeremie/.ssh/github-deploy - jeremie users - /run/secrets/github-deploy-key"
  ];
}

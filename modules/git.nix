# ============================================================================
# Module "git.nix"
# ---------------------------------------------------------------------------
# Ce module centralise toute la configuration Git pour le système NixOS.
# Il garantit que Git est installé et configuré correctement, et que les
# dépôts ont les bonnes permissions.
# ============================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.nixConfig or {};
  # Chemin standard du dépôt NixOS (peut être surchargé si besoin pour des cas particuliers)
  repoPath = cfg.repoPath or "/etc/nixos";
  # Propriétaire par défaut (peut être surchargé par nixConfig.repoOwner)
  repoOwner = cfg.repoOwner or "jeremie";
in
{
  # =========================================================================
  # OPTIONS DE CONFIGURATION
  # =========================================================================

  options = {
    nixConfig = {
      repoPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Chemin du dépôt nix-config à gérer.
          Par défaut: /etc/nixos (emplacement standard NixOS)
          Utile uniquement si vous avez un setup non-standard.
        '';
        example = "/home/jeremie/dev/nix-config";
      };

      repoOwner = lib.mkOption {
        type = lib.types.str;
        default = "jeremie";
        description = "Utilisateur propriétaire du dépôt";
        example = "jeremie";
      };
    };
  };

  # =========================================================================
  # CONFIGURATION GIT SYSTÈME
  # =========================================================================

  config = {
    # Installation de Git au niveau système
    environment.systemPackages = with pkgs; [
      git
    ];

    # Configuration Git globale (système)
    # Vous pouvez ajouter ici d'autres paramètres Git si nécessaire
    # environment.etc."gitconfig".text = ''
    #   [core]
    #     editor = vim
    #   [init]
    #     defaultBranch = main
    # '';

    # =========================================================================
    # GESTION DÉCLARATIVE DES PERMISSIONS DU DÉPÔT
    # =========================================================================
    #
    # Problème résolu :
    # Lorsque des opérations système (comme sudo, nix-build, ou certains
    # services) modifient des fichiers dans le dépôt Git, ils peuvent changer
    # le propriétaire en 'root', causant des erreurs "Permission denied" lors
    # de l'utilisation de Git.
    #
    # Solution :
    # Utilise systemd.tmpfiles.rules pour appliquer automatiquement les bonnes
    # permissions à chaque boot et à chaque activation de configuration.
    # Cette approche est déclarative et s'intègre parfaitement à NixOS.
    #
    # Format systemd.tmpfiles : Type Path Mode UID GID Age Argument
    # Z = Set ownership and access mode recursively (récursif)
    # =========================================================================

    systemd.tmpfiles.rules = [
      # Fixe les permissions du dépôt nix-config récursivement
      "Z ${repoPath} 0755 ${repoOwner} users - -"

      # Assure que le répertoire .git a les bonnes permissions
      # (Important car Git écrit souvent dans .git/FETCH_HEAD, index, etc.)
      "Z ${repoPath}/.git 0755 ${repoOwner} users - -"
    ];
  };
}

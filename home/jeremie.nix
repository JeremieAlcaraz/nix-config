{ config, pkgs, lib, osConfig, ... }:

{
  imports = [
    ../modules/home-manager/aliases.nix
    ../modules/home-manager/fish-functions.nix
  ];

  # Version de Home Manager (doit correspondre à la version NixOS)
  home.stateVersion = "24.11";

  # Activer la commande home-manager
  programs.home-manager.enable = true;

  # Programmes communs aux deux hosts
  home.packages = with pkgs; [
    htop
    direnv
    tree
    any-nix-shell
  ];

  # Vim - Éditeur de texte
  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  # Starship - Prompt shell moderne (commun aux deux hosts)
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
    };
  };

  # ZSH - Shell pour tous les hosts
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initExtra = ''
      if [[ -o interactive ]]; then
        ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
      fi

      echo ""
      ${if osConfig.networking.hostName == "magnolia" then ''
        echo "🌸 Magnolia - Infrastructure Proxmox"
      '' else if osConfig.networking.hostName == "whitelily" then ''
        echo "🤍 Whitelily - n8n Automation"
      '' else if osConfig.networking.hostName == "mimosa" then ''
        echo "🌼 Mimosa - Serveur web"
      '' else if osConfig.networking.hostName == "dandelion" then ''
        echo "🌾 Dandelion - Serveur Git Gitea"
      '' else ""}
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    '';
  };

  # Fish - Shell pour toutes les VMs
  programs.fish = {
    enable = true;
    shellInit = ''
      if status is-interactive
        ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

        # Changer automatiquement vers /etc/nixos
        cd /etc/nixos 2>/dev/null; or cd ~

        echo ""
        ${if osConfig.networking.hostName == "magnolia" then ''
          echo "🌸 Magnolia - Infrastructure Proxmox"
        '' else if osConfig.networking.hostName == "whitelily" then ''
          echo "🤍 Whitelily - n8n Automation"
        '' else if osConfig.networking.hostName == "mimosa" then ''
          echo "🌼 Mimosa - Serveur web"
        '' else if osConfig.networking.hostName == "dandelion" then ''
          echo "🌾 Dandelion - Serveur Git Gitea"
        '' else ""}
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
      end
    '';
  };

  # Git - Configuration globale
  programs.git = {
    enable = true;
    userName = "JeremieAlcaraz";
    userEmail = "hello@jeremiealcaraz.com";
    extraConfig = {
      safe.directory = "/etc/nixos";
    } // (if osConfig.networking.hostName == "magnolia" then {
      # Réécrire automatiquement les URLs HTTPS en SSH pour GitHub (magnolia uniquement)
      url."git@github.com:".insteadOf = [
        "https://github.com/"
        "http://local_proxy@127.0.0.1:16900/git/"
      ];
    } else {});
  };

  # Génération automatique d'une clé SSH pour whitelily
  # Permet à whitelily de se connecter à d'autres machines (comme le Mac) sans mot de passe
  home.activation.generateSshKey = lib.mkIf (osConfig.networking.hostName == "whitelily") (
    config.lib.dag.entryAfter ["writeBoundary"] ''
      SSH_DIR="$HOME/.ssh"
      SSH_KEY="$SSH_DIR/id_ed25519"

      # Créer le répertoire .ssh s'il n'existe pas
      if [ ! -d "$SSH_DIR" ]; then
        $DRY_RUN_CMD mkdir -p "$SSH_DIR"
        $DRY_RUN_CMD chmod 700 "$SSH_DIR"
      fi

      # Générer la clé SSH si elle n'existe pas déjà
      if [ ! -f "$SSH_KEY" ]; then
        echo "Génération de la clé SSH pour whitelily..."
        $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "whitelily@nixos"
        $DRY_RUN_CMD chmod 600 "$SSH_KEY"
        $DRY_RUN_CMD chmod 644 "$SSH_KEY.pub"
        echo "✅ Clé SSH générée : $SSH_KEY.pub"
        echo ""
        echo "🔑 Copie cette clé publique et ajoute-la à ~/.ssh/authorized_keys sur ton Mac :"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        cat "$SSH_KEY.pub"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      fi
    ''
  );
}

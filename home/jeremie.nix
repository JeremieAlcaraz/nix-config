{ config, pkgs, osConfig, ... }:

{
  imports = [
    ../modules/aliases.nix
    ../modules/fish-functions.nix
  ];

  # Version de Home Manager (doit correspondre à la version NixOS)
  home.stateVersion = "24.11";

  # Activer la commande home-manager
  programs.home-manager.enable = true;

  # Programmes communs aux deux hosts
  home.packages = with pkgs; [
    htop
    tree
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

  # ZSH - Shell pour magnolia et whitelily (COMMENTÉ - remplacé par Fish)
  # programs.zsh = {
  #   enable = (osConfig.networking.hostName == "magnolia" || osConfig.networking.hostName == "whitelily");
  #   enableCompletion = true;
  #   autosuggestion.enable = true;
  #   syntaxHighlighting.enable = true;
  #   initExtra = ''
  #     echo ""
  #     ${if osConfig.networking.hostName == "magnolia" then ''
  #       echo "🌸 Magnolia - Infrastructure Proxmox"
  #     '' else if osConfig.networking.hostName == "whitelily" then ''
  #       echo "🤍 Whitelily - n8n Automation"
  #     '' else ""}
  #     echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  #     echo ""
  #   '';
  # };

  # Fish - Shell pour toutes les VMs
  programs.fish = {
    enable = true;
    shellInit = ''
      if status is-interactive
        # Changer automatiquement vers /etc/nixos
        cd /etc/nixos 2>/dev/null; or cd ~

        echo ""
        ${if osConfig.networking.hostName == "magnolia" then ''
          echo "🌸 Magnolia - Infrastructure Proxmox"
        '' else if osConfig.networking.hostName == "whitelily" then ''
          echo "🤍 Whitelily - n8n Automation"
        '' else if osConfig.networking.hostName == "mimosa" then ''
          echo "🌼 Mimosa - Serveur web"
        '' else if osConfig.networking.hostName == "minimal" then ''
          echo "🔧 Minimal - VM de démonstration minimale"
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
}

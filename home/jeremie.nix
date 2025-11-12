{ config, pkgs, osConfig, ... }:

{
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

  # ZSH - Shell pour magnolia et whitelily
  programs.zsh = {
    enable = (osConfig.networking.hostName == "magnolia" || osConfig.networking.hostName == "whitelily");
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initExtra = ''
      echo ""
      ${if osConfig.networking.hostName == "magnolia" then ''
        echo "🌸 Magnolia - Infrastructure Proxmox"
      '' else if osConfig.networking.hostName == "whitelily" then ''
        echo "🤍 Whitelily - n8n Automation"
      '' else ""}
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    '';
  };

  # Fish - Shell pour mimosa
  programs.fish = {
    enable = osConfig.networking.hostName == "mimosa";
    shellInit = ''
      echo ""
      echo "🌼 Mimosa - Serveur web"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
    '';
  };

  # Git - Configuration pour mimosa uniquement
  programs.git = {
    enable = osConfig.networking.hostName == "mimosa";
    userName = "JeremieAlcaraz";
    userEmail = "hello@jeremiealcaraz.com";
  };
}

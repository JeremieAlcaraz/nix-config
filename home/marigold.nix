{ config, pkgs, ... }:

{
  home.stateVersion = "23.11";
  home.username = "jeremiealcaraz";
  home.homeDirectory = "/Users/jeremiealcaraz";

  # === XDG Configuration ===
  xdg.enable = true;

  # === PACKAGES ===
  home.packages = with pkgs; [
    # Test smoke test
    cowsay

    # Shells
    nushell

    # Shell prompt
    starship

    # Shell tools (zoxide, atuin, carapace for completions)
    zoxide
    atuin
    carapace

    # ZSH plugins et outils (gérés par Nix au lieu de Homebrew/git)
    zsh-fzf-tab
    zsh-autocomplete
    zsh-syntax-highlighting
    zsh-autosuggestions
  ];

  # === ZSH CONFIGURATION ===
  # Solution propre : un seul .zshenv minimal qui définit ZDOTDIR
  # Tout le reste de la config ZSH est dans ~/.config/zsh (XDG-compliant)
  home.file.".zshenv".text = ''
    # Point ZSH to XDG config directory
    export ZDOTDIR="$HOME/.config/zsh"
  '';

  # === DOTFILES ZSH ===
  # Toute la vraie config ZSH est ici (XDG-compliant)
  xdg.configFile = {
    # Fichier de test (smoke test)
    "nix-test.txt".text = ''
      Test de Home Manager pour Marigold.
      Date : 22 décembre 2025
      Statut : En cours de déploiement.
    '';

    # Configuration ZSH principale
    "zsh/.zshenv".source = ../modules/dotfiles/zsh/.zshenv.marigold;
    "zsh/.zshrc".source = ../modules/dotfiles/zsh/.zshrc.marigold;

    # Modules ZSH (tous sauf 06-tools.zsh qu'on remplace par la version marigold)
    "zsh/modules/01-options.zsh".source = ../modules/dotfiles/zsh/modules/01-options.zsh;
    "zsh/modules/02-prompt.zsh".source = ../modules/dotfiles/zsh/modules/02-prompt.zsh;
    "zsh/modules/03-history.zsh".source = ../modules/dotfiles/zsh/modules/03-history.zsh;
    "zsh/modules/04-completion.zsh".source = ../modules/dotfiles/zsh/modules/04-completion.zsh;
    "zsh/modules/05-aliases.zsh".source = ../modules/dotfiles/zsh/modules/05-aliases.zsh;
    "zsh/modules/06-tools.zsh".source = ../modules/dotfiles/zsh/modules/06-tools.marigold.zsh;
    "zsh/modules/07-fzf.zsh".source = ../modules/dotfiles/zsh/modules/07-fzf.zsh;
    "zsh/modules/99-syntax-highlighting.zsh".source = ../modules/dotfiles/zsh/modules/99-syntax-highlighting.marigold.zsh;

    # Fonctions ZSH
    "zsh/functions/dotfiles-switcher.zsh".source = ../modules/dotfiles/zsh/functions/dotfiles-switcher.zsh;
    "zsh/functions/file-management.zsh".source = ../modules/dotfiles/zsh/functions/file-management.zsh;
    "zsh/functions/fzf-helpers.zsh".source = ../modules/dotfiles/zsh/functions/fzf-helpers.zsh;
    "zsh/functions/navi-widget.zsh".source = ../modules/dotfiles/zsh/functions/navi-widget.zsh;
    "zsh/functions/shell-switch.zsh".source = ../modules/dotfiles/zsh/functions/shell-switch.zsh;
    "zsh/functions/show-tree.zsh".source = ../modules/dotfiles/zsh/functions/show-tree.zsh;
    "zsh/functions/ssh.zsh".source = ../modules/dotfiles/zsh/functions/ssh.zsh;

    # Scripts personnels
    "zsh/scripts".source = ../modules/dotfiles/zsh/scripts;

    # Starship prompt configuration
    "starship.toml".source = ../modules/dotfiles/starship/starship.toml;

    # Nushell configuration (XDG-compliant by default)
    "nushell/env.nu".source = ../modules/dotfiles/nushell/env.marigold.nu;
    "nushell/config.nu".source = ../modules/dotfiles/nushell/config.marigold.nu;
  };
}

{ config, pkgs, try, ... }:

let
  bunInstall = "${config.xdg.dataHome}/bun";
  bunCache = "${config.xdg.cacheHome}/bun";
  pnpmHome = "${config.xdg.dataHome}/pnpm";
  pnpmStore = "${config.xdg.dataHome}/pnpm/store";
in

{
  home.stateVersion = "23.11";
  home.username = "jeremiealcaraz";
  home.homeDirectory = "/Users/jeremiealcaraz";

  # === XDG Configuration ===
  xdg.enable = true;

  # === ENVIRONMENT VARIABLES ===
  # Force XDG compliance for tools that support it via env vars
  home.sessionVariables = {
    CLAUDE_CONFIG_DIR = "${config.home.homeDirectory}/.config/claude";
    CODEX_HOME = "${config.home.homeDirectory}/.config/codex";
    GLOW_CONFIG_PATH = "${config.xdg.configHome}/glow/glow.yml";
    RIPGREP_CONFIG_PATH = "${config.home.homeDirectory}/.config/ripgrep/config";
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/nixos-shared-key.txt";
    BUN_INSTALL = bunInstall;
    BUN_INSTALL_CACHE_DIR = bunCache;
    PNPM_HOME = pnpmHome;
    PNPM_STORE_DIR = pnpmStore;
  };

  home.sessionPath = [
    "${bunInstall}/bin"
    pnpmHome
  ];

  # === PACKAGES ===
  home.packages = with pkgs; [
    # Test smoke test
    cowsay

    # Shells
    nushell

    # Shell prompt
    starship

    # Terminal emulator
    wezterm

    # GitHub CLI
    gh

    # Editor (LazyVim nécessite une version récente)
    unstable.neovim

    # Shell tools (zoxide, atuin, carapace for completions)
    zoxide
    atuin
    carapace
    direnv
    glow
    navi
    ripgrep
    sops
    pnpm

    # Node.js (Copilot.lua requires >= 22)
    unstable.nodejs_22

    # Modern ls replacement
    eza

    # Tree view
    tree

    # 1Password CLI (op)
    _1password-cli

    # Bun
    bun

    # AI coding assistants (depuis nixpkgs-unstable)
    unstable.claude-code
    unstable.codex

    # Try - Fresh directories for every vibe
    try.packages.${pkgs.system}.default

    # ZSH plugins et outils (gérés par Nix au lieu de Homebrew/git)
    zsh-fzf-tab
    zsh-autocomplete
    zsh-syntax-highlighting
    zsh-autosuggestions
  ];

  # === ZSH CONFIGURATION ===
  # Solution propre : un seul .zshenv minimal qui définit ZDOTDIR
  # Tout le reste de la config ZSH est dans ~/.config/zsh (XDG-compliant)
  home.file = {
    ".zshenv".text = ''
      # Point ZSH to XDG config directory
      export ZDOTDIR="$HOME/.config/zsh"

      # Load the real .zshenv from ZDOTDIR (zsh does not re-read it automatically)
      if [[ -r "$ZDOTDIR/.zshenv" ]]; then
        source "$ZDOTDIR/.zshenv"
      fi
    '';

    # SSH configuration
    ".ssh/config".source = ../modules/dotfiles/ssh/config;
    ".ssh/authorized_keys".source = ../modules/dotfiles/ssh/public/authorized_keys;
    ".ssh/public".source = ../modules/dotfiles/ssh/public;
  };

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

    # Plugins ZSH
    "zsh/plugins".source = ../modules/dotfiles/zsh/plugins;

    # Starship prompt configuration
    "starship.toml".source = ../modules/dotfiles/starship/starship.toml;

    # WezTerm terminal configuration
    "wezterm".source = ../modules/dotfiles/wezterm;

    # GitHub CLI configuration
    "gh".source = ../modules/dotfiles/gh;

    # Glow configuration (XDG)
    "glow/glow.yml" = {
      source = ../modules/dotfiles/glow/glow.yml;
      force = true;
    };

    # Neovim configuration
    "nvim".source = ../modules/dotfiles/nvim;

    # Hammerspoon configuration (XDG)
    "hammerspoon".source = ../modules/dotfiles/hammerspoon;

    # Nushell configuration (XDG-compliant by default)
    "nushell/env.nu".source = ../modules/dotfiles/nushell/env.marigold.nu;
    "nushell/config.nu".source = ../modules/dotfiles/nushell/config.marigold.nu;

    # Navi cheatsheets and configuration
    "navi/config.yaml".source = ../modules/dotfiles/navi/config.yaml;
    "navi/config.toml".source = ../modules/dotfiles/navi/config.toml;
    "navi/cheats".source = ../modules/dotfiles/navi/cheats;

    # Claude Code configuration (XDG-compliant via CLAUDE_CONFIG_DIR)
    "claude/settings.json".source = ../modules/dotfiles/claude/settings.json;

    # Codex configuration (XDG-compliant via CODEX_HOME)
    "codex/config.toml" = {
      source = ../modules/dotfiles/codex/config.toml;
      force = true;
    };

    # Ripgrep configuration
    "ripgrep".source = ../modules/dotfiles/ripgrep;
  };

  # === SOPS (secrets) ===
  sops = {
    defaultSopsFile = ../secrets/marigold.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/nixos-shared-key.txt";
    secrets = {
      ssh_id_ed25519 = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
        mode = "0600";
      };
      ssh_id_rsa = {
        path = "${config.home.homeDirectory}/.ssh/id_rsa";
        mode = "0600";
      };
    };
  };
}

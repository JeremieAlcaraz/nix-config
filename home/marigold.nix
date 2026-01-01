{ config, lib, pkgs, try, ... }:

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

  imports = [
    ./aerospace.nix
    ./sketchybar.nix
    ./wezterm.nix
    ./yazi.nix
  ];

  # === GIT CONFIGURATION ===
  programs.git = {
    enable = true;
    userName = "Jérémie Alcaraz";
    userEmail = "jeremie.alcaraz@gmail.com";

    extraConfig = {
      init = {
        defaultBranch = "main";
        templateDir = "~/.config/git/templates";
      };
      core = {
        excludesfile = "~/.config/git/ignore";
        editor = "nvim";
        pager = "less -FRX";
        quotepath = false;
      };
      pull.rebase = false;
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      fetch.prune = true;
      rebase.autoStash = true;
      merge.conflictStyle = "zdiff3";
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };
      log.date = "iso";
      color.ui = "auto";
      help.autocorrect = 1;
      credential.helper = "osxkeychain";
    };

    aliases = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      ignored = "ls-files --others --ignored --exclude-standard";
      undo = "reset HEAD~1 --mixed";
      amend = "commit --amend --no-edit";
      current = "rev-parse --abbrev-ref HEAD";
      cleanup = "!git branch --merged | grep -v '\\*\\|main\\|master\\|develop' | xargs -n 1 git branch -d";
    };

    ignores = [
      "**/.claude/settings.local.json"
    ];
  };

  # === ENVIRONMENT VARIABLES ===
  # Force XDG compliance for tools that support it via env vars
  home.sessionVariables = {
    CLAUDE_CONFIG_DIR = "${config.home.homeDirectory}/.config/claude";
    CODEX_HOME = "${config.home.homeDirectory}/.config/codex";
    GLOW_CONFIG_PATH = "${config.xdg.configHome}/glow/glow.yml";
    RIPGREP_CONFIG_PATH = "${config.home.homeDirectory}/.config/ripgrep/config";
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/key.txt";
    BUN_INSTALL = bunInstall;
    BUN_INSTALL_CACHE_DIR = bunCache;
    PNPM_HOME = pnpmHome;
    PNPM_STORE_DIR = pnpmStore;
  };

  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
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

    # Version control
    git
    gh # GitHub CLI

    # Editor (LazyVim nécessite une version récente)
    unstable.neovim

    # Shell tools (zoxide, atuin, carapace for completions)
    zoxide
    atuin
    carapace
    fd
    unstable.tabiew
    unstable.television
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
    broot

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

    # TPM (Tmux Plugin Manager) - installation déclarative (XDG-compliant)
    ".config/tmux/plugins/tpm" = {
      source = pkgs.fetchFromGitHub {
        owner = "tmux-plugins";
        repo = "tpm";
        rev = "v3.1.0";
        sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
      };
      recursive = true;
    };
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

    # GitHub CLI configuration
    "gh".source = ../modules/dotfiles/gh;

    # Git ignore global (XDG)
    "git/ignore".source = ../modules/dotfiles/git/ignore;

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
    "nushell/broot.nu".source = ../modules/dotfiles/nushell/broot.marigold.nu;

    # Fish configuration
    "fish/conf.d/broot.fish".source = ../modules/dotfiles/fish/conf.d/broot.marigold.fish;

    # Navi cheatsheets and configuration
    "navi/config.yaml".source = ../modules/dotfiles/navi/config.yaml;
    "navi/config.toml".source = ../modules/dotfiles/navi/config.toml;
    "navi/cheats".source = ../modules/dotfiles/navi/cheats;

    # Broot configuration
    "broot/conf.hjson".source = ../modules/dotfiles/broot/conf.hjson;
    "broot/verbs.hjson".source = ../modules/dotfiles/broot/verbs.hjson;

    # Claude Code configuration (XDG-compliant via CLAUDE_CONFIG_DIR)
    "claude/settings.json".source = ../modules/dotfiles/claude/settings.json;

    # Codex configuration (XDG-compliant via CODEX_HOME)
    "codex/config.toml" = {
      source = ../modules/dotfiles/codex/config.toml;
      force = true;
    };

    # Ripgrep configuration
    "ripgrep".source = ../modules/dotfiles/ripgrep;

    # fd ignore file (XDG)
    "fd/ignore".source = ../modules/dotfiles/fd/ignore;

    # Git templates (hooks) - la config est gérée par programs.git
    "git/templates/hooks/pre-commit" = {
      source = ../modules/dotfiles/git/templates/hooks/pre-commit;
      executable = true;
    };
    "git/templates/hooks/commit-msg" = {
      source = ../modules/dotfiles/git/templates/hooks/commit-msg;
      executable = true;
    };
    "git/templates/hooks/prepare-commit-msg" = {
      source = ../modules/dotfiles/git/templates/hooks/prepare-commit-msg;
      executable = true;
    };

    # Television - Fuzzy finder
    "television/config.toml".source = ../modules/dotfiles/television/config.toml;
    "television/cable".source = ../modules/dotfiles/television/cable;
    "television/scripts/recent-files-preview.zsh" = {
      source = ../modules/dotfiles/television/scripts/recent-files-preview.zsh;
      executable = true;
    };
    "television/scripts/recent-files-source.zsh" = {
      source = ../modules/dotfiles/television/scripts/recent-files-source.zsh;
      executable = true;
    };
    "television/shell/integration.zsh".source = ../modules/dotfiles/television/shell/integration.zsh;

    # Tmux configuration
    "tmux/tmux.conf".source = ../modules/dotfiles/tmux/tmux.conf;
    "tmux/tmux.reset.conf".source = ../modules/dotfiles/tmux/tmux.reset.conf;
    "tmux/scripts/cal.sh" = {
      source = ../modules/dotfiles/tmux/scripts/cal.sh;
      executable = true;
    };
  };

  # === SOPS (secrets) ===
  sops = {
    defaultSopsFile = ../secrets/marigold.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/key.txt";
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

  home.activation.bootstrapSopsAgeKey = config.lib.dag.entryAfter ["writeBoundary"] ''
    KEY_PATH="${config.home.homeDirectory}/.config/sops/age/key.txt"
    OP_ITEM="op://Personal/sops-age-key/notesPlain"
    OP_BIN="${pkgs._1password-cli}/bin/op"

    if [ ! -f "$KEY_PATH" ]; then
      if [ -n "$DRY_RUN_CMD" ]; then
        echo "DRY RUN: would fetch SOPS age key from 1Password ($OP_ITEM)"
      else
        if [ ! -x "$OP_BIN" ]; then
          echo "Erreur: 1Password CLI (op) introuvable. Installe-le avant le rebuild."
          exit 1
        fi

        mkdir -p "$(dirname "$KEY_PATH")"

        if ! "$OP_BIN" read "$OP_ITEM" > "$KEY_PATH"; then
          echo "Erreur: impossible de lire la clé depuis 1Password. Vault déverrouillé ?"
          rm -f "$KEY_PATH"
          exit 1
        fi

        chmod 600 "$KEY_PATH"

        if ! grep -q "AGE-SECRET-KEY-1" "$KEY_PATH"; then
          echo "Erreur: contenu de clé age invalide dans 1Password."
          rm -f "$KEY_PATH"
          exit 1
        fi
      fi
    fi
  '';

  programs.yazi.yaziPlugins.runtimeDeps = lib.mkAfter [
    pkgs.unstable.tabiew
  ];

  programs.yazi.settings = {
    opener.csv = [
      { run = "${pkgs.unstable.tabiew}/bin/tw \"$@\""; block = true; desc = "Tabiew"; }
    ];
    open.prepend_rules = [
      { name = "*.csv"; use = [ "csv" ]; }
    ];
  };
}

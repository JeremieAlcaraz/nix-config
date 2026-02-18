{ config, lib, pkgs, try, ... }:

let
  bunInstall = "${config.xdg.dataHome}/bun";
  bunCache = "${config.xdg.cacheHome}/bun";
  pnpmHome = "${config.xdg.dataHome}/pnpm";
  pnpmStore = "${config.xdg.dataHome}/pnpm/store";
  repoRoot = "${config.home.homeDirectory}/Development/_programmation/_production/_services/nix-config";
  repoKarabinerDir = "${repoRoot}/modules/dotfiles/karabiner/.config/karabiner";
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
    "${config.home.homeDirectory}/.local/bin"  # Wrappers custom (claude, etc.)
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/opt/zerobrew/prefix/bin"  # Zerobrew packages
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
    direnv
    glow
    navi
    ripgrep
    # Node global pour outils non-interactifs (agents AI, scripts CI, etc.).
    # fnm reste actif en shell interactif pour gérer les versions par projet.
    nodejs_22
    fnm
    terminal-notifier
    sops

    # pnpm: géré via wrapper (voir .local/bin/pnpm) pour permettre l'auto-install

    # Modern ls replacement
    eza

    # Tree view
    tree
    broot

    # 1Password CLI (op)
    _1password-cli

    # Bun: géré via wrapper (voir .local/bin/bun) pour permettre bun upgrade

    # Try - Fresh directories for every vibe
    try.packages.${pkgs.system}.default

    # ZSH plugins et outils (gérés par Nix au lieu de Homebrew/git)
    zsh-fzf-tab
    zsh-autocomplete
    zsh-syntax-highlighting
    zsh-autosuggestions

    # any-nix-shell
    any-nix-shell
  ];

  # === ZSH CONFIGURATION ===
  programs.zsh = {
    enable = true;
    initExtra = ''
      if [[ -o interactive ]]; then
        ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
      fi
    '';
  };

  # === FISH CONFIGURATION ===
  programs.fish = {
    enable = true;
    shellInit = ''
      if status is-interactive
        ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source
      end
    '';
  };

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

    # Fix PATH after macOS path_helper (loaded in /etc/zprofile)
    ".zprofile".text = ''
      # Restore paths that might be reordered/removed by /etc/zprofile's path_helper
      [[ -d "/opt/zerobrew/prefix/bin" ]] && export PATH="/opt/zerobrew/prefix/bin:$PATH"
      [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
    '';

    # SSH configuration
    ".ssh/config".source = ../modules/dotfiles/ssh/config;
    ".ssh/authorized_keys".source = ../modules/dotfiles/ssh/public/authorized_keys;
    ".ssh/public".source = ../modules/dotfiles/ssh/public;

    # terminal-notifier.app registered in ~/Applications for macOS notifications.
    "Applications/terminal-notifier.app".source = "${pkgs.terminal-notifier}/Applications/terminal-notifier.app";

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

    # Claude Code wrapper - utilise le binaire Homebrew (toujours à jour)
    ".local/bin/claude" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        HOMEBREW_CLAUDE="/opt/homebrew/bin/claude"

        if [[ -x "$HOMEBREW_CLAUDE" ]]; then
          exec "$HOMEBREW_CLAUDE" "$@"
        fi

        echo "❌ Claude Code n'est pas installé via Homebrew."
        echo ""
        echo "Installe-le avec:"
        echo "  brew install --cask claude-code"
        echo ""
        echo "Puis redémarre ton shell."
        exit 1
      '';
      executable = true;
    };

    # Bun wrapper - installation manuelle pour permettre bun upgrade
    ".local/bin/bun" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        BUN_BIN="${bunInstall}/bin/bun"

        if [[ -x "$BUN_BIN" ]]; then
          exec "$BUN_BIN" "$@"
        fi

        echo "⚡ Bun n'est pas installé. Installation en cours..."
        echo ""
        curl -fsSL https://bun.sh/install | bash
        echo ""
        echo "✅ Bun installé ! Relance ta commande."
        exit 0
      '';
      executable = true;
    };

    # pnpm wrapper - installation lazy à la première utilisation
    ".local/bin/pnpm" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        PNPM_BIN="${pnpmHome}/pnpm"

        if [[ -x "$PNPM_BIN" ]]; then
          exec "$PNPM_BIN" "$@"
        fi

        echo "📦 pnpm n'est pas installé. Installation en cours..."
        echo ""
        export PNPM_HOME="${pnpmHome}"
        curl -fsSL https://get.pnpm.io/install.sh | sh
        echo ""
        echo "✅ pnpm installé ! Relance ta commande."
        exit 0
      '';
      executable = true;
    };

    # Television wrapper - utilise Homebrew pour permettre update à la demande
    ".local/bin/tv" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        HOMEBREW_TV="/opt/homebrew/bin/tv"

        if [[ -x "$HOMEBREW_TV" ]]; then
          exec "$HOMEBREW_TV" "$@"
        fi

        echo "📺 Television n'est pas installé. Installation en cours..."
        echo ""
        brew install television
        echo ""
        echo "✅ Television installé."
        exec "$HOMEBREW_TV" "$@"
      '';
      executable = true;
    };

    # Zerobrew wrapper - installation lazy à la première utilisation
    ".local/bin/zerobrew" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        ZB_BIN="$HOME/.local/bin/zb"

        if [[ -x "$ZB_BIN" ]]; then
          exec "$ZB_BIN" "$@"
        fi

        echo "🍺 Zerobrew n'est pas installé. Installation en cours..."
        echo ""
        curl -sSL https://raw.githubusercontent.com/lucasgelfond/zerobrew/main/install.sh | bash
        echo ""
        echo "✅ Zerobrew installé dans $ZB_BIN"
        echo "   Relance ta commande."
        exit 0
      '';
      executable = true;
    };

    # AeroSpace wrapper - installe le cask si absent et tente de lancer l'app
    ".local/bin/aerospace" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        AEROSPACE_BIN="/opt/homebrew/bin/aerospace"
        AEROSPACE_APP="/Applications/AeroSpace.app"

        if [[ ! -x "$AEROSPACE_BIN" ]]; then
          echo "🪟 AeroSpace n'est pas installé. Installation en cours..."
          echo ""
          brew install --cask aerospace
          echo ""
          echo "✅ AeroSpace installé."
        fi

        if [[ -d "$AEROSPACE_APP" ]]; then
          if ! pgrep -x "AeroSpace" >/dev/null 2>&1; then
            open "$AEROSPACE_APP" >/dev/null 2>&1 || true
            for _ in {1..10}; do
              pgrep -x "AeroSpace" >/dev/null 2>&1 && break
              sleep 0.3
            done
          fi
        fi

        exec "$AEROSPACE_BIN" "$@"
      '';
      executable = true;
    };

    # macOS appearance helper - dark/light/auto/toggle/cycle
    ".local/bin/macos-appearance" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        mode=''${1:-toggle}

        is_dark() {
          defaults read -g AppleInterfaceStyle >/dev/null 2>&1
        }

        current_mode() {
          if [[ "$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || echo 0)" == "1" ]]; then
            echo "auto"
            return
          fi

          if is_dark; then
            echo "dark"
          else
            echo "light"
          fi
        }

        disable_auto() {
          defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false
        }

        set_dark() {
          disable_auto
          osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null
        }

        set_light() {
          disable_auto
          osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' >/dev/null
        }

        set_auto() {
          defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true
        }

        case "$mode" in
          dark)
            set_dark
            ;;
          light)
            set_light
            ;;
          auto)
            set_auto
            ;;
          cycle)
            case "$(current_mode)" in
              auto)
                set_dark
                ;;
              dark)
                set_light
                ;;
              light)
                set_auto
                ;;
            esac
            ;;
          toggle)
            if is_dark; then
              set_light
            else
              set_dark
            fi
            ;;
          status)
            current_mode
            exit 0
            ;;
          *)
            echo "Usage: macos-appearance [toggle|cycle|dark|light|auto|status]" >&2
            exit 2
            ;;
        esac

        current_mode
      '';
      executable = true;
    };

    ".local/bin/karabiner-push" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        RUNTIME_JSON="${config.home.homeDirectory}/.config/karabiner/karabiner.json"
        REPO_JSON="${repoKarabinerDir}/karabiner.json"
        STAMP="$(date +%Y%m%d-%H%M%S)"

        if [[ ! -f "$RUNTIME_JSON" ]]; then
          echo "Erreur: fichier runtime introuvable: $RUNTIME_JSON" >&2
          exit 1
        fi

        mkdir -p "$(dirname "$REPO_JSON")"

        BACKUP_PATH=""
        if [[ -f "$REPO_JSON" ]]; then
          BACKUP_PATH="$REPO_JSON.bak.$STAMP"
          cp "$REPO_JSON" "$BACKUP_PATH"
        fi

        cp "$RUNTIME_JSON" "$REPO_JSON"

        if command -v jq >/dev/null 2>&1; then
          jq empty "$REPO_JSON" >/dev/null
        fi

        echo "✅ karabiner.json poussé vers le repo."
        echo "   Source: $RUNTIME_JSON"
        echo "   Cible : $REPO_JSON"
        if [[ -n "$BACKUP_PATH" ]]; then
          echo "   Backup: $BACKUP_PATH"
        fi
      '';
      executable = true;
    };

    ".local/bin/karabiner-pull" = {
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        RUNTIME_DIR="${config.home.homeDirectory}/.config/karabiner"
        RUNTIME_JSON="$RUNTIME_DIR/karabiner.json"
        REPO_DIR="${repoKarabinerDir}"
        REPO_JSON="$REPO_DIR/karabiner.json"
        RUNTIME_ASSETS_DIR="$RUNTIME_DIR/assets"
        RUNTIME_ASSETS_LINK="$RUNTIME_ASSETS_DIR/complex_modifications"
        REPO_ASSETS_LINK="$REPO_DIR/assets/complex_modifications"
        STAMP="$(date +%Y%m%d-%H%M%S)"

        if [[ ! -f "$REPO_JSON" ]]; then
          echo "Erreur: fichier repo introuvable: $REPO_JSON" >&2
          exit 1
        fi

        if [[ -L "$RUNTIME_DIR" ]]; then
          rm -f "$RUNTIME_DIR"
        elif [[ -e "$RUNTIME_DIR" && ! -d "$RUNTIME_DIR" ]]; then
          rm -f "$RUNTIME_DIR"
        fi

        mkdir -p "$RUNTIME_ASSETS_DIR"

        if [[ -L "$RUNTIME_ASSETS_LINK" ]]; then
          ln -sfn "$REPO_ASSETS_LINK" "$RUNTIME_ASSETS_LINK"
        elif [[ -e "$RUNTIME_ASSETS_LINK" ]]; then
          echo "Info: assets/complex_modifications existe deja en local, lien repo non force."
        else
          ln -s "$REPO_ASSETS_LINK" "$RUNTIME_ASSETS_LINK"
        fi

        BACKUP_PATH=""
        if [[ -f "$RUNTIME_JSON" ]]; then
          BACKUP_PATH="$RUNTIME_JSON.bak.$STAMP"
          cp "$RUNTIME_JSON" "$BACKUP_PATH"
        fi

        cp "$REPO_JSON" "$RUNTIME_JSON"
        chmod 600 "$RUNTIME_JSON" || true

        echo "✅ karabiner.json appliqué depuis le repo."
        echo "   Source: $REPO_JSON"
        echo "   Cible : $RUNTIME_JSON"
        if [[ -n "$BACKUP_PATH" ]]; then
          echo "   Backup: $BACKUP_PATH"
        fi
      '';
      executable = true;
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
    "zsh/.zprofile".text = ''
      # Fix PATH after macOS /etc/zprofile's path_helper
      [[ -d "/opt/zerobrew/prefix/bin" ]] && export PATH="/opt/zerobrew/prefix/bin:$PATH"
      [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
    '';
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
    "zsh/functions/media-download.zsh".source = ../modules/dotfiles/zsh/functions/media-download.zsh;
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

    # Bat themes (Tokyo Night)
    "bat/themes".source = ../modules/dotfiles/bat/themes;

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

    # Television - config hors store (editable directement dans le repo)
    "television".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Development/_programmation/_production/_services/nix-config/modules/dotfiles/television";

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

  home.activation.bootstrapKarabinerRuntime = config.lib.dag.entryAfter ["writeBoundary"] ''
    REPO_KARABINER_DIR="${repoKarabinerDir}"
    RUNTIME_KARABINER_DIR="${config.home.homeDirectory}/.config/karabiner"
    RUNTIME_JSON="$RUNTIME_KARABINER_DIR/karabiner.json"
    RUNTIME_ASSETS_DIR="$RUNTIME_KARABINER_DIR/assets"
    RUNTIME_ASSETS_LINK="$RUNTIME_ASSETS_DIR/complex_modifications"
    REPO_ASSETS_LINK="$REPO_KARABINER_DIR/assets/complex_modifications"

    if [ -L "$RUNTIME_KARABINER_DIR" ]; then
      rm -f "$RUNTIME_KARABINER_DIR"
      mkdir -p "$RUNTIME_KARABINER_DIR"
      echo "Karabiner: symlink global remplace par un dossier local writable."
    elif [ -e "$RUNTIME_KARABINER_DIR" ] && [ ! -d "$RUNTIME_KARABINER_DIR" ]; then
      rm -f "$RUNTIME_KARABINER_DIR"
      mkdir -p "$RUNTIME_KARABINER_DIR"
    else
      mkdir -p "$RUNTIME_KARABINER_DIR"
    fi

    mkdir -p "$RUNTIME_ASSETS_DIR"
    if [ -L "$RUNTIME_ASSETS_LINK" ]; then
      ln -sfn "$REPO_ASSETS_LINK" "$RUNTIME_ASSETS_LINK"
    elif [ -e "$RUNTIME_ASSETS_LINK" ]; then
      echo "Karabiner: assets/complex_modifications local detecte, lien repo non force."
    else
      ln -s "$REPO_ASSETS_LINK" "$RUNTIME_ASSETS_LINK"
    fi

    if [ ! -f "$RUNTIME_JSON" ]; then
      cp "$REPO_KARABINER_DIR/karabiner.json" "$RUNTIME_JSON"
      chmod 600 "$RUNTIME_JSON" || true
      echo "Karabiner: bootstrap karabiner.json depuis le repo."
    fi
  '';

  home.activation.preflightFixBrokenConfigLinks = config.lib.dag.entryBefore ["checkLinkTargets"] ''
    move_broken_link() {
      local path="$1"
      if [ -L "$path" ] && [ ! -e "$path" ]; then
        local stamp backup_path
        stamp="$(date +%Y%m%d-%H%M%S)"
        backup_path="$path.broken-link.$stamp"
        mv "$path" "$backup_path"
        echo "Home Manager preflight: lien cassé déplacé -> $backup_path"
      fi
    }

    move_broken_link "${config.xdg.configHome}/fish"
    move_broken_link "${config.xdg.configHome}/hammerspoon"
    move_broken_link "${config.xdg.configHome}/karabiner"
    move_broken_link "${config.home.homeDirectory}/.hammerspoon"
  '';

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

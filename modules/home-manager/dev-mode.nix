{ config, lib, ... }:

let
  cfg = config.jeremie.dotfiles;
  repoRootDefault = "${config.home.homeDirectory}/c/nix-config/main";
  worktreeRootDefault = "${config.home.homeDirectory}/c/nix-config/dev";
  dotfilesDevPathDefault = "${worktreeRootDefault}/modules/dotfiles";
in
{
  options.jeremie.dotfiles = {
    devMode = lib.mkEnableOption "dotfiles dev mode (live edit via worktree)";

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = repoRootDefault;
      description = "Chemin absolu vers le repo principal (branche stable).";
    };

    worktreeRoot = lib.mkOption {
      type = lib.types.str;
      default = worktreeRootDefault;
      description = "Chemin absolu vers le worktree de dev (branche playground).";
    };

    repoPath = lib.mkOption {
      type = lib.types.path;
      default = ../dotfiles;
      description = "Chemin Nix vers les dotfiles (store-based en prod).";
    };

    devPath = lib.mkOption {
      type = lib.types.str;
      default = dotfilesDevPathDefault;
      description = "Chemin absolu vers les dotfiles du worktree (dev).";
    };

    source = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Fonction helper pour choisir store-based ou out-of-store.";
    };
    path = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Fonction helper pour obtenir un chemin (store ou worktree).";
    };
    mkScript = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = ''
        Helper pour les scripts exécutables.
        En devMode, mkOutOfStoreSymlink est incompatible avec executable = true
        (le sandbox Nix ne peut pas accéder au fichier hors-store pendant le build).
        Ce helper retourne { source; } sans executable en devMode,
        et { source; executable = true; } en non-devMode.
        Un home.activation remet le bit +x sur les symlinks en devMode.
      '';
    };
  };

  # Expose repo paths as env vars — source unique de vérité pour tous les scripts
  config.home.sessionVariables = {
    NIX_CONFIG_MAIN = cfg.repoRoot;
    NIX_CONFIG_DEV  = cfg.worktreeRoot;
  };

  config.jeremie.dotfiles.source = relPath:
    if cfg.devMode
    then config.lib.file.mkOutOfStoreSymlink "${cfg.devPath}/${relPath}"
    else cfg.repoPath + "/${relPath}";
  config.jeremie.dotfiles.path = relPath:
    if cfg.devMode
    then "${cfg.devPath}/${relPath}"
    else cfg.repoPath + "/${relPath}";
  config.jeremie.dotfiles.mkScript = relPath:
    if cfg.devMode
    then { source = config.lib.file.mkOutOfStoreSymlink "${cfg.devPath}/${relPath}"; }
    else { source = cfg.repoPath + "/${relPath}"; executable = true; };

  # En devMode, remettre le bit exécutable sur les symlinks vers des scripts
  # (impossible via executable = true avec mkOutOfStoreSymlink)
  config.home.activation.devModeScriptsExecutable = lib.mkIf cfg.devMode (
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      find "$HOME/.config" -type l -name "*.sh" \
        -exec chmod +x {} \; 2>/dev/null || true
      find "$HOME/.local/share/git-core/templates/hooks" -type l \
        -exec chmod +x {} \; 2>/dev/null || true
    ''
  );
}

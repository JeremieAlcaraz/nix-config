{ config, lib, ... }:

let
  cfg = config.jeremie.dotfiles;
  # Contract:
  # - repoRoot points to nix-config checkout.
  # - dotfiles are resolved from repoPath (store) or externalRoot (out-of-store).
  # - source/path/mkScript must only depend on cfg.mode.
  repoRootDefault = "${config.home.homeDirectory}/c/nix-config/main";
  externalRootDefault = "${config.home.homeDirectory}/c/dotfiles";
  dotfilesRepoPathDefault = ../dotfiles;
in
{
  options.jeremie.dotfiles = {
    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = repoRootDefault;
      description = "Chemin absolu vers le repo principal (branche stable).";
    };

    externalRoot = lib.mkOption {
      type = lib.types.str;
      default = externalRootDefault;
      description = ''
        Chemin absolu vers le repository Git externe des dotfiles.
        Ce root servira de cible principale après migration hors repo Nix.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "repo" "external" ];
      default = "repo";
      description = ''
        Sélecteur du root dotfiles:
        - repo: utilise repoPath (store-based)
        - external: utilise externalRoot (out-of-store)
      '';
    };

    repoPath = lib.mkOption {
      type = lib.types.path;
      default = dotfilesRepoPathDefault;
      description = ''
        Chemin Nix vers l'arbre dotfiles en mode non-dev (store-based).
        Ce chemin est la source de vérité des liens HM quand devMode = false.
      '';
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
        En mode external, mkOutOfStoreSymlink est incompatible avec executable = true
        (le sandbox Nix ne peut pas accéder au fichier hors-store pendant le build).
        Ce helper retourne { source; } sans executable en mode external,
        et { source; executable = true; } en mode repo.
        Un home.activation remet le bit +x sur les symlinks en mode external.
      '';
    };
  };

  # Expose repo paths as env vars — source unique de vérité pour tous les scripts
  config.home.sessionVariables = {
    NIX_CONFIG_MAIN = cfg.repoRoot;
  };

  config.jeremie.dotfiles.source = relPath:
    if cfg.mode == "external"
    then config.lib.file.mkOutOfStoreSymlink "${cfg.externalRoot}/${relPath}"
    else cfg.repoPath + "/${relPath}";
  config.jeremie.dotfiles.path = relPath:
    if cfg.mode == "external"
    then "${cfg.externalRoot}/${relPath}"
    else cfg.repoPath + "/${relPath}";
  config.jeremie.dotfiles.mkScript = relPath:
    if cfg.mode == "external"
    then { source = config.lib.file.mkOutOfStoreSymlink "${cfg.externalRoot}/${relPath}"; }
    else { source = cfg.repoPath + "/${relPath}"; executable = true; };

  # En mode external, remettre le bit exécutable sur les symlinks vers des scripts
  # (impossible via executable = true avec mkOutOfStoreSymlink)
  config.home.activation.externalModeScriptsExecutable = lib.mkIf (cfg.mode == "external") (
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      find "$HOME/.config" -type l -name "*.sh" \
        -exec chmod +x {} \; 2>/dev/null || true
      find "$HOME/.local/share/git-core/templates/hooks" -type l \
        -exec chmod +x {} \; 2>/dev/null || true
    ''
  );
}

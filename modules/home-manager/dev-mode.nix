{ config, lib, ... }:

let
  cfg = config.jeremie.dotfiles;
  # Source de vérité unique : ~/c/dotfiles
  # nix-config ne contient plus de copie des dotfiles.
  repoRootDefault = "${config.home.homeDirectory}/c/nix-config";
  externalRootDefault = "${config.home.homeDirectory}/c/dotfiles";
in
{
  options.jeremie.dotfiles = {
    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = repoRootDefault;
      description = "Chemin absolu vers le repo nix-config.";
    };

    externalRoot = lib.mkOption {
      type = lib.types.str;
      default = externalRootDefault;
      description = "Chemin absolu vers le repository Git des dotfiles (source de vérité).";
    };

    source = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Helper : crée un symlink out-of-store vers ~/c/dotfiles.";
    };
    path = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Helper : retourne le chemin absolu dans ~/c/dotfiles.";
    };
    mkScript = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = ''
        Helper pour les scripts exécutables.
        mkOutOfStoreSymlink est incompatible avec executable = true —
        un home.activation remet le bit +x sur les symlinks.
      '';
    };
  };

  # Expose repo paths as env vars
  config.home.sessionVariables = {
    NIX_CONFIG_MAIN = cfg.repoRoot;
    DOTFILES = cfg.externalRoot;
  };

  config.jeremie.dotfiles.source = relPath:
    config.lib.file.mkOutOfStoreSymlink "${cfg.externalRoot}/${relPath}";

  config.jeremie.dotfiles.path = relPath:
    "${cfg.externalRoot}/${relPath}";

  config.jeremie.dotfiles.mkScript = relPath:
    { source = config.lib.file.mkOutOfStoreSymlink "${cfg.externalRoot}/${relPath}"; };

  # Remettre le bit exécutable sur les symlinks vers des scripts
  config.home.activation.externalModeScriptsExecutable =
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      find "$HOME/.config" -type l -name "*.sh" \
        -exec chmod +x {} \; 2>/dev/null || true
      find "$HOME/.local/share/git-core/templates/hooks" -type l \
        -exec chmod +x {} \; 2>/dev/null || true
    '';

  # Optionnel mais utile en mode "dotfiles source of truth":
  # Home Manager garde ses liens via $HOME/.nix-profile/.. -> /nix/store/... par design.
  # Ce hook remplace ces liens par des symlinks directs vers ~/c/dotfiles
  # uniquement quand la cible finale est bien dans le repo de dotfiles.
  config.home.activation.externalModeDirectDotfilesSymlinks =
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      if [ -d "$HOME/.config" ]; then
        find "$HOME/.config" -type l 2>/dev/null | while IFS= read -r link; do
          first_target="$(readlink "$link" 2>/dev/null || true)"
          case "$first_target" in
            /nix/store/*home-manager-files/*)
              second_target="$(readlink "$first_target" 2>/dev/null || true)"
              case "$second_target" in
                "${cfg.externalRoot}"/*)
                  ln -sfn "$second_target" "$link"
                  ;;
              esac
              ;;
          esac
        done
      fi
    '';
}

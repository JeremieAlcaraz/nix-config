{ config, lib, ... }:

let
  cfg = config.jeremie.dotfiles;
  repoRootDefault = "${config.home.homeDirectory}/Development/_programmation/_production/_services/nix-config";
  worktreeRootDefault = "${config.home.homeDirectory}/Development/_programmation/_production/_services/nix-config-playground";
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
  };

  config.jeremie.dotfiles.source = relPath:
    if cfg.devMode
    then config.lib.file.mkOutOfStoreSymlink "${cfg.devPath}/${relPath}"
    else cfg.repoPath + "/${relPath}";
  config.jeremie.dotfiles.path = relPath:
    if cfg.devMode
    then "${cfg.devPath}/${relPath}"
    else cfg.repoPath + "/${relPath}";
}

{ config, lib, pkgs, ... }:
let
  dotfiles = config.jeremie.dotfiles;
  dotfilesSource = dotfiles.source;
in
{
  # Configuration AeroSpace
  xdg.configFile."aerospace/aerospace.toml".source = dotfilesSource "aerospace/aerospace.toml";
  xdg.configFile."aerospace/raycast-ai-overlay.sh" = dotfiles.mkScript "aerospace/raycast-ai-overlay.sh";
  xdg.configFile."aerospace/organize-workspaces.sh" = dotfiles.mkScript "aerospace/organize-workspaces.sh";
  xdg.configFile."aerospace/split-picker.sh" = dotfiles.mkScript "aerospace/split-picker.sh";

  # LaunchAgent pour démarrer AeroSpace automatiquement
  launchd.agents.aerospace = {
    enable = true;
    config = {
      ProgramArguments = [
        "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
        "--config-path"
        "${config.home.homeDirectory}/.config/aerospace/aerospace.toml"
      ];
      Label = "com.nikitabobko.aerospace";
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;  # Redémarre si l'app quitte normalement
        Crashed = true;          # Redémarre si l'app crash
      };
      ProcessType = "Interactive";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/AeroSpace/stderr.log";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/AeroSpace/stdout.log";
    };
  };

  # Crée le dossier de logs
  home.file."Library/Logs/AeroSpace/.keep".text = "";
}

{ config, lib, pkgs, ... }:
let
  dotfilesSource = config.jeremie.dotfiles.source;
in
{
  # Configuration AeroSpace
  xdg.configFile."aerospace/aerospace.toml".source = dotfilesSource "aerospace/aerospace.toml";
  xdg.configFile."aerospace/raycast-ai-overlay.sh" = {
    source = dotfilesSource "aerospace/raycast-ai-overlay.sh";
    executable = true;
  };
  xdg.configFile."aerospace/organize-workspaces.sh" = {
    source = dotfilesSource "aerospace/organize-workspaces.sh";
    executable = true;
  };
  xdg.configFile."aerospace/split-picker.sh" = {
    source = dotfilesSource "aerospace/split-picker.sh";
    executable = true;
  };

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

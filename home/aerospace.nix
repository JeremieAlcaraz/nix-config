{ config, lib, pkgs, ... }:

{
  # Configuration AeroSpace
  xdg.configFile."aerospace/aerospace.toml".source = ../modules/dotfiles/aerospace/aerospace.toml;

  # LaunchAgent pour démarrer AeroSpace automatiquement
  launchd.agents.aerospace = {
    enable = true;
    config = {
      ProgramArguments = [ "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ];
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

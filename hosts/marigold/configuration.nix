{ config, pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    casks = [ "1password" "hammerspoon" ];
  };

  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
    MJConfigFile = "${config.users.users.jeremiealcaraz.home}/.config/hammerspoon/init.lua";
  };

  # Obligatoire pour ne pas casser l'install Determinate
  nix.enable = false;

  system.stateVersion = 4;
}

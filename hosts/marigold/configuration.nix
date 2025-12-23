{ pkgs, ... }: {
  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    casks = [ "1password" "hammerspoon" ];
  };

  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  # Obligatoire pour ne pas casser l'install Determinate
  nix.enable = false;

  system.stateVersion = 4;
}

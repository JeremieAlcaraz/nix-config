{ pkgs, ... }: {
  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  # Obligatoire pour ne pas casser l'install Determinate
  nix.enable = false;

  system.stateVersion = 4;
}

{ pkgs, ... }: {
  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  system.stateVersion = 4;
}

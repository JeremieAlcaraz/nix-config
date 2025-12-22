{ pkgs, ... }: {
  # L'utilisateur principal
  users.users.jeremiealcaraz.home = "/Users/jeremiealcaraz";

  # --- LA SOLUTION AU CONFLIT ---
  # On désactive la gestion du moteur Nix par nix-darwin 
  # car Determinate Systems (que nous avons installé) s'en occupe déjà.
  nix.enable = false;

  # On garde la version du système pour nix-darwin
  system.stateVersion = 4;
}

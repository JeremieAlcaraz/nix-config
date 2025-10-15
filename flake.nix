{
  # Meta : description courte affichée via les commandes Nix
  description = "Learnix: petit terrain d'apprentissage de Nix Flakes";

  # Dépendances du flake (sources externes récupérées via leurs URLs)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Outputs : tout ce que le flake met à disposition
  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    # Parcourt automatiquement les systèmes supportés (x86_64-linux, aarch64-darwin, ...)
    flake-utils.lib.eachDefaultSystem (system:
      let
        # pkgs = version de nixpkgs pour le système en cours
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };
      in {
        # Paquet par défaut que fournit le flake : la démo "hello"
        packages.default = pkgs.hello;

        # Shell de développement minimal avec fmt et hello
        devShells.default = pkgs.mkShell {
          name = "learnix-shell";
          buildInputs = [
            pkgs.nixpkgs-fmt
            pkgs.hello
          ];
        };
      }
    ) // {
      # Configuration NixOS nommée "learnix"
      nixosConfigurations.learnix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ ... }: {
            # Service SSH : actif, accès uniquement par clé
            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
              };
            };

            # Utilisateur jeremie autorisé via la clé publique fournie
            users.users.jeremie = {
              isNormalUser = true;
              hashedPassword = null;
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
              ];
            };
          })
        ];
      };
    };
}

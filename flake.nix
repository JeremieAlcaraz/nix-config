{
  description = "Learnix: petit terrain d'apprentissage de Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };
      in {
        packages.default = pkgs.hello;

        devShells.default = pkgs.mkShell {
          name = "learnix-shell";
          buildInputs = [
            pkgs.nixpkgs-fmt
            pkgs.hello
          ];
        };
      }
    );
}

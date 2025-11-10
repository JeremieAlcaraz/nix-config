{
  description = "Learnix NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    j12z-site = {
      url = "github:JeremieAlcaraz/j12zdotcom";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, j12z-site, sops-nix, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        # Magnolia - Infrastructure Proxmox
        magnolia = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/magnolia/configuration.nix
            sops-nix.nixosModules.sops
          ];
        };

        # Mimosa - Serveur web
        mimosa = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/mimosa/configuration.nix
            j12z-site.nixosModules.j12z-webserver
            sops-nix.nixosModules.sops
          ];
        };
      };
    };
}

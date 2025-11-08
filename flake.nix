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
        proxmox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/proxmox/configuration.nix
          ];
        };

        jeremie-web = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/jeremie-web/configuration.nix
           # j12z-site.nixosModules.j12z-webserver
            sops-nix.nixosModules.sops
          ];
        };
      };
    };
}

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

        # Mimosa Minimal - Pour l'installation initiale (sans serveur web)
        # Utilisé par le script d'installation pour éviter les problèmes réseau
        mimosa-minimal = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/mimosa/configuration.nix
            sops-nix.nixosModules.sops
            # Le module j12z-webserver n'est PAS importé ici
            # pour éviter les téléchargements npm pendant l'installation
          ];
        };

        # Mimosa - Serveur web complet (configuration de production)
        mimosa = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/mimosa/configuration.nix
            ./hosts/mimosa/webserver.nix  # Configuration du serveur web
            j12z-site.nixosModules.j12z-webserver
            sops-nix.nixosModules.sops
          ];
        };

        # ISO d'installation personnalisée
        # Build avec: nix build .#nixosConfigurations.installer.config.system.build.isoImage
        installer = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./iso/custom-installer.nix
          ];
        };
      };
    };
}

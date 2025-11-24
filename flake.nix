{
  description = "Learnix NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    j12z-site = {
      url = "github:JeremieAlcaraz/j12zdotcom";
      # Ne pas forcer nixpkgs - laisser j12zdotcom utiliser sa propre version
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, j12z-site, sops-nix, home-manager, darwin, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        # Magnolia - Infrastructure Proxmox
        magnolia = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/magnolia/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
          ];
        };

        # Mimosa - Serveur web (webserver désactivé par défaut lors de l'installation)
        # Pour activer le webserver après l'installation :
        #   1. Éditez ce fichier et changez enable = false → enable = true
        #   2. sudo nixos-rebuild switch --flake .#mimosa
        mimosa = nixpkgs.lib.nixosSystem {
          inherit system;
          # Passer j12z-site en argument pour accéder au package pré-buildé
          specialArgs = { inherit j12z-site; };
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/mimosa/configuration.nix
            ./hosts/mimosa/webserver.nix  # Configuration du serveur web
            # Retrait de j12z-site.nixosModules.j12z-webserver qui rebuild le site
            # On utilise maintenant directement le package via specialArgs
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
            # Webserver activé
            {
              mimosa.webserver.enable = true;
            }
          ];
        };

        # Whitelily - VM n8n automation
        whitelily = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/whitelily/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
          ];
        };

        # Minimal - VM de démonstration minimale
        minimal = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/minimal/configuration.nix
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

      darwinConfigurations = {
        marigold = darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
            ./hosts/marigold/configuration.nix
          ];
        };
      };
    };
}

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

        # Mimosa - Serveur web (configuration complète)
        # Pour l'installation initiale, utiliser la config "minimal" à la place
        # Usage: sudo nixos-rebuild switch --flake .#mimosa
        mimosa = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit j12z-site; };
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/mimosa/configuration.nix
            ./hosts/mimosa/webserver.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
            { mimosa.webserver.enable = true; }
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

        # Minimal - Configuration minimale pour installation initiale
        # Usage pour install : nixos-install --flake .#minimal
        # Puis switch vers la vraie config : sudo nixos-rebuild switch --flake .#<hostname>
        minimal = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/base.nix
            ./modules/ssh.nix
            ./hosts/minimal/configuration.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
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

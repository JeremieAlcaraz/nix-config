{
  description = "Learnix NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

  outputs = { self, nixpkgs, nixpkgs-unstable, j12z-site, sops-nix, home-manager, darwin, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        # Magnolia - Infrastructure Proxmox
        magnolia = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
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

        # Mimosa Bootstrap - Configuration d'installation légère (SANS webserver)
        # Utilisez cette config pour l'installation initiale depuis l'ISO
        # Une fois installé, basculez vers "mimosa" pour activer le webserver
        mimosa-bootstrap = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit j12z-site; };
          modules = [
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
            ./hosts/mimosa/configuration.nix
            ./hosts/mimosa/webserver.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
            # Webserver DÉSACTIVÉ - installation rapide depuis le cache
            {
              mimosa.webserver.enable = false;
            }
          ];
        };

        # Mimosa Production - Configuration complète (AVEC webserver j12zdotcom)
        # Après installation avec mimosa-bootstrap, activez cette config avec :
        #   sudo nixos-rebuild switch --flake .#mimosa
        mimosa = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit j12z-site; };
          modules = [
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
            ./hosts/mimosa/configuration.nix
            ./hosts/mimosa/webserver.nix
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremie = import ./home/jeremie.nix;
            }
            # Webserver ACTIVÉ - configuration production complète
            {
              mimosa.webserver.enable = true;
            }
          ];
        };

        # Whitelily - VM n8n automation
        whitelily = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
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

        # Dandelion - VM Gitea (serveur Git auto-hébergé)
        dandelion = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
            ./hosts/dandelion/configuration.nix
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
            ./modules/home-manager/base.nix
            ./modules/home-manager/ssh.nix
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
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jeremiealcaraz = import ./home/marigold.nix;
              # Rendre nixpkgs-unstable accessible dans les modules Home Manager
              nixpkgs.overlays = [
                (final: prev: {
                  unstable = import nixpkgs-unstable {
                    system = "aarch64-darwin";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };
      };
    };
}

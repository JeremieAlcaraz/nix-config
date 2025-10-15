{
  # Meta : description courte affichée via les commandes Nix
  description = "Learnix: petit terrain d'apprentissage de Nix Flakes";

  # Dépendances du flake (sources externes récupérées via leurs URLs)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    # Disko : gestion déclarative des disques et filesystems
    disko.url = "github:nix-community/disko";
  };

  # Outputs : tout ce que le flake met à disposition
  outputs = inputs@{ self, nixpkgs, flake-utils, disko, ... }:
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
          # Module Disko fournissant les options `disko.*`
          disko.nixosModules.disko
          ({ ... }: {
            # Service SSH : actif, accès uniquement par clé
            services.openssh = {
              enable = true;
              settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
              };
            };

            # Agencement disque/partitions géré par Disko
            # ⚠️ Le disque cible est identifié via un chemin stable `by-id`
            disko.enableConfig = true;
            disko.devices = {
              disk.main = {
                type = "disk";
                device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_learnix-root";
                content = {
                  type = "gpt";
                  partitions = {
                    EFI = {
                      size = "512M";
                      type = "EF00";
                      content = {
                        type = "filesystem";
                        format = "vfat";
                        mountpoint = "/boot";
                      };
                    };
                    root = {
                      size = "100%";
                      type = "8300";
                      content = {
                        type = "filesystem";
                        format = "ext4";
                        mountpoint = "/";
                      };
                    };
                  };
                };
              };
            };

            # Chargeur de démarrage : systemd-boot (UEFI) pour OVMF
            boot.loader.grub.enable = false;
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi = {
              canTouchEfiVariables = true;
              efiSysMountPoint = "/boot";
            };

            # Utilisateur jeremie autorisé via la clé publique fournie
            users.users.jeremie = {
              isNormalUser = true;
              hashedPassword = null;
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
              ];
            };

            # État de référence de la machine (version de base NixOS)
            system.stateVersion = "24.05";
          })
        ];
      };
    };
}

# TEMPLATE - À REMPLACER PAR LA CONFIGURATION GÉNÉRÉE
# Ce fichier sera généré automatiquement lors de l'installation de NixOS
# avec la commande: nixos-generate-config --root /mnt
#
# Pour l'instant, voici un template basique qui devra être remplacé

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Configuration des disques - À ADAPTER selon votre VM
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  swapDevices = [ ];

  # Plateforme
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

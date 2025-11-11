# ISO NixOS personnalisée pour l'installation de nix-config
# Build: nix build .#nixosConfigurations.installer.config.system.build.isoImage
#
# Cette ISO inclut :
# - Flakes activés par défaut
# - Outils de diagnostic réseau
# - Scripts d'installation
# - Configuration réseau optimisée

{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Activer les flakes par défaut
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Configuration réseau pour l'installation
  networking.useDHCP = true;
  networking.wireless.enable = false; # Désactiver wifi (VMs Proxmox utilisent Ethernet)

  # Configurer des DNS publics par défaut pour éviter les problèmes
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4" ];

  # Outils de diagnostic et d'installation inclus dans l'ISO
  environment.systemPackages = with pkgs; [
    # Outils réseau essentiels
    bind # nslookup
    dnsutils # dig
    curl
    wget

    # Outils de diagnostic
    htop
    iotop
    tcpdump

    # Outils système
    git
    vim
    tmux
    tree
    lsof
    pciutils
    usbutils

    # Outils de partitionnement
    parted
    gptfdisk

    # Utilitaires
    rsync
    unzip
    file
  ];

  # Copier les scripts d'installation dans l'ISO
  environment.etc."installer/scripts/install-nixos.sh" = {
    source = ../scripts/install-nixos.sh;
    mode = "0755";
  };

  environment.etc."installer/scripts/diagnose-network.sh" = {
    source = ../scripts/diagnose-network.sh;
    mode = "0755";
  };

  # Message de bienvenue personnalisé
  programs.bash.interactiveShellInit = ''
    cat << 'EOF'

    ╔════════════════════════════════════════════════════════════╗
    ║                                                            ║
    ║   🌸 NixOS Installation ISO - nix-config                  ║
    ║                                                            ║
    ║   Cette ISO contient tous les outils nécessaires pour     ║
    ║   installer votre configuration NixOS.                    ║
    ║                                                            ║
    ╚════════════════════════════════════════════════════════════╝

    📦 Scripts d'installation disponibles dans /etc/installer/scripts/

    🔧 Diagnostic réseau :
       sudo /etc/installer/scripts/diagnose-network.sh

    🚀 Installation NixOS :
       sudo /etc/installer/scripts/install-nixos.sh [magnolia|mimosa]

    💡 Les flakes sont activés par défaut
    💡 DNS publics (1.1.1.1, 8.8.8.8) configurés automatiquement

    EOF
  '';

  # Augmenter la taille de l'ISO si nécessaire
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Nom de l'ISO
  isoImage.isoName = lib.mkForce "nixos-nix-config-installer-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  # Version
  system.stateVersion = "24.11";
}

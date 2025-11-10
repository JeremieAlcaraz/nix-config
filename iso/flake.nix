{
  description = "ISO NixOS minimale avec support TTY série (ttyS0) pour Proxmox/NoVNC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.iso-minimal-ttyS0 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        # Base ISO minimal officielle de NixOS
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

        # Configuration personnalisée
        ({ pkgs, lib, ... }: {
          # 🧠 Nom de l'hôte ISO
          networking.hostName = "nixos-iso-ttyS0";

          # 🖥️ Configuration du boot pour console série
          # console=ttyS0,115200n8 : active la console série (parfait pour Proxmox/NoVNC)
          # console=tty1 : garde aussi la console graphique standard
          boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];

          # 🔌 Active plusieurs TTYs (tty1, tty2 et ttyS0 série)
          services.getty = {
            autologinUser = "nixos";  # Connexion automatique
            helpLine = ''

              Bienvenue sur l'ISO NixOS minimale avec support TTY série !

              Cette ISO est configurée pour Proxmox/NoVNC avec :
              - Console série sur ttyS0 (115200 baud)
              - Autologin en tant que "nixos"
              - Environnement X11 minimal avec xterm

              Pour démarrer l'interface graphique : startx
            '';
          };

          # 💻 Environnement X11 minimal avec xterm
          services.xserver = {
            enable = true;
            # Désactive le display manager par défaut (on utilisera startx)
            displayManager.startx.enable = true;
          };

          # 📦 Packages essentiels pour l'ISO
          environment.systemPackages = with pkgs; [
            # Interface graphique minimale
            xterm
            xorg.xinit
            twm  # Tiny Window Manager (très léger)

            # Outils de base
            vim
            git
            curl
            wget
            htop
            tree

            # Outils réseau
            inetutils
            nmap

            # Outils de diagnostic
            pciutils
            usbutils
          ];

          # 🐚 Configuration de ZSH comme shell par défaut
          programs.zsh = {
            enable = true;
            enableCompletion = true;
            autosuggestions.enable = true;
            syntaxHighlighting.enable = true;
          };

          # ✨ Starship prompt moderne
          programs.starship = {
            enable = true;
            settings = {
              add_newline = false;
              character = {
                success_symbol = "[➜](bold green)";
                error_symbol = "[➜](bold red)";
              };
              directory = {
                truncation_length = 3;
                truncate_to_repo = true;
              };
            };
          };

          # 👤 Configuration de l'utilisateur nixos (user par défaut de l'ISO)
          users.users.nixos = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" ];
            shell = pkgs.zsh;
            initialPassword = "nixos";  # Mot de passe par défaut
          };

          # 🔓 Permet sudo sans mot de passe pour l'utilisateur nixos
          security.sudo.wheelNeedsPassword = false;

          # 🌐 Active NetworkManager (gère automatiquement le DHCP)
          networking.wireless.enable = false;  # Désactive wpa_supplicant (conflit avec NetworkManager)
          networking.networkmanager.enable = true;

          # 🖥️ QEMU Guest Agent pour Proxmox (affiche l'IP dans l'interface)
          services.qemuGuest.enable = true;

          # 🔧 SSH activé avec mot de passe temporaire (pratique pour debug)
          services.openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = true;  # Activé pour l'ISO (désactiver en prod)
            };
          };

          # 📝 Message de bienvenue dans le shell
          programs.zsh.interactiveShellInit = ''
            echo ""
            echo "🚀 ISO NixOS minimale avec TTY série (ttyS0)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "  Pour démarrer X11 : startx"
            echo "  User : nixos / Pass : nixos"
            echo "  SSH activé sur port 22"
            echo ""
          '';

          # 🎯 ISO metadata
          isoImage = {
            isoName = lib.mkForce "nixos-minimal-ttyS0.iso";
            volumeID = lib.mkForce "NIXOS_TTYS0";
            appendToMenuLabel = lib.mkForce " (avec support TTY série)";
          };
        })
      ];
    };
  };
}

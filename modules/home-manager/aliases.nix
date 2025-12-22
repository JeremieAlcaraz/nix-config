{ config, pkgs, osConfig, ... }:

{
  # Fish shell aliases - Optimisés pour NixOS
  programs.fish = {
    shellAliases = {
      # ═══════════════════════════════════════════════════
      # 🔄 NIXOS REBUILD - Gestion de la configuration
      # ═══════════════════════════════════════════════════

      # Rebuild avec auto-détection du hostname
      r = "sudo nixos-rebuild switch --flake .#(hostname)";

      # Rebuild boot (pour changements kernel/bootloader)
      rb = "sudo nixos-rebuild boot --flake .#(hostname)";

      # Rebuild test (sans ajouter de génération au boot)
      rt = "sudo nixos-rebuild test --flake .#(hostname)";

      # Update flake inputs + rebuild
      ru = "nix flake update && sudo nixos-rebuild switch --flake .#(hostname)";

      # Rebuild avec verbose (pour debug)
      rv = "sudo nixos-rebuild switch --flake .#(hostname) --show-trace";

      # Rebuild ALL configurations (magnolia cache builder)
      ra = "/etc/nixos/scripts/rebuild-all.sh";

      # Deploy ALL configurations to remote hosts
      da = "/etc/nixos/scripts/deploy-all.sh";

      # ═══════════════════════════════════════════════════
      # 📦 GESTION DES GÉNÉRATIONS
      # ═══════════════════════════════════════════════════

      # Lister les générations
      ngl = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

      # Garbage collector (nettoie les anciennes générations)
      ngc = "sudo nix-collect-garbage -d";

      # Nettoyer seulement les générations > 7 jours
      ngc7 = "sudo nix-collect-garbage --delete-older-than 7d";

      # Nettoyer seulement les générations > 30 jours
      ngc30 = "sudo nix-collect-garbage --delete-older-than 30d";

      # Optimiser le store (hard links)
      nopt = "sudo nix-store --optimise";

      # ═══════════════════════════════════════════════════
      # 🔍 FLAKE OPERATIONS
      # ═══════════════════════════════════════════════════

      # Mettre à jour les inputs du flake
      nfu = "nix flake update";

      # Afficher les infos du flake
      nfi = "nix flake show";

      # Vérifier le flake
      nfc = "nix flake check";

      # Mettre à jour un input spécifique (ex: nfu1 nixpkgs)
      nfu1 = "nix flake lock --update-input";

      # ═══════════════════════════════════════════════════
      # 🐙 GIT SHORTCUTS - Pour /etc/nixos
      # ═══════════════════════════════════════════════════

      gs = "git status";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit -m";
      gca = "git commit --amend";
      gp = "git push";
      gpl = "git pull";
      gd = "git diff";
      gdc = "git diff --cached";
      gl = "git log --oneline --graph --decorate -10";
      gla = "git log --oneline --graph --decorate --all -20";

      # Note: 'gu' est maintenant une fonction (voir fish-functions.nix)
      # Elle propose interactivement de rebuild magnolia après un git pull réussi

      # ═══════════════════════════════════════════════════
      # 🛠️ SYSTEMD - Gestion des services
      # ═══════════════════════════════════════════════════

      # Status d'un service
      sst = "sudo systemctl status";

      # Start/Stop/Restart
      ssta = "sudo systemctl start";
      ssto = "sudo systemctl stop";
      ssr = "sudo systemctl restart";

      # Enable/Disable
      sse = "sudo systemctl enable";
      ssd = "sudo systemctl disable";

      # Lister tous les services
      ssl = "systemctl list-units --type=service";

      # Lister les services failed
      ssf = "systemctl list-units --type=service --state=failed";

      # Reload systemd daemon
      sdr = "sudo systemctl daemon-reload";

      # ═══════════════════════════════════════════════════
      # 📋 LOGS - Journalctl
      # ═══════════════════════════════════════════════════

      # Follow les logs système
      jf = "sudo journalctl -f";

      # Follow les logs d'un service
      jfs = "sudo journalctl -u";

      # Logs depuis le dernier boot
      jb = "sudo journalctl -b";

      # Logs avec priorité error et plus
      je = "sudo journalctl -p err -b";

      # ═══════════════════════════════════════════════════
      # 📁 NAVIGATION
      # ═══════════════════════════════════════════════════

      # Remonte dans l'arborescence
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Accès rapide à /etc/nixos
      nxc = "cd /etc/nixos";

      # ═══════════════════════════════════════════════════
      # 📊 LISTING & FICHIERS
      # ═══════════════════════════════════════════════════

      # Listing détaillé avec couleurs
      ll = "ls -lah --color=auto";
      la = "ls -A --color=auto";
      l = "ls -CF --color=auto";

      # Tree limité à 2 niveaux
      t2 = "tree -L 2";
      t3 = "tree -L 3";

      # ═══════════════════════════════════════════════════
      # 🔍 RECHERCHE
      # ═══════════════════════════════════════════════════

      # Trouver un fichier
      ff = "find . -type f -name";

      # Trouver un dossier
      fd = "find . -type d -name";

      # Grep récursif avec couleurs
      gr = "grep -r --color=auto";

      # ═══════════════════════════════════════════════════
      # 💾 SYSTÈME
      # ═══════════════════════════════════════════════════

      # Espace disque
      df = "df -h";

      # Utilisation disque du dossier courant
      du = "du -sh";

      # Top processes par CPU
      topcpu = "ps aux --sort=-%cpu | head -10";

      # Top processes par RAM
      topmem = "ps aux --sort=-%mem | head -10";

      # ═══════════════════════════════════════════════════
      # 🌐 RÉSEAU (pour tes VMs)
      # ═══════════════════════════════════════════════════

      # Ping rapide
      p = "ping -c 4";

      # Ports en écoute
      ports = "sudo netstat -tulpn";

      # Connexions actives
      conns = "sudo netstat -atn";

      # ═══════════════════════════════════════════════════
      # 🔐 TAILSCALE (pour ton infra)
      # ═══════════════════════════════════════════════════

      # Status Tailscale
      tst = "sudo tailscale status";

      # IP Tailscale
      tip = "tailscale ip";

      # Ping via Tailscale
      tping = "tailscale ping";

      # ═══════════════════════════════════════════════════
      # 🔄 UTILITAIRES
      # ═══════════════════════════════════════════════════

      # Recharger la config fish
      reload = "exec fish";

      # Afficher le PATH ligne par ligne
      path = "echo $PATH | tr ':' '\\n'";

      # Historique avec timestamps
      h = "history";
    };
  };
}

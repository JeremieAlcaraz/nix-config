{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./n8n.nix
    ./n8n-backup.nix
    ../../modules/ssh.nix
    ../../modules/tailscale.nix

  ];

  time.timeZone = "Europe/Paris";
  system.stateVersion = "25.05";

  # Réseau
  networking.hostName = "whitelily";  # VM n8n automation
  networking.useDHCP = true;
  # Configuration DNS (resolvconf désactivé, donc configuration manuelle)
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];
  # Firewall activé (Cloudflare Tunnel = trafic sortant uniquement)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH uniquement (Cloudflare Tunnel = trafic sortant)
  };

  sshCommon = {
    jeremieHashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
    extraPackages = with pkgs; [ htop restic gzip ];
  };

  # QEMU Guest Agent
  services.qemuGuest.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Configuration sops-nix pour la gestion des secrets
  sops = {
    defaultSopsFile = ../../secrets/whitelily.yaml;
    age = {
      # Utiliser UNIQUEMENT la clé age partagée (copiée depuis le Mac)
      keyFile = "/var/lib/sops-nix/key.txt";
      # Désactiver les clés SSH pour forcer l'utilisation de keyFile
      sshKeyPaths = [];
    };
    secrets = {
      # Hash du mot de passe de l'utilisateur jeremie
      jeremie-password-hash = {
        neededForUsers = true;
      };
      # Secrets n8n (utilisés dans n8n.nix)
      "n8n/encryption_key" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/basic_user" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/basic_pass" = { owner = "root"; group = "root"; mode = "0400"; };
      "n8n/db_password" = { owner = "root"; group = "root"; mode = "0400"; };
      # Cloudflare Tunnel token (simplifié)
      "cloudflared/token" = { owner = "cloudflared"; group = "cloudflared"; mode = "0400"; };
      # GitHub token pour auto-update workflow
      "github/token" = { owner = "root"; group = "root"; mode = "0400"; };
    };
  };

   # ========================================================================
  # CONFIGURATION DU BACKUP AUTOMATISÉ N8N
  # ========================================================================
  
  services.n8n-backup = {
    enable = true;
    
    # Répertoire où créer les backups temporaires (avant upload GDrive)
    # Changé de /tmp à /var/backups/n8n pour plus de persistance
    backupDir = "/var/backups/n8n";
    
    # Fichier de log du backup
    logFile = "/var/log/n8n-backup.log";
    
    # Chemin dans Google Drive où stocker les backups
    # Tu dois avoir créé ce dossier dans GDrive : backups/n8n
    gdrivePath = "backups/n8n";

    # Note: L'ID du dossier Google Drive est lu depuis les secrets sops
    # (google_drive/folder_id) et n'a plus besoin d'être configuré ici


    # Calendrier systemd (format OnCalendar) pour l'exécution du backup
    # "*-*-* 00:00:00" = tous les jours à minuit
    # Tu peux changer pour :
    # - "*-*-* 02:00:00" = tous les jours à 2h du matin
    # - "*-*-01 00:00:00" = le 1er de chaque mois à minuit
    # - "Mon *-*-* 00:00:00" = tous les lundis à minuit
    schedule = "*-*-* 00:00:00";
    
    # Nombre de backups à garder localement dans /var/backups/n8n
    # 7 = garde les 7 backups les plus récents, supprime les plus anciens
    retentionLocal = 7;
    
    # Nombre de jours de backups à garder sur Google Drive
    # 30 = supprime automatiquement les backups de plus de 30 jours
    retentionGdrive = 30;
  };

  # ZSH activé au niveau système (requis pour users.users.jeremie.shell)
  # La configuration ZSH détaillée est gérée par Home Manager
}

# Plan : Backup/Restore automatisé pour Gitea

## 📋 Analyse comparative n8n vs Gitea

### n8n (existant)
- **Type**: Container Podman
- **Base de données**: PostgreSQL (podman-n8n)
- **Données**: `/var/lib/n8n` (montage volume)
- **Config**: Variables d'env dans `/run/n8n/n8n.env`
- **Secrets critiques**: `N8N_ENCRYPTION_KEY` (pour credentials)
- **Arrêt**: `systemctl stop podman-n8n.service`

### Gitea (à créer)
- **Type**: Service systemd natif NixOS
- **Base de données**: PostgreSQL (database `gitea`, user `gitea`)
- **Données**: `/var/lib/gitea` (repos, avatars, attachments, etc.)
- **Config**: `/var/lib/gitea/custom/conf/app.ini` (généré par NixOS)
- **Secrets**: Clé SSH serveur, secrets OAuth, tokens
- **Arrêt**: `systemctl stop gitea.service`

---

## 🎯 Objectifs du backup Gitea

### 1. Données à sauvegarder
- ✅ **Base PostgreSQL** : Dump complet de la database `gitea`
- ✅ **Répertoire de données** : `/var/lib/gitea/` (repos Git, avatars, LFS, etc.)
- ✅ **Configuration** : `app.ini` complet (avec paramètres NixOS)
- ✅ **Clés SSH** : `/var/lib/gitea/.ssh/` (clés du serveur Gitea SSH)
- ✅ **Version info** : PostgreSQL version, Gitea version, NixOS generation

### 2. Données à NE PAS sauvegarder
- ❌ Logs (`/var/lib/gitea/log/`)
- ❌ Cache temporaire
- ❌ Indexation de recherche (se reconstruit)

---

## 📦 Structure du backup

```
gitea_backup_20260122_120000/
├── gitea_database.sql              # Dump PostgreSQL
├── gitea_data.tar.gz               # /var/lib/gitea (compressé)
├── gitea_config.ini                # app.ini
├── gitea_ssh_keys.tar.gz           # Clés SSH du serveur Gitea
├── restore_config.txt              # Config de restauration (versions, paths)
├── RESTORE_README.md               # Instructions de restauration
└── restore_script.sh               # Script de restauration automatique
```

**Archive finale** : `gitea_backup_20260122_120000.tar.gz` + SHA256

---

## 🔧 Étapes du script de backup

### Phase 1 : Préparation (étapes 1-2)
1. Créer le dossier de backup temporaire
2. Récupérer les informations système (versions, paths)

### Phase 2 : Arrêt de Gitea (étape 3)
3. Arrêter le service `gitea.service`
   - ⚠️ Downtime nécessaire pour cohérence des données

### Phase 3 : Backup des données (étapes 4-7)
4. **Dump PostgreSQL**
   ```bash
   sudo -u postgres pg_dump gitea > gitea_database.sql
   ```

5. **Backup du répertoire de données**
   ```bash
   tar czf gitea_data.tar.gz \
     --exclude='log/*' \
     --exclude='indexers/*' \
     -C /var/lib gitea/
   ```

6. **Copie de la configuration**
   ```bash
   cp /var/lib/gitea/custom/conf/app.ini gitea_config.ini
   ```

7. **Backup des clés SSH**
   ```bash
   tar czf gitea_ssh_keys.tar.gz -C /var/lib/gitea .ssh/
   ```

### Phase 4 : Redémarrage (étape 8)
8. Redémarrer `gitea.service`

### Phase 5 : Métadonnées (étapes 9-10)
9. Créer `restore_config.txt` avec :
   - PostgreSQL version
   - Gitea version
   - NixOS generation
   - Database credentials
   - Paths des données

10. Créer `RESTORE_README.md` avec instructions

### Phase 6 : Archive et upload (étapes 11-13)
11. Créer l'archive finale `.tar.gz` + SHA256
12. Upload vers Google Drive via rclone
13. Nettoyage des vieux backups (local + GDrive)

### Phase 7 : Notifications (étape 14)
14. Envoyer notifications :
    - Slack (statut + métadonnées)
    - Email (si erreur)
    - Notion (log de backup)

---

## 🔄 Script de restauration

Un script `restore_script.sh` sera inclus dans chaque backup pour automatiser la restauration :

```bash
#!/usr/bin/env bash
# Restore automatique Gitea

# 1. Vérifier que Gitea n'est pas en cours d'exécution
# 2. Créer la database PostgreSQL si elle n'existe pas
# 3. Restaurer le dump SQL
# 4. Extraire les données dans /var/lib/gitea
# 5. Restaurer les clés SSH
# 6. Copier app.ini (ou afficher pour config NixOS)
# 7. Démarrer gitea.service
# 8. Vérifier que Gitea démarre correctement
```

---

## 📁 Structure du module NixOS

### Fichier : `hosts/dandelion/gitea-backup.nix`

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.gitea-backup;
  
  backupScript = pkgs.writeShellScript "gitea-backup.sh" ''
    # Script complet de backup
  '';
  
  restoreScript = pkgs.writeShellScript "gitea-restore.sh" ''
    # Script complet de restauration
  '';

in {
  options.services.gitea-backup = {
    enable = mkEnableOption "Backup automatisé Gitea";
    
    backupDir = mkOption {
      type = types.str;
      default = "/var/backups/gitea";
    };
    
    logFile = mkOption {
      type = types.str;
      default = "/var/log/gitea-backup.log";
    };
    
    gdrivePath = mkOption {
      type = types.str;
      default = "backups/gitea";
    };
    
    schedule = mkOption {
      type = types.str;
      default = "*-*-* 02:00:00";  # 2h du matin
    };
    
    retentionLocal = mkOption {
      type = types.int;
      default = 7;
    };
    
    retentionGdrive = mkOption {
      type = types.int;
      default = 90;  # Plus long pour Gitea (plus critique)
    };
  };
  
  config = mkIf cfg.enable {
    # Services systemd
    # Secrets sops
    # Tmpfiles
  };
}
```

---

## 🔐 Secrets sops nécessaires

### Dans `secrets/dandelion.yaml` :

```yaml
# Déjà existants (réutilisés)
google_drive/client_id: ENC[...]
google_drive/client_secret: ENC[...]
google_drive/token: ENC[...]
google_drive/folder_id: ENC[...]

# Notifications (réutilisés de n8n ou nouveaux)
notion/api_token: ENC[...]
notion/database_id_gitea: ENC[...]  # Nouveau (ou réutiliser celui de n8n)
gmail/from: ENC[...]
gmail/to: ENC[...]
gmail/app_password: ENC[...]
slack/webhook_url: ENC[...]
```

---

## 🚀 Activation dans la config

### Dans `hosts/dandelion/configuration.nix` :

```nix
imports = [
  ./gitea-backup.nix
];

services.gitea-backup = {
  enable = true;
  schedule = "*-*-* 02:00:00";  # Tous les jours à 2h
  retentionGdrive = 90;  # 90 jours sur GDrive
};
```

---

## 📊 Commandes manuelles

```bash
# Lancer un backup manuel
sudo systemctl start gitea-backup.service

# Voir les logs
sudo journalctl -u gitea-backup -f

# Voir le statut du timer
systemctl status gitea-backup.timer

# Lister les backups
ls -lh /var/backups/gitea/

# Restaurer un backup
sudo /var/backups/gitea/gitea_backup_XXXXXX/restore_script.sh
```

---

## ⚠️ Différences importantes avec n8n

| Aspect | n8n | Gitea |
|--------|-----|-------|
| **Runtime** | Container Podman | Service systemd natif |
| **Variables d'env** | /run/n8n/n8n.env | app.ini (NixOS) |
| **Encryption key** | Critique (credentials) | N/A |
| **Arrêt service** | podman-n8n.service | gitea.service |
| **Données** | /var/lib/n8n | /var/lib/gitea |
| **Config** | Container env vars | app.ini généré par NixOS |
| **Restore complexity** | Élevée (encryption key) | Moyenne (standard) |

---

## ✅ Prochaines étapes

1. **Créer** `hosts/dandelion/gitea-backup.nix` avec le module complet
2. **Ajouter** les secrets manquants dans `secrets/dandelion.yaml`
3. **Tester** un backup manuel sur dandelion
4. **Valider** le script de restauration sur une VM de test
5. **Activer** le timer automatique

---

## 📝 Notes importantes

- Le backup Gitea est **CRITIQUE** car il contient tous les repos Git
- La rétention recommandée est **plus longue** que n8n (90 jours vs 30)
- Le downtime est **acceptable** car les backups sont à 2h du matin
- Le script de restauration **doit être testé** avant production
- Les clés SSH du serveur Gitea doivent être sauvegardées pour garder les fingerprints


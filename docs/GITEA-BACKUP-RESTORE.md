# Guide Complet : Backup & Restore Gitea

Ce guide explique comment fonctionne le système de backup automatisé de Gitea et comment restaurer un backup en cas de besoin.

---

## 📦 Section 1 : Backup Gitea

### Vue d'ensemble

Le système de backup Gitea est entièrement automatisé via un module NixOS qui :
- Sauvegarde quotidiennement la base PostgreSQL, les données Git, la config et les clés SSH
- Upload les backups vers Google Drive
- Envoie des notifications Slack/Email/Notion
- Nettoie automatiquement les vieux backups

**Configuration actuelle** :
- 📅 **Schedule** : Tous les jours à **2h00 du matin**
- 💾 **Rétention locale** : 7 backups sur dandelion (`/var/backups/gitea/`)
- ☁️ **Rétention Google Drive** : 90 jours
- 📍 **Emplacement GDrive** : `backups/gitea/`

---

### Contenu d'un backup

Chaque backup contient :

```
gitea_backup_20260122_120000.tar.gz
└── gitea_backup_20260122_120000/
    ├── gitea_database.sql           # Dump PostgreSQL complet
    ├── gitea_data.tar.gz            # Tous les repos Git + avatars + LFS
    ├── gitea_config.ini             # Configuration app.ini
    ├── gitea_ssh_keys.tar.gz        # Clés SSH du serveur
    ├── restore_config.txt           # Métadonnées (versions, paths)
    ├── RESTORE_README.md            # Instructions de restauration
    └── restore_script.sh            # Script de restauration automatique
```

**Taille typique** : Variable selon la taille des repos (quelques MB à plusieurs GB)

---

### Processus de backup (14 étapes)

Le script exécute ces étapes dans l'ordre :

1. **Préparation** : Création du dossier temporaire
2. **Info système** : Récupération versions (Gitea, PostgreSQL, NixOS)
3. **Arrêt Gitea** : `systemctl stop gitea.service` (⚠️ downtime ~2-3 min)
4. **Dump PostgreSQL** : Sauvegarde de la database `gitea`
5. **Backup données** : Archivage `/var/lib/gitea` (exclut logs/indexation)
6. **Backup config** : Copie de `app.ini`
7. **Backup SSH** : Archivage des clés SSH du serveur
8. **Redémarrage Gitea** : `systemctl start gitea.service`
9. **Création restore_config.txt** : Métadonnées du backup
10. **Création RESTORE_README.md** : Instructions de restauration
11. **Création restore_script.sh** : Script de restauration automatique
12. **Compression** : Création archive `.tar.gz` + hash SHA256
13. **Upload GDrive** : Upload via rclone
14. **Notifications** : Slack + Email (erreur) + Notion

**Downtime** : ~2-3 minutes (étapes 3 à 8)

---

### Lancer un backup manuel

#### Se connecter à dandelion

```bash
ssh jeremie@dandelion
```

#### Lancer le backup

```bash
sudo systemctl start gitea-backup.service
```

#### Suivre les logs en temps réel

```bash
# Option 1 : journalctl (logs systemd)
sudo journalctl -u gitea-backup -f

# Option 2 : fichier de log dédié
sudo tail -f /var/log/gitea-backup.log
```

#### Vérifier le statut

```bash
# Statut du service
sudo systemctl status gitea-backup.service

# Dernière exécution
sudo journalctl -u gitea-backup -n 100 --no-pager
```

---

### Backups automatiques (timer systemd)

#### Vérifier le timer

```bash
# Statut du timer
systemctl status gitea-backup.timer

# Liste tous les timers actifs
systemctl list-timers

# Détails du timer gitea
systemctl list-timers gitea-backup.timer --all
```

**Sortie typique** :
```
NEXT                         LEFT          LAST                         PASSED       UNIT                   ACTIVATES
Wed 2026-01-23 02:00:00 CET  9h left       Tue 2026-01-22 02:00:00 CET  14h ago      gitea-backup.timer     gitea-backup.service
```

#### Modifier le schedule

Éditer `/etc/nixos/configuration.nix` (via le flake) :

```nix
services.gitea-backup = {
  enable = true;
  schedule = "*-*-* 03:00:00";  # Changer à 3h du matin
  retentionLocal = 10;          # Garder 10 backups locaux
  retentionGdrive = 120;        # Garder 120 jours sur GDrive
};
```

Puis redéployer :

```bash
nixos-rebuild switch --flake .#dandelion --target-host jeremie@dandelion
```

#### Désactiver temporairement le timer

```bash
# Arrêter le timer (ne lance plus de backups automatiques)
sudo systemctl stop gitea-backup.timer

# Redémarrer le timer
sudo systemctl start gitea-backup.timer
```

---

### Lister les backups

#### Backups locaux

```bash
# Liste avec tailles
ls -lh /var/backups/gitea/

# Liste triée par date (plus récent en dernier)
ls -lt /var/backups/gitea/

# Compte le nombre de backups
ls -1 /var/backups/gitea/*.tar.gz | wc -l
```

#### Backups sur Google Drive

```bash
# Via rclone (sur dandelion)
rclone ls gdrive:gitea/ --config /run/gitea-backup/rclone.conf

# Avec détails (tailles, dates)
rclone lsl gdrive:gitea/ --config /run/gitea-backup/rclone.conf

# Trier par date
rclone ls gdrive:gitea/ --config /run/gitea-backup/rclone.conf | sort
```

Ou via l'interface web Google Drive : naviguer vers le dossier `backups/gitea/`

---

### Vérifier l'intégrité d'un backup

#### Vérifier le hash SHA256

```bash
cd /var/backups/gitea/

# Vérifier un backup spécifique
sha256sum -c gitea_backup_20260122_120000.tar.gz.sha256
```

**Sortie attendue** : `gitea_backup_20260122_120000.tar.gz: OK`

#### Inspecter le contenu sans extraire

```bash
# Lister les fichiers dans l'archive
tar tzf gitea_backup_20260122_120000.tar.gz | head -20

# Voir les métadonnées
tar xzf gitea_backup_20260122_120000.tar.gz \
  --to-stdout gitea_backup_20260122_120000/restore_config.txt
```

---

### Télécharger un backup depuis Google Drive

```bash
# Sur dandelion
rclone copy gdrive:gitea/gitea_backup_20260122_120000.tar.gz \
  /var/backups/gitea/ \
  --config /run/gitea-backup/rclone.conf

# Avec la barre de progression
rclone copy gdrive:gitea/gitea_backup_20260122_120000.tar.gz \
  /var/backups/gitea/ \
  --config /run/gitea-backup/rclone.conf \
  --progress
```

---

### Logs et debugging

#### Voir les logs complets

```bash
# Tous les logs du service
sudo journalctl -u gitea-backup --no-pager

# Logs des 24 dernières heures
sudo journalctl -u gitea-backup --since "24 hours ago"

# Logs entre deux dates
sudo journalctl -u gitea-backup --since "2026-01-20" --until "2026-01-22"

# Fichier de log dédié
sudo cat /var/log/gitea-backup.log
```

#### En cas d'erreur

1. **Vérifier l'état du service Gitea** :
   ```bash
   sudo systemctl status gitea.service
   ```

2. **Vérifier l'espace disque** :
   ```bash
   df -h /var/backups/gitea/
   df -h /var/lib/gitea/
   ```

3. **Vérifier les secrets sops** :
   ```bash
   # Les secrets doivent être lisibles
   sudo cat /run/secrets/google_drive/token > /dev/null && echo "✓ OK"
   sudo cat /run/secrets/notion/api_token > /dev/null && echo "✓ OK"
   ```

4. **Tester rclone manuellement** :
   ```bash
   # Lister le dossier GDrive
   rclone ls gdrive:gitea/ --config /run/gitea-backup/rclone.conf
   ```

5. **Voir les logs détaillés** :
   ```bash
   sudo journalctl -u gitea-backup -p err
   ```

---

## 🔄 Section 2 : Restauration Gitea

### Quand restaurer un backup ?

- 💥 **Crash du serveur** : Perte de données, corruption du disque
- 🚚 **Migration** : Déplacement vers un nouveau serveur
- 🔙 **Rollback** : Revenir à un état antérieur (erreur humaine, bug)
- 🧪 **Test** : Créer un environnement de test avec données réelles

---

### Prérequis avant restauration

1. ✅ **Backup disponible** : Fichier `.tar.gz` sur dandelion ou téléchargé depuis GDrive
2. ✅ **NixOS configuré** : Gitea installé et configuré (via `configuration.nix`)
3. ✅ **PostgreSQL running** : `systemctl status postgresql`
4. ✅ **Accès root** : Exécuter les commandes avec `sudo`

---

### Méthode 1 : Restauration interactive avec fzf (recommandée)

C'est la méthode la plus simple : le script liste automatiquement les backups sur Google Drive, vous laisse choisir avec fzf, télécharge et restaure.

#### Étape unique : Lancer le script

```bash
# Depuis ton Mac (dans le dossier nix-config)
ssh jeremie@dandelion

# Cloner le repo si pas déjà fait
cd /tmp
git clone http://dandelion:3000/jeremiealcaraz/nix-config.git
cd nix-config

# Lancer le script de restauration interactif
sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-gitea.sh
```

**Le script va automatiquement** :
1. 🔓 Déchiffrer les credentials Google Drive (via sops)
2. ☁️ Lister les 10 backups les plus récents sur Google Drive
3. 🎯 Te laisser choisir avec **fzf** (flèches haut/bas + Enter)
4. ⬇️ Télécharger le backup sélectionné
5. 🔍 Vérifier l'intégrité (SHA256)
6. 📋 Afficher les métadonnées du backup
7. ⚠️ Demander confirmation (taper `restore`)
8. 🛑 Arrêter Gitea
9. 🗄️ Restaurer la base PostgreSQL
10. 📂 Restaurer les données + clés SSH
11. 👤 Corriger les permissions
12. ⚡ Redémarrer Gitea
13. 🧪 Vérifier que tout fonctionne (HTTP + SSH)

**Sortie typique** :
```
╔════════════════════════════════════════╗
║   🔄 RESTAURATION GITEA               ║
╚════════════════════════════════════════╝

[RESTORE] 🔓 Déchiffrement des accès Google Drive...
[RESTORE] ☁️  Récupération de la liste des backups...

╭──────────────────────────────────────────────────────────╮
│ 🔽 SÉLECTIONNEZ LE BACKUP À RESTAURER (Enter)           │
├──────────────────────────────────────────────────────────┤
│ > gitea_backup_20260122_120000.tar.gz                    │
│   gitea_backup_20260121_120000.tar.gz                    │
│   gitea_backup_20260120_120000.tar.gz                    │
│   gitea_backup_20260119_120000.tar.gz                    │
│   gitea_backup_20260118_120000.tar.gz                    │
╰──────────────────────────────────────────────────────────╯

✅ Backup sélectionné : gitea_backup_20260122_120000.tar.gz
[RESTORE] ⬇️  Téléchargement de l'archive...
[RESTORE] 🔍 Vérification de l'intégrité...
✅ Intégrité vérifiée (SHA256 OK)
[RESTORE] 📦 Extraction de l'archive principale...
[RESTORE] 📋 Informations du backup :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Date backup: 20260122_120000
Hostname source: dandelion
Gitea version: 1.21.5
PostgreSQL version: 16
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  ATTENTION : Vous êtes sur le point d'écraser la base de données et les fichiers Gitea actuels.
⚠️  Une fois lancé, ce processus est irréversible.

Êtes-vous sûr de vouloir continuer ? (taper 'restore') : restore

[RESTORE] 🛑 Arrêt de Gitea...
[RESTORE] 🗄️  Restauration de PostgreSQL...
✅ Base de données restaurée
[RESTORE] 📂 Restauration des données Gitea (/var/lib/gitea)...
✅ Données restaurées
[RESTORE] 🔑 Restauration des clés SSH...
✅ Clés SSH restaurées
[RESTORE] 👤 Correction des permissions...
[RESTORE] ⚡ Redémarrage de Gitea...
✅ Service Gitea redémarré avec succès !
[RESTORE] 🧪 Vérifications post-restauration...
✅ HTTP accessible (port 3000)
✅ SSH accessible (port 2222)

╔════════════════════════════════════════╗
║   ✅ RESTAURATION TERMINÉE            ║
╚════════════════════════════════════════╝
```

---

### Méthode 2 : Restauration avec le script inclus dans le backup

Si tu as déjà téléchargé et extrait un backup manuellement :

#### Étape 1 : Extraire le backup

```bash
cd /tmp
tar xzf gitea_backup_20260122_120000.tar.gz
cd gitea_backup_20260122_120000/
```

#### Étape 2 : Exécuter le script de restauration

```bash
sudo ./restore_script.sh
```

**Le script va automatiquement** :
1. Arrêter Gitea
2. Créer/vérifier la database PostgreSQL
3. Restaurer le dump SQL
4. Restaurer les données dans `/var/lib/gitea`
5. Restaurer les clés SSH
6. Redémarrer Gitea
7. Vérifier que Gitea fonctionne

**Sortie typique** :
```
╔════════════════════════════════════════╗
║   🔄 RESTAURATION GITEA               ║
╚════════════════════════════════════════╝

[1/8] ⏸️  Arrêt de Gitea...
✓ Gitea arrêté

[2/8] 🗄️  Vérification de la base PostgreSQL...
✓ Database gitea existe

[3/8] 💾 Restauration de la base de données...
✓ Base restaurée

[4/8] 📦 Restauration des données Gitea...
✓ Données restaurées

[5/8] 🔑 Restauration des clés SSH...
✓ Clés SSH restaurées

[6/8] ⚙️  Vérification de la configuration...
   📄 Configuration disponible dans gitea_config.ini
   ⚠️  Comparez avec votre configuration NixOS actuelle

[7/8] ⚡ Démarrage de Gitea...
✓ Gitea est démarré

[8/8] ✅ Vérification...
✓ Gitea est démarré

╔════════════════════════════════════════╗
║   ✅ RESTAURATION TERMINÉE            ║
╚════════════════════════════════════════╝

Testez l'accès : curl http://localhost:3000/
```

#### Étape 5 : Vérifier que Gitea fonctionne

```bash
# Vérifier le service
sudo systemctl status gitea.service

# Tester l'accès HTTP
curl -I http://localhost:3000/

# Tester l'accès SSH
ssh -p 2222 -T gitea@localhost
```

---

### Méthode 3 : Restauration manuelle

Si tu veux plus de contrôle ou si le script automatique échoue.

#### Étape 1 : Extraire le backup

```bash
cd /tmp
tar xzf gitea_backup_20260122_120000.tar.gz
cd gitea_backup_20260122_120000/
```

#### Étape 2 : Arrêter Gitea

```bash
sudo systemctl stop gitea.service

# Vérifier qu'il est bien arrêté
sudo systemctl is-active gitea.service
# Doit retourner : inactive
```

#### Étape 3 : Restaurer PostgreSQL

```bash
# Vérifier que la database existe
sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw gitea
echo $?  # Doit retourner 0 si la database existe

# Si elle n'existe pas, la créer
sudo -u postgres createdb gitea
sudo -u postgres createuser gitea || true
sudo -u postgres psql -c "GRANT ALL ON DATABASE gitea TO gitea;"

# Restaurer le dump
sudo -u postgres psql gitea < gitea_database.sql

# Vérifier la restauration
sudo -u postgres psql gitea -c "SELECT COUNT(*) FROM repository;"
```

#### Étape 4 : Restaurer les données Gitea

```bash
# Sauvegarder les données actuelles (par sécurité)
sudo mv /var/lib/gitea /var/lib/gitea.old

# Extraire les données
sudo tar xzf gitea_data.tar.gz -C /var/lib/

# Fixer les permissions
sudo chown -R gitea:gitea /var/lib/gitea
```

#### Étape 5 : Restaurer les clés SSH

```bash
# Extraire les clés SSH
sudo tar xzf gitea_ssh_keys.tar.gz -C /var/lib/gitea/

# Fixer les permissions
sudo chown -R gitea:gitea /var/lib/gitea/.ssh
sudo chmod 700 /var/lib/gitea/.ssh
sudo chmod 600 /var/lib/gitea/.ssh/* 2>/dev/null || true
```

#### Étape 6 : Vérifier la configuration

```bash
# Comparer la config du backup avec la config actuelle
diff gitea_config.ini /var/lib/gitea/custom/conf/app.ini

# Si besoin, ajuster la configuration NixOS
# (ne pas copier directement app.ini, il est généré par NixOS)
```

#### Étape 7 : Démarrer Gitea

```bash
sudo systemctl start gitea.service

# Attendre quelques secondes
sleep 5

# Vérifier l'état
sudo systemctl status gitea.service
```

#### Étape 8 : Vérifier le fonctionnement

```bash
# Logs de démarrage
sudo journalctl -u gitea -n 50

# Tester HTTP
curl http://localhost:3000/

# Tester SSH
ssh -p 2222 -T gitea@localhost
```

---

### Restauration sur un nouveau serveur

Pour migrer Gitea vers une nouvelle machine :

#### 1. Installer NixOS sur le nouveau serveur

Configurer NixOS avec le même `configuration.nix` que l'ancien serveur.

#### 2. Déployer la configuration

```bash
# Depuis ton Mac
nixos-rebuild switch --flake .#dandelion --target-host jeremie@nouveau-serveur
```

#### 3. Copier la clé age sops

```bash
# Sur le nouveau serveur
sudo mkdir -p /var/lib/sops-nix
sudo cp /chemin/vers/la/cle/age/key.txt /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt
```

#### 4. Télécharger le backup

```bash
# Depuis Google Drive
rclone copy gdrive:gitea/gitea_backup_XXXXXX.tar.gz \
  /tmp/ \
  --config /run/gitea-backup/rclone.conf \
  --progress
```

#### 5. Extraire et restaurer

```bash
cd /tmp
tar xzf gitea_backup_XXXXXX.tar.gz
cd gitea_backup_XXXXXX/
sudo ./restore_script.sh
```

#### 6. Mettre à jour Tailscale/DNS

Si tu utilises Tailscale ou un DNS pour pointer vers `dandelion`, assure-toi que le hostname est correct.

---

### Restauration partielle

Tu peux restaurer seulement certaines parties :

#### Restaurer uniquement la database

```bash
sudo systemctl stop gitea.service
sudo -u postgres psql gitea < gitea_database.sql
sudo systemctl start gitea.service
```

#### Restaurer uniquement un repo spécifique

```bash
# Extraire les données
tar xzf gitea_data.tar.gz

# Copier un repo spécifique
sudo cp -r gitea/data/gitea-repositories/jeremiealcaraz/mon-repo.git \
  /var/lib/gitea/data/gitea-repositories/jeremiealcaraz/

# Fixer les permissions
sudo chown -R gitea:gitea \
  /var/lib/gitea/data/gitea-repositories/jeremiealcaraz/mon-repo.git
```

#### Restaurer uniquement les clés SSH

```bash
tar xzf gitea_ssh_keys.tar.gz
sudo cp -r .ssh /var/lib/gitea/
sudo chown -R gitea:gitea /var/lib/gitea/.ssh
sudo chmod 700 /var/lib/gitea/.ssh
```

---

### Tester une restauration (sans impacter la prod)

#### Option 1 : Restauration sur une VM de test

1. Créer une VM NixOS avec la même config
2. Restaurer le backup sur cette VM
3. Tester que tout fonctionne
4. Détruire la VM si c'était juste un test

#### Option 2 : Restauration dans un namespace isolé

```bash
# Créer un dossier de test
sudo mkdir -p /tmp/gitea-test

# Extraire sans écraser la prod
tar xzf gitea_data.tar.gz -C /tmp/gitea-test/

# Inspecter le contenu
ls -lah /tmp/gitea-test/gitea/
```

---

### Problèmes courants et solutions

#### ❌ Erreur : "Database already exists"

```bash
# Vider la database avant de restaurer
sudo -u postgres psql -c "DROP DATABASE IF EXISTS gitea;"
sudo -u postgres psql -c "CREATE DATABASE gitea OWNER gitea;"
sudo -u postgres psql gitea < gitea_database.sql
```

#### ❌ Erreur : "Permission denied" lors de la restauration

```bash
# Fixer les permissions
sudo chown -R gitea:gitea /var/lib/gitea
sudo chmod 750 /var/lib/gitea
sudo chmod 750 /var/lib/gitea/data
```

#### ❌ Gitea ne démarre pas après restauration

```bash
# Voir les logs d'erreur
sudo journalctl -u gitea -n 100

# Vérifier les permissions de la database
sudo -u postgres psql -c "\du"
sudo -u postgres psql gitea -c "\dt"

# Vérifier la config
sudo cat /var/lib/gitea/custom/conf/app.ini
```

#### ❌ "Host key verification failed" après restauration

```bash
# Les clés SSH ont changé
# Sur les clients, supprimer l'ancienne clé
ssh-keygen -R "[dandelion]:2222"

# Réaccepter la nouvelle clé
ssh -p 2222 -T gitea@dandelion
```

#### ❌ "Repository not found" après restauration

```bash
# Reconstruire les métadonnées
sudo -u gitea gitea doctor --fix

# Recréer les hooks Git
sudo -u gitea gitea admin regenerate hooks
```

---

## 📋 Checklist de restauration

Utilise cette checklist pour une restauration sans stress :

### Avant la restauration

- [ ] Backup disponible (local ou téléchargé depuis GDrive)
- [ ] Hash SHA256 vérifié (`sha256sum -c`)
- [ ] Espace disque suffisant sur `/var/lib/gitea`
- [ ] PostgreSQL running
- [ ] Configuration NixOS déployée
- [ ] Backup de l'état actuel (si applicable)

### Pendant la restauration

- [ ] Gitea arrêté
- [ ] Database restaurée
- [ ] Données restaurées dans `/var/lib/gitea`
- [ ] Clés SSH restaurées
- [ ] Permissions fixées (`chown gitea:gitea`)
- [ ] Configuration vérifiée

### Après la restauration

- [ ] Gitea démarré
- [ ] HTTP fonctionne (`curl http://localhost:3000/`)
- [ ] SSH fonctionne (`ssh -p 2222 -T gitea@dandelion`)
- [ ] Repos accessibles (tester un `git clone`)
- [ ] Login admin fonctionne
- [ ] Actions Gitea fonctionnent (si utilisées)
- [ ] Webhooks fonctionnent (si utilisés)

---

## 🔗 Ressources

- **Plan d'implémentation** : `docs/plans/GITEA-BACKUP-PLAN.md`
- **Code source backup** : `hosts/dandelion/gitea-backup.nix`
- **Configuration Gitea** : `hosts/dandelion/configuration.nix`
- **Secrets chiffrés** : `secrets/dandelion.yaml` (éditer avec `sops`)

---

## 💡 Bonnes pratiques

1. **Tester régulièrement les restaurations** : Au moins une fois par trimestre
2. **Vérifier les notifications** : S'assurer que Slack/Email fonctionnent
3. **Monitorer l'espace disque** : Sur `/var/backups/gitea` et Google Drive
4. **Documenter les changements** : Noter les modifications de config
5. **Garder plusieurs backups** : Ne jamais dépendre d'un seul backup
6. **Chiffrer les secrets** : Toujours utiliser sops pour les secrets sensibles
7. **Tester les backups** : Vérifier l'intégrité avec SHA256

---

**Dernière mise à jour** : 2026-01-22
**Version Gitea** : 1.21.5
**Version PostgreSQL** : 16
**Version NixOS** : 25.05

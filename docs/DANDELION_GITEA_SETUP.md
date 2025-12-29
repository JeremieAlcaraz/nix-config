# Guide de déploiement: Gitea sur Dandelion 🌾

Ce guide explique comment déployer Gitea (serveur Git auto-hébergé) sur l'hôte dandelion.

## 📋 Vue d'ensemble

**Architecture:**
- **Gitea**: Serveur Git auto-hébergé (HTTP sur port 3000)
- **PostgreSQL 16**: Base de données backend
- **Tailscale**: Accès sécurisé via VPN (pas d'exposition publique)
- **SOPS**: Gestion des secrets (mot de passe admin)

**Flux de données:**
```
Utilisateur (via Tailscale) → http://dandelion:3000 → Gitea → PostgreSQL
```

**Caractéristiques:**
- Enregistrement désactivé (seul l'admin peut créer des comptes)
- Création automatique de l'utilisateur admin au premier démarrage
- Timeouts augmentés pour les miroirs GitHub
- Accès uniquement via Tailscale (sécurisé, pas d'exposition publique)

---

## 🚀 Installation complète (de zéro)

### Prérequis

- Une VM NixOS fraîchement installée
- Accès SSH à la VM
- Tailscale configuré sur ton réseau
- La clé age partagée (pour déchiffrer les secrets)

### Étape 1: Installation de NixOS sur la VM

1. **Créer la VM** (Proxmox, VirtualBox, etc.)
   - 2 CPU cores minimum
   - 4 GB RAM minimum
   - 20 GB disque minimum
   - Réseau: DHCP ou IP fixe

2. **Installer NixOS** avec l'ISO personnalisée:
   ```bash
   # Sur magnolia (machine de build)
   cd /etc/nixos
   nix build .#nixosConfigurations.installer.config.system.build.isoImage

   # Copier l'ISO sur la VM et booter dessus
   ```

3. **Générer la configuration hardware**:
   ```bash
   # Sur la VM (une fois bootée sur l'ISO)
   sudo nixos-generate-config --root /mnt

   # Copier le hardware-configuration.nix généré
   cat /mnt/etc/nixos/hardware-configuration.nix
   ```

4. **Remplacer le template hardware** dans le repo:
   ```bash
   # Sur ta machine de dev
   # Copier le contenu de hardware-configuration.nix dans:
   # hosts/dandelion/hardware-configuration.nix
   ```

### Étape 2: Configuration des secrets

**Sur ta machine de développement** (magnolia ou Mac):

1. **Créer le fichier de secrets**:
   ```bash
   cd /etc/nixos
   cp secrets/dandelion.yaml.example secrets/dandelion.yaml
   ```

2. **Éditer les secrets avec SOPS**:
   ```bash
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/key.txt
   sops secrets/dandelion.yaml
   ```

3. **Remplacer les valeurs**:
   ```yaml
   jeremie-password-hash: $6$...  # Générer avec: mkpasswd -m sha-512

   gitea:
     admin_password: "VotreSuperMotDePasse123!"  # Mot de passe fort
   ```

4. **Sauvegarder et vérifier le chiffrement**:
   ```bash
   # Sauvegarder dans sops (Ctrl+S puis :wq)

   # Vérifier que c'est chiffré
   cat secrets/dandelion.yaml | grep "sops:"
   # Devrait afficher des lignes avec "sops: ..."
   ```

5. **Committer les secrets chiffrés**:
   ```bash
   git add -f secrets/dandelion.yaml
   git commit -m "🔒 Add encrypted secrets for dandelion"
   git push
   ```

### Étape 3: Déploiement sur la VM

**Sur la VM dandelion:**

1. **Cloner la configuration**:
   ```bash
   sudo mkdir -p /etc/nixos
   sudo chown jeremie:users /etc/nixos
   cd /etc/nixos
   git clone https://github.com/JeremieAlcaraz/nix-config.git .
   ```

2. **Copier la clé age partagée**:
   ```bash
   # Option 1: Depuis magnolia via SSH
   scp magnolia:~/.config/sops/age/key.txt /tmp/key.txt

   # Option 2: Depuis le Mac
   scp marigold:~/.config/sops/age/key.txt /tmp/key.txt

   # Installer la clé
   sudo mkdir -p /var/lib/sops-nix
   sudo mv /tmp/key.txt /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   ```

3. **Activer la configuration**:
   ```bash
   cd /etc/nixos
   sudo nixos-rebuild switch --flake .#dandelion
   ```

4. **Rejoindre Tailscale**:
   ```bash
   # Le service Tailscale démarre automatiquement
   # Authentifier la machine
   sudo tailscale up

   # Suivre le lien affiché pour autoriser la machine dans ton réseau Tailscale
   ```

### Étape 4: Vérification

1. **Vérifier les services**:
   ```bash
   # PostgreSQL
   sudo systemctl status postgresql

   # Gitea
   sudo systemctl status gitea

   # Création de l'admin
   sudo systemctl status gitea-admin-setup
   ```

2. **Vérifier les logs**:
   ```bash
   # Logs Gitea
   sudo journalctl -u gitea -f

   # Logs PostgreSQL
   sudo journalctl -u postgresql -f

   # Logs création admin
   sudo journalctl -u gitea-admin-setup
   ```

3. **Tester l'accès**:
   ```bash
   # Depuis la VM elle-même
   curl http://localhost:3000

   # Depuis une autre machine sur Tailscale
   curl http://dandelion:3000
   ```

4. **Se connecter à l'interface web**:
   - Ouvrir un navigateur
   - Aller sur: `http://dandelion:3000`
   - Se connecter avec:
     - Username: `admin`
     - Password: (celui configuré dans secrets/dandelion.yaml)

---

## 🔧 Configuration post-installation

### Créer des utilisateurs supplémentaires

Gitea n'autorise pas l'enregistrement public. Pour créer des utilisateurs:

```bash
# En ligne de commande (SSH sur dandelion)
sudo -u gitea gitea admin user create \
  --username john \
  --password "MotDePasse123!" \
  --email john@example.com \
  --must-change-password

# Ou via l'interface web (en tant qu'admin)
# Settings → Users → Create New User
```

### Configurer des miroirs GitHub

Pour créer un miroir automatique d'un repo GitHub:

1. Se connecter en tant qu'admin
2. Cliquer sur "+" → "New Migration"
3. Choisir "GitHub"
4. Coller l'URL du repo: `https://github.com/user/repo`
5. Configurer les options:
   - ✅ This repository will be a mirror
   - Interval: 8h (ou selon préférence)
6. Cliquer sur "Migrate Repository"

**Note:** Les miroirs se synchronisent automatiquement selon l'intervalle configuré.

### Activer Git LFS (Large File Storage)

Si tu veux stocker des fichiers volumineux:

```nix
# Dans hosts/dandelion/configuration.nix
services.gitea = {
  # ... config existante ...

  lfs = {
    enable = true;
    contentDir = "/var/lib/gitea/data/lfs";
  };
};
```

Puis rebuild:
```bash
sudo nixos-rebuild switch --flake .#dandelion
```

---

## 📝 Fichiers importants

### Structure du projet

```
nix-config/
├── flake.nix                          # Définit dandelion dans nixosConfigurations
├── hosts/dandelion/
│   ├── configuration.nix              # Config principale + Gitea
│   └── hardware-configuration.nix     # Config matériel (à remplacer après install)
├── secrets/
│   ├── dandelion.yaml                 # Secrets chiffrés (SOPS)
│   └── dandelion.yaml.example         # Template pour nouveaux secrets
└── docs/
    └── DANDELION_GITEA_SETUP.md       # Ce fichier !
```

### Ports utilisés

- **3000**: Gitea HTTP (accessible via Tailscale)
- **22**: SSH (pour `git push/pull` via SSH)
- **5432**: PostgreSQL (localhost uniquement)

---

## 🐛 Dépannage

### Problème: L'utilisateur admin n'est pas créé

**Vérifier les logs:**
```bash
sudo journalctl -u gitea-admin-setup
```

**Créer l'admin manuellement:**
```bash
# Lire le mot de passe depuis les secrets
ADMIN_PASS=$(sudo cat /run/secrets/gitea/admin_password | tr -d '\n"' | xargs)

# Créer l'admin
sudo -u gitea gitea admin user create \
  --username admin \
  --password "$ADMIN_PASS" \
  --email admin@dandelion.local \
  --admin
```

### Problème: Gitea ne démarre pas

**Vérifier PostgreSQL:**
```bash
sudo systemctl status postgresql

# Vérifier que la base existe
sudo -u postgres psql -l | grep gitea
```

**Réinitialiser Gitea:**
```bash
# Arrêter Gitea
sudo systemctl stop gitea

# Nettoyer la base (ATTENTION: perte de données !)
sudo -u postgres psql -c "DROP DATABASE gitea;"
sudo -u postgres psql -c "CREATE DATABASE gitea OWNER gitea;"

# Redémarrer
sudo systemctl start gitea
```

### Problème: Impossible d'accéder via Tailscale

**Vérifier Tailscale:**
```bash
# Status Tailscale
sudo tailscale status

# Vérifier l'IP Tailscale
ip addr show tailscale0

# Tester depuis une autre machine
ping dandelion  # (si MagicDNS est activé)
```

**Vérifier le firewall:**
```bash
# Le port 3000 doit être ouvert
sudo iptables -L -n | grep 3000
```

### Problème: Git push/pull échoue en SSH

**Vérifier le service SSH:**
```bash
sudo systemctl status sshd

# Tester la connexion SSH
ssh git@dandelion
```

**Configurer les clés SSH:**
```bash
# Dans Gitea, aller dans Settings → SSH / GPG Keys
# Ajouter ta clé publique SSH
```

---

## 🔐 Sécurité

### Bonnes pratiques

1. **Mot de passe admin fort**: Utiliser un gestionnaire de mots de passe
2. **Accès Tailscale uniquement**: Ne pas exposer Gitea publiquement
3. **Backups réguliers**: Sauvegarder PostgreSQL et /var/lib/gitea
4. **Mises à jour**: Rebuild régulièrement pour les mises à jour de sécurité

### Backup automatique

Créer un timer systemd pour backup quotidien:

```nix
# Dans hosts/dandelion/configuration.nix
systemd.services."backup-gitea" = {
  description = "Backup Gitea database and data";
  script = ''
    BACKUP_DIR="/var/backup/gitea"
    TIMESTAMP=$(date +%F_%H-%M-%S)

    mkdir -p "$BACKUP_DIR"

    # Backup PostgreSQL
    ${pkgs.sudo}/bin/sudo -u postgres ${pkgs.postgresql}/bin/pg_dump gitea | \
      ${pkgs.gzip}/bin/gzip > "$BACKUP_DIR/gitea-db-$TIMESTAMP.sql.gz"

    # Backup data directory
    ${pkgs.gzip}/bin/gzip -c \
      <(${pkgs.gnutar}/bin/tar -C /var/lib -cf - gitea) \
      > "$BACKUP_DIR/gitea-data-$TIMESTAMP.tar.gz"

    # Garder les 7 derniers backups
    cd "$BACKUP_DIR"
    ls -t gitea-*.gz | tail -n +8 | xargs -r rm
  '';
  serviceConfig = {
    Type = "oneshot";
    User = "root";
  };
};

systemd.timers."backup-gitea" = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
};
```

---

## ✅ Checklist de déploiement

### Préparation
- [ ] VM créée et NixOS installé
- [ ] Hardware configuration récupérée
- [ ] Secrets créés et chiffrés avec SOPS
- [ ] Clé age partagée disponible
- [ ] Configuration commitée et pushée

### Déploiement
- [ ] Configuration clonée sur la VM
- [ ] Clé age copiée sur la VM
- [ ] `nixos-rebuild switch` réussi
- [ ] Tailscale configuré et connecté
- [ ] Services PostgreSQL et Gitea actifs

### Vérification
- [ ] Accès à http://dandelion:3000 fonctionnel
- [ ] Connexion admin réussie
- [ ] Création d'un repo test réussie
- [ ] Git clone/push/pull fonctionnel
- [ ] Backup configuré (si souhaité)

---

## 📚 Ressources

- [Gitea Documentation](https://docs.gitea.io/)
- [NixOS Gitea Options](https://search.nixos.org/options?query=services.gitea)
- [PostgreSQL NixOS](https://search.nixos.org/options?query=services.postgresql)
- [Tailscale](https://tailscale.com/kb/)
- [SOPS-nix](https://github.com/Mic92/sops-nix)

---

**Créé le:** 2025-12-13
**Auteur:** Jérémie Alcaraz (avec l'aide de Claude)

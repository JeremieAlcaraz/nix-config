# 📘 Guide de déploiement NixOS

Guide complet pour créer et déployer des VMs NixOS de manière **100% reproductible**.

## 🎯 Principes de base

Ce repo utilise une approche **standardisée** pour toutes les VMs :
- **Labels de disque fixes** : `nixos-root` (partition racine) et `ESP` (partition boot)
- **Configuration déclarative** : Tout est dans le code, rien n'est manuel
- **Clonage facile** : Les VMs peuvent être clonées sans modification

---

## 📦 Workflow 1 : Installation depuis zéro (VM neuve)

### Prérequis
- VM créée dans Proxmox avec au minimum :
  - 2 CPU, 2 Go RAM, 32 Go de disque
  - Boot UEFI activé
  - ISO NixOS bootée

### Installation automatique avec le script

```bash
# 1. Depuis l'ISO NixOS, télécharger le script
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh

# 2. Lancer l'installation (remplacer HOST par magnolia ou mimosa)
sudo ./install.sh magnolia
```

Le script va :
1. ✅ Partitionner le disque avec les labels standards
2. ✅ Formater en ext4 + FAT32
3. ✅ Cloner ce repo
4. ✅ Installer NixOS avec la config de l'host choisi
5. ✅ Tout nettoyer

### Après l'installation

```bash
# 1. Retirer l'ISO dans Proxmox (Hardware > CD/DVD > Remove)
# 2. Redémarrer
reboot

# 3. Trouver l'IP de la VM
ip a

# 4. Se connecter depuis votre Mac/PC
ssh jeremie@IP_DE_LA_VM
```

**Mot de passe initial** : `nixos` (changez-le immédiatement avec `passwd`)

---

## 🔄 Workflow 2 : Clonage d'une VM existante (RECOMMANDÉ)

**C'est le workflow le plus rapide et le plus fiable !**

### Étape 1 : Cloner la VM dans Proxmox

1. Dans Proxmox, faites un clic droit sur une VM existante (ex: `magnolia`)
2. Cliquez sur **"Clone"**
3. Choisissez :
   - **Mode** : Full Clone (clone complet)
   - **Nom** : Le nouveau nom (ex: `mimosa`)
   - **VM ID** : Un ID libre

### Étape 2 : Démarrer et reconfigurer

```bash
# 1. Démarrer la VM clonée dans Proxmox

# 2. Se connecter en SSH (utilisez l'IP de la nouvelle VM)
ssh jeremie@IP_NOUVELLE_VM

# 3. Aller dans /etc/nixos (le repo est déjà là !)
cd /etc/nixos

# 4. Pull les dernières modifications
git pull

# 5. Appliquer la nouvelle configuration
sudo nixos-rebuild switch --flake .#mimosa

# 6. Redémarrer pour que le hostname soit appliqué
sudo reboot
```

### Étape 3 : Vérification

```bash
# Se reconnecter
ssh jeremie@IP_NOUVELLE_VM

# Vérifier le hostname
hostnamectl
# Devrait afficher : Static hostname: mimosa

# Vérifier la config
cat /etc/nixos/hosts/mimosa/configuration.nix | grep hostName
```

**✅ C'est tout ! Votre VM est prête.**

---

## 🔧 Workflow 3 : Déploiement de changements

Une fois la VM installée/clonée, voici comment déployer des modifications :

### Depuis votre Mac/PC (développement)

```bash
# 1. Faire vos modifications dans le repo local
cd ~/nix-config
vim hosts/mimosa/configuration.nix

# 2. Commit et push
git add .
git commit -m "Update mimosa config"
git push
```

### Depuis la VM (déploiement)

```bash
# 1. Se connecter à la VM
ssh jeremie@IP_DE_LA_VM

# 2. Pull les changements
cd /etc/nixos
git pull

# 3. Tester la config avant de l'appliquer (optionnel)
sudo nixos-rebuild test --flake .#mimosa

# 4. Appliquer définitivement
sudo nixos-rebuild switch --flake .#mimosa
```

**Note** : La plupart des changements sont appliqués immédiatement. Seuls quelques paramètres (comme le hostname) nécessitent un redémarrage.

---

## 🆕 Créer un nouvel host

### 1. Créer la structure de base

```bash
# Créer le dossier
mkdir -p hosts/mon-nouveau-host

# Copier les fichiers depuis un host existant
cp hosts/mimosa/configuration.nix hosts/mon-nouveau-host/
cp hosts/mimosa/hardware-configuration.nix hosts/mon-nouveau-host/
```

### 2. Modifier la configuration

```bash
# Éditer configuration.nix
vim hosts/mon-nouveau-host/configuration.nix

# Changer au minimum :
networking.hostName = "mon-nouveau-host";
```

### 3. Ajouter dans flake.nix

```nix
nixosConfigurations = {
  # ... configurations existantes ...

  mon-nouveau-host = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ./hosts/mon-nouveau-host/configuration.nix
      # Ajoutez les modules nécessaires (sops-nix, etc.)
    ];
  };
};
```

### 4. Déployer

```bash
# Méthode 1 : Installation depuis zéro
sudo ./scripts/install-nixos.sh mon-nouveau-host

# Méthode 2 : Depuis une VM clonée
sudo nixos-rebuild switch --flake .#mon-nouveau-host
```

---

## ⚠️ Points importants

### Labels de disque standardisés

**TOUTES les VMs de ce repo utilisent les mêmes labels** :
- `/dev/disk/by-label/nixos-root` → Partition racine (ext4)
- `/dev/disk/by-label/ESP` → Partition boot (FAT32)

✅ **Avantage** : Les VMs peuvent être clonées sans modifier `hardware-configuration.nix`

❌ **Ne jamais** utiliser d'autres labels (comme `nixos` ou `boot`)

### Hostname vs Configuration

Le **hostname de la VM** doit correspondre au **nom dans flake.nix** :

| Hostname dans Proxmox | Commande nixos-rebuild | Fichier config |
|----------------------|------------------------|----------------|
| `magnolia` | `--flake .#magnolia` | `hosts/magnolia/` |
| `mimosa` | `--flake .#mimosa` | `hosts/mimosa/` |

### Changement de hostname

Le hostname est appliqué **au boot**. Après un `nixos-rebuild switch` avec un nouveau hostname :

```bash
# Appliquer immédiatement (temporaire)
sudo hostnamectl set-hostname nouveau-nom

# OU redémarrer (permanent)
sudo reboot
```

---

## 🔑 Informations de connexion

### Par défaut sur toutes les VMs

- **Utilisateur** : `jeremie`
- **Mot de passe initial** : `nixos` (changez-le avec `passwd`)
- **SSH** : Authentification par clé publique uniquement
- **Sudo** : Pas de mot de passe requis pour le groupe `wheel`

### Clé SSH autorisée

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
```

---

## 🐛 Dépannage

### Erreur "Can't lookup blockdev" au boot

**Cause** : Les labels de disque ne correspondent pas.

**Solution** :
1. Vérifier les labels : `lsblk -f`
2. Vérifier `hardware-configuration.nix` utilise bien `nixos-root` et `ESP`
3. Si besoin, reformater avec les bons labels :
   ```bash
   sudo mkfs.ext4 -L nixos-root /dev/sda2
   sudo mkfs.vfat -F32 -n ESP /dev/sda1
   ```

### La VM a toujours le hostname "nixos"

**Cause** : Le hostname n'a pas été appliqué ou vous n'avez pas redémarré.

**Solution** :
```bash
# Vérifier que la config a le bon hostname
grep hostName /etc/nixos/hosts/*/configuration.nix

# Vérifier que vous avez bien utilisé le bon nom d'host
# Mauvais : nixos-rebuild switch --flake .#
# Bon : nixos-rebuild switch --flake .#mimosa

# Redémarrer
sudo reboot
```

### Git pull échoue dans /etc/nixos

**Cause** : Le repo a des modifications locales ou est sur une branche différente.

**Solution** :
```bash
cd /etc/nixos
git status
git stash  # sauvegarder les modifs locales
git pull
git stash pop  # restaurer les modifs
```

---

## 📚 Documentation complémentaire

- [BOOTSTRAP.md](./BOOTSTRAP.md) - Guide d'installation détaillé et bootstrap
- [SECRETS.md](./SECRETS.md) - Gestion des secrets avec sops-nix
- [README.md](../README.md) - Vue d'ensemble du projet

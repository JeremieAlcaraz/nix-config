# 💿 Builder une ISO NixOS minimale pour Proxmox/NoVNC

Ce guide détaille comment générer et utiliser une ISO NixOS minimale personnalisée avec support de la console série (ttyS0), optimisée pour une utilisation dans Proxmox avec NoVNC.

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Prérequis](#-prérequis)
- [Construction de l'ISO](#-construction-de-liso)
  - [Depuis une VM NixOS](#depuis-une-vm-nixos)
  - [Depuis un système NixOS local](#depuis-un-système-nixos-local)
- [Utilisation de l'ISO](#-utilisation-de-liso)
- [Détails techniques](#-détails-techniques)
- [Personnalisation](#-personnalisation)
- [Dépannage](#-dépannage)

---

## 🎯 Vue d'ensemble

Cette ISO personnalisée résout un problème courant lors de l'utilisation de NixOS dans Proxmox avec NoVNC : **l'accès à un terminal fonctionnel dès le boot**.

### Le problème

Quand vous démarrez l'ISO NixOS standard en mode graphique sous Proxmox/NoVNC :
- Le framebuffer VGA affiche une console graphique "muette"
- Il n'y a pas de TTY actif utilisable
- Des outils comme `xterm` ne fonctionnent pas correctement

### La solution

En activant la **console série (ttyS0)** dès le boot avec le paramètre `console=ttyS0,115200n8` :
- Le noyau Linux redirige toute la console système vers le port série
- systemd démarre un getty sur ce terminal série
- NoVNC ou la console Proxmox voit un **terminal texte réel** (lié à `/dev/ttyS0`)
- Les outils comme `xterm` peuvent s'attacher à un vrai TTY

### Caractéristiques de l'ISO

✅ **Console série active automatiquement** (ttyS0 à 115200 baud)
✅ **Autologin** en tant qu'utilisateur `nixos`
✅ **Environnement X11 minimal** avec `xterm` et `twm`
✅ **ZSH + Starship** pour un shell moderne
✅ **Outils de base** : vim, git, curl, wget, htop, tree
✅ **SSH activé** avec authentification par mot de passe (pour debug)
✅ **Réseau DHCP** configuré automatiquement

---

## 🔧 Prérequis

### Pour builder l'ISO

Vous aurez besoin :

1. **NixOS avec flakes activés** (version 23.05 ou plus récente)
2. **Espace disque suffisant** (~5 GB pour le build)
3. **Accès internet** pour télécharger les dépendances
4. **Ce repository** cloné localement

### Activer les flakes (si nécessaire)

Si les flakes ne sont pas encore activés sur votre système :

```bash
# Créer ou éditer /etc/nixos/configuration.nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];

# Reconstruire le système
sudo nixos-rebuild switch
```

Ou utilisez temporairement les flakes sans les activer globalement :

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

---

## 🏗️ Construction de l'ISO

### Depuis une VM NixOS

C'est la méthode recommandée si vous travaillez déjà dans Proxmox.

#### 1. Créer une VM NixOS temporaire

Dans Proxmox :
1. Téléchargez l'ISO NixOS standard : [nixos.org/download](https://nixos.org/download)
2. Créez une nouvelle VM avec :
   - **CPU** : 4 cores minimum
   - **RAM** : 8 GB minimum
   - **Disque** : 20 GB minimum
   - **Réseau** : Bridge ou NAT avec accès internet

#### 2. Installer NixOS dans la VM

Bootez sur l'ISO et suivez l'installation minimale :

```bash
# 1. Partitionner le disque (exemple simple avec tout sur une partition)
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart primary 1MiB 100%
sudo mkfs.ext4 -L nixos /dev/sda1

# 2. Monter et préparer
sudo mount /dev/disk/by-label/nixos /mnt
sudo nixos-generate-config --root /mnt

# 3. Éditer la configuration pour activer les flakes
sudo nano /mnt/etc/nixos/configuration.nix
# Ajouter : nix.settings.experimental-features = [ "nix-command" "flakes" ];

# 4. Installer
sudo nixos-install

# 5. Redémarrer
sudo reboot
```

#### 3. Cloner ce repository

Une fois NixOS installé et redémarré :

```bash
# Installer git si nécessaire
nix-shell -p git

# Cloner le repo
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config/iso
```

#### 4. Builder l'ISO

```bash
# Se placer dans le dossier iso/
cd ~/nix-config/iso

# Builder l'ISO (prend 10-30 minutes selon la machine)
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage
```

Le build va :
1. Télécharger toutes les dépendances NixOS nécessaires
2. Construire l'image ISO personnalisée
3. Créer un lien symbolique `result` pointant vers l'ISO

#### 5. Récupérer l'ISO

L'ISO se trouve dans :

```bash
ls -lh result/iso/*.iso
# Exemple : result/iso/nixos-minimal-ttyS0.iso
```

Pour la copier ailleurs :

```bash
# Copier vers un dossier accessible
cp result/iso/nixos-minimal-ttyS0.iso ~/

# Ou directement vers un serveur via SCP
scp result/iso/nixos-minimal-ttyS0.iso user@server:/path/to/destination/
```

#### 6. Télécharger l'ISO depuis Proxmox

Depuis l'interface web Proxmox, vous pouvez :

**Option A : Via SCP/SFTP**
```bash
# Depuis un autre système, récupérer l'ISO
scp root@vm-nixos-builder:~/nix-config/iso/result/iso/*.iso ./
```

**Option B : Upload direct dans Proxmox**
1. Allez dans **Datacenter > Storage > local**
2. Cliquez sur **ISO Images**
3. Uploadez l'ISO depuis votre machine locale

---

### Depuis un système NixOS local

Si vous avez déjà NixOS sur votre machine :

```bash
# 1. Cloner le repo
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config/iso

# 2. Builder l'ISO
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage

# 3. L'ISO est dans result/iso/
ls -lh result/iso/
```

---

## 🚀 Utilisation de l'ISO

### 1. Upload dans Proxmox

1. Connectez-vous à l'interface web Proxmox
2. Allez dans **Datacenter > [votre-node] > local (pve)**
3. Onglet **ISO Images**
4. Cliquez **Upload** et sélectionnez votre ISO

### 2. Créer une VM de test

```bash
# Exemple de création de VM via CLI Proxmox
qm create 999 \
  --name test-iso-nixos \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --cdrom local:iso/nixos-minimal-ttyS0.iso \
  --boot order=cdrom

# Démarrer la VM
qm start 999
```

Ou via l'interface web :
1. Clic droit sur le nœud > **Create VM**
2. Configurez la VM
3. Dans **OS**, sélectionnez votre ISO personnalisée
4. Terminez la création et démarrez

### 3. Accéder à la console

#### Via NoVNC (interface web)

1. Sélectionnez votre VM dans l'interface Proxmox
2. Cliquez sur **Console** (bouton en haut)
3. Vous devriez voir le boot automatique avec TTY série actif

#### Via console série (recommandé)

```bash
# Depuis le shell Proxmox
qm terminal 999
```

### 4. Utiliser l'ISO

Une fois bootée, vous êtes automatiquement connecté en tant qu'utilisateur `nixos`.

**Démarrer l'interface graphique :**
```bash
startx
```

Cela lance :
- `twm` (Tiny Window Manager)
- `xterm` (terminal graphique)

**Installer NixOS :**
```bash
# L'ISO contient tous les outils d'installation standard
sudo nixos-install
```

---

## 🔬 Détails techniques

### Paramètres de boot

```nix
boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
```

- **`console=ttyS0,115200n8`** :
  - `ttyS0` : premier port série
  - `115200` : vitesse en bauds (standard pour les consoles modernes)
  - `n8` : No parity, 8 bits (configuration série standard)

- **`console=tty1`** :
  - Garde aussi la console VGA/graphique standard active
  - Permet d'utiliser l'ISO sur du matériel physique sans port série

### Architecture de l'ISO

```
ISO NixOS personnalisée
├── Kernel Linux avec params série
├── initrd avec drivers série
├── Système de base NixOS
│   ├── Getty sur ttyS0 (autologin: nixos)
│   ├── Getty sur tty1
│   └── Getty sur tty2
├── Environnement X11
│   ├── xterm
│   ├── twm (window manager)
│   └── xinit
└── Outils supplémentaires
    ├── ZSH + Starship
    ├── vim, git, curl, wget
    └── SSH server
```

### Comparaison : ISO standard vs personnalisée

| Aspect | ISO standard | ISO personnalisée |
|--------|-------------|-------------------|
| Console série | ❌ Désactivée par défaut | ✅ Active dès le boot |
| TTY utilisable dans NoVNC | ⚠️ Nécessite menu GRUB | ✅ Automatique |
| Autologin | ❌ Login manuel | ✅ User `nixos` auto |
| Shell | Bash basique | ZSH + Starship |
| Interface graphique | Aucune | xterm + twm |
| Taille ISO | ~800 MB | ~950 MB |

---

## 🎨 Personnalisation

Le fichier `iso/flake.nix` est entièrement modulable.

### Ajouter des packages

```nix
environment.systemPackages = with pkgs; [
  # Vos packages personnalisés
  tmux
  neovim
  ranger
  # ...
];
```

### Changer le shell par défaut

```nix
users.users.nixos = {
  shell = pkgs.bash;  # ou pkgs.fish, pkgs.zsh, etc.
};
```

### Activer des services supplémentaires

```nix
# Exemple : Tailscale pour VPN automatique
services.tailscale.enable = true;
```

### Changer le nom de l'ISO

```nix
isoImage = {
  isoName = "mon-iso-custom.iso";
  volumeID = "MY_CUSTOM_ISO";
  appendToMenuLabel = " (Ma config perso)";
};
```

### Rebuild après modification

```bash
# Rebuild après changements
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage

# Vérifier la nouvelle ISO
ls -lh result/iso/
```

---

## 🛠️ Dépannage

### Le build échoue avec "out of disk space"

**Solution** : Libérez de l'espace ou utilisez un disque plus grand

```bash
# Nettoyer le store Nix
nix-collect-garbage -d

# Vérifier l'espace libre
df -h /nix
```

### Le build est très lent

**Solution** : Augmentez les ressources de la VM

- **CPU** : Passez à 4-6 cores
- **RAM** : Augmentez à 8-16 GB

### L'ISO ne boot pas dans Proxmox

**Vérifiez** :

1. La VM est configurée en **BIOS** (pas UEFI) ou l'inverse selon votre config
2. L'ordre de boot inclut bien le CD-ROM
3. L'ISO n'est pas corrompue :
   ```bash
   sha256sum result/iso/*.iso
   ```

### xterm ne se lance pas après startx

**Cause probable** : Problème X11

**Debug** :
```bash
# Vérifier les logs X
cat ~/.local/share/xorg/Xorg.0.log

# Tester manuellement
startx -- :1
```

### SSH ne fonctionne pas

**Vérifiez** :

```bash
# Le service est actif
systemctl status sshd

# Le port est ouvert
ss -tlnp | grep 22

# Firewall Proxmox
# (depuis l'hôte Proxmox)
iptables -L -n | grep 22
```

### Je n'ai pas accès réseau

**Solution** :

```bash
# Vérifier les interfaces
ip addr

# Redémarrer NetworkManager
sudo systemctl restart NetworkManager

# Debug DHCP
sudo dhclient -v
```

---

## 📚 Ressources additionnelles

- [NixOS Manual - Building ISO Images](https://nixos.org/manual/nixos/stable/#sec-building-image)
- [NixOS Wiki - ISO Image](https://nixos.wiki/wiki/Creating_a_NixOS_live_CD)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Serial Console Linux HOWTO](https://tldp.org/HOWTO/Serial-Console-HOWTO/)

---

## 🤝 Contribution

Des suggestions pour améliorer cette ISO ou ce guide ? N'hésite pas à ouvrir une issue ou une PR !

---

**Note** : Cette ISO est conçue pour un usage de développement et de test. Pour un usage en production, désactive l'authentification SSH par mot de passe et configure des clés SSH appropriées.

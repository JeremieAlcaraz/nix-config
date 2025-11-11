# ISO NixOS personnalisée

ISO d'installation NixOS optimisée pour ce projet, avec :
- ✅ Flakes activés par défaut
- ✅ DNS publics (1.1.1.1, 8.8.8.8) configurés automatiquement
- ✅ Outils de diagnostic réseau inclus (bind, dnsutils, etc.)
- ✅ Scripts d'installation pré-installés

## 🏗️ Builder l'ISO

Depuis la racine du projet :

```bash
# Builder l'ISO (prend ~10-15 minutes)
nix build .#nixosConfigurations.installer.config.system.build.isoImage

# L'ISO sera dans result/iso/
ls -lh result/iso/*.iso
```

## 📤 Uploader l'ISO sur Proxmox

### Option 1 : Via SCP

```bash
# Depuis votre machine où vous avez buildé l'ISO
scp result/iso/nixos-*.iso root@proxmox:/var/lib/vz/template/iso/
```

### Option 2 : Via l'interface web Proxmox

1. Aller dans **Datacenter** > **Storage** > **local (pve)** > **ISO Images**
2. Cliquer sur **Upload**
3. Sélectionner l'ISO buildée

## 🚀 Utiliser l'ISO

### 1. Créer ou configurer la VM dans Proxmox

```bash
# Attacher l'ISO à la VM
qm set <VMID> --ide2 local:iso/nixos-nix-config-installer-*.iso,media=cdrom

# Démarrer la VM
qm start <VMID>
```

### 2. Une fois bootée dans l'ISO

Les scripts sont déjà disponibles dans `/etc/installer/scripts/` !

```bash
# Diagnostic réseau
sudo /etc/installer/scripts/diagnose-network.sh

# Installation
sudo /etc/installer/scripts/install-nixos.sh mimosa
```

## ✨ Avantages de l'ISO personnalisée

| Problème | ISO vanilla | ISO personnalisée |
|----------|-------------|-------------------|
| Flakes | ❌ Désactivés par défaut | ✅ Activés |
| DNS | ⚠️ Via DHCP (peut être absent) | ✅ DNS publics configurés |
| Outils diagnostic | ❌ À installer | ✅ Pré-installés |
| Scripts | ❌ À télécharger | ✅ Inclus dans l'ISO |
| Message d'aide | ❌ Generic | ✅ Personnalisé |

## 🔄 Mettre à jour l'ISO

Quand vous modifiez les scripts d'installation :

```bash
# 1. Rebuild l'ISO avec les derniers scripts
nix build .#nixosConfigurations.installer.config.system.build.isoImage

# 2. Uploader la nouvelle version sur Proxmox
scp result/iso/nixos-*.iso root@proxmox:/var/lib/vz/template/iso/

# 3. Utiliser la nouvelle ISO pour les prochaines installations
```

## 📝 Notes

- L'ISO fait environ 800MB-1GB (selon les packages inclus)
- Le build nécessite ~2GB d'espace disque temporaire
- Compatible x86_64 uniquement (modifiable dans flake.nix si besoin)

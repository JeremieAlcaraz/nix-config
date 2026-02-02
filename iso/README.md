# 🏗️ ISO Builder - NixOS Custom

ISO personnalisée NixOS optimisée pour Proxmox avec console série (ttyS0) et environnement d'installation ergonomique.

## 🚀 Quick Start

```bash
# Builder l'ISO (synchronisée avec le flake principal)
./build-iso.sh

# Ou mettre à jour vers la dernière version nixpkgs
./build-iso.sh --update

# Aide
./build-iso.sh --help
```

**Résultat** : `nixos-installer-ttyS0-YYYY-MM-DD.iso` (~600-900 MB) dans le dossier `iso/`.

## 📋 Pourquoi rebuilder l'ISO ?

### ❌ Sans ISO à jour
```
ISO ancienne (novembre 2024)
     ↓
Installation VM (janvier 2025)
     ↓
Gap de 2+ mois = Télécharge TOUS les packages mis à jour
     ↓
Temps: 5-8 minutes ⚠️
```

### ✅ Avec ISO à jour
```
ISO récente (même version que le flake)
     ↓
Installation VM
     ↓
Pas de gap = Télécharge uniquement les nouveaux packages
     ↓
Temps: 2-3 minutes ✅
```

**Gain** : 3-5 minutes par installation ! 🚀

## 🔧 Configuration de l'ISO

Cette ISO contient :

- ✅ **Console série (ttyS0)** : Compatible Proxmox/NoVNC
- ✅ **Environnement X11 minimal** : xterm + twm
- ✅ **ZSH + Starship** : Shell moderne et ergonomique
- ✅ **Autologin** : Utilisateur `nixos` (pas de mot de passe)
- ✅ **SSH activé** : Port 22, login root avec mot de passe vide
- ✅ **DHCP** : Configuration réseau automatique
- ✅ **DNS publics** : 1.1.1.1 + 8.8.8.8 pré-configurés
- ✅ **Scripts d'installation** : Accès direct au repo

## 📦 Contenu

```
iso/
├── flake.nix              # Configuration ISO
├── custom-installer.nix   # Modules personnalisés
├── build-iso.sh           # Script de build automatisé
├── flake.lock             # Versions verrouillées
└── README.md              # Ce fichier
```

## 🛠️ Build manuel (sans script)

Si tu préfères faire le build à la main :

```bash
# Mettre à jour nixpkgs
nix flake update

# Ou synchroniser avec le flake principal
MAIN_REV=$(cd .. && jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$MAIN_REV"

# Builder l'ISO
nix build .#nixosConfigurations.iso-installer-ttyS0.config.system.build.isoImage

# Résultat
ls -lh result/iso/*.iso
```

## 📤 Upload sur Proxmox

### Via SCP (recommandé)

```bash
# Copier vers Downloads
cp nixos-installer-ttyS0-YYYY-MM-DD.iso ~/Downloads/

# Upload vers Proxmox
scp ~/Downloads/nixos-installer-ttyS0-YYYY-MM-DD.iso root@proxmox:/var/lib/vz/template/iso/
```

### Via Web UI

1. Aller sur Proxmox Web UI
2. Datacenter → Storage → local
3. Upload → Sélectionner l'ISO
4. Attendre la fin de l'upload

## 🎬 Utiliser l'ISO

```bash
# Attacher à une VM (remplace 100 par ton VMID)
qm set 100 --ide2 local:iso/nixos-installer-ttyS0-YYYY-MM-DD.iso,media=cdrom

# Démarrer la VM
qm start 100

# Une fois dans l'ISO, lancer l'install
sudo ./scripts/install-nixos.sh
```

## ⏱️ Performances

### Temps de build (première fois)

| Machine | Temps |
|---------|-------|
| Mac M1/M2 | 8-12 min |
| Magnolia (4 cores) | 10-15 min |

### Temps de build (rebuild après update)

| Machine | Temps |
|---------|-------|
| Mac M1/M2 | 3-5 min |
| Magnolia (4 cores) | 5-8 min |

### Temps d'installation avec ISO

| Avec ISO | Temps |
|----------|-------|
| ISO à jour | 2-3 min ✅ |
| ISO ancienne (2+ mois) | 5-8 min ⚠️ |

## 🔍 Troubleshooting

### Erreur "platform mismatch" sur macOS

Si tu es sur macOS et que le build échoue :

```bash
# Option 1: Builder sur magnolia
ssh magnolia
cd /etc/nixos/iso
./build-iso.sh

# Option 2: Utiliser remote builder (avancé)
# Voir docs/BUILD-OPTIMIZATION.md
```

### Build très lent

```bash
# Vérifier que les caches sont utilisés
nix build ... --print-build-logs 2>&1 | grep -E 'copying|building'

# Devrait voir beaucoup de "copying path" (téléchargement)
# Peu de "building" (compilation)
```

### Out of disk space

```bash
# Libérer de l'espace
nix-collect-garbage -d

# Vérifier l'espace disponible
df -h
```

## 📅 Quand rebuilder ?

- ✅ Tous les 1-2 mois (quand nixpkgs a avancé)
- ✅ Avant une grosse session d'installation de VMs
- ✅ Après une mise à jour majeure (24.11 → 25.05)
- ❌ Pas besoin à chaque petit changement

## 📚 Documentation

Voir [docs/BUILD-ISO.md](../docs/BUILD-ISO.md) pour le guide concis.

## 🆘 Besoin d'aide ?

- Guide : `docs/BUILD-ISO.md`
- Optimisation builds : `docs/BUILD-OPTIMIZATION.md`
- Config ISO : `iso/custom-installer.nix`

---

**Astuce** : Lance `./build-iso.sh` une fois par mois pour garder une ISO à jour ! ⏰

# 🔄 Guide : Rebuilder une ISO NixOS à jour

## 🎯 Objectif

Créer une ISO mise à jour avec la même version de nixpkgs que ton flake principal pour des installations ultra-rapides (~2-3 min au lieu de 5-8 min).

## 📋 Prérequis

- macOS avec Nix installé (ton Mac)
- OU magnolia avec accès SSH
- ~2 GB d'espace disque libre
- Connexion internet stable

---

## 🚀 Étape 1 : Vérifier la version actuelle

### Sur ton ISO actuelle (optionnel)

Si tu veux voir à quel point elle est vieille :

```bash
# Depuis l'ISO bootée dans Proxmox
nixos-version --json | jq -r '.nixosVersion'

# Exemple de sortie:
# "24.11.20241115.abc123"
#        ^^^^^^^^ = Date de build (15 nov 2024)
```

### Dans ton repo principal

```bash
cd ~/nix-config  # Sur ton Mac
jq -r '.nodes.nixpkgs.locked.rev' flake.lock

# Sortie actuelle: 50ab793786d9de88ee30ec4e4c24fb4236fc2674
```

---

## 🔧 Étape 2 : Préparer le dossier ISO

```bash
# Sur ton Mac
cd ~/nix-config/iso

# Vérifier qu'on a bien le flake ISO
ls -la flake.nix
# Devrait afficher le fichier flake.nix de l'ISO
```

---

## 📦 Étape 3 : Mettre à jour vers nixpkgs récent

### Option A : Utiliser la même version que le flake principal (RECOMMANDÉ)

```bash
cd ~/nix-config/iso

# Copier la version exacte du flake principal
NIXPKGS_REV=$(cd .. && jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
echo "Version à utiliser: $NIXPKGS_REV"

# Mettre à jour flake.lock pour pointer vers cette version
nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_REV"

# Vérifier que c'est bien à jour
jq -r '.nodes.nixpkgs.locked.rev' flake.lock
# Devrait afficher: 50ab793786d9de88ee30ec4e4c24fb4236fc2674
```

### Option B : Mettre à jour vers la toute dernière version

```bash
cd ~/nix-config/iso

# Mettre à jour vers la dernière version de nixpkgs 24.11
nix flake update

# Vérifier la nouvelle version
jq -r '.nodes.nixpkgs.locked | "\(.lastModified) = \(.rev)"' flake.lock
```

---

## 🏗️ Étape 4 : Builder la nouvelle ISO

### Sur macOS (ton Mac)

⚠️ **IMPORTANT** : Le build d'ISO NixOS depuis macOS peut échouer à cause des incompatibilités. Si ça ne marche pas, utilise magnolia (Étape 5).

```bash
cd ~/nix-config/iso

# Builder l'ISO (peut prendre 5-10 minutes la première fois)
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage

# Si succès, l'ISO sera dans:
ls -lh result/iso/*.iso
# Exemple: result/iso/nixos-minimal-ttyS0.iso (~800 MB)
```

**Si tu obtiens une erreur** du genre "platform mismatch" ou "unsupported system", passe à l'Étape 5 (build sur magnolia).

---

## 🖥️ Étape 5 : Builder sur magnolia (si macOS échoue)

### 5.1 : Pousser les changements

```bash
# Sur ton Mac, depuis ~/nix-config/iso
cd ~/nix-config/iso
git add flake.lock
git commit -m "chore(iso): update nixpkgs to match main flake"
git push
```

### 5.2 : Builder sur magnolia

```bash
# SSH vers magnolia
ssh magnolia

# Aller dans le repo
cd /etc/nixos/iso

# Pull les derniers changements
git pull

# Builder l'ISO (10-15 minutes première fois)
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage \
  --option sandbox false

# Vérifier le résultat
ls -lh result/iso/*.iso
```

---

## 📤 Étape 6 : Récupérer l'ISO

### Depuis magnolia

```bash
# Sur ton Mac
cd ~/Downloads

# Copier l'ISO depuis magnolia
scp magnolia:/etc/nixos/iso/result/iso/nixos-minimal-ttyS0.iso ./

# Vérifier la taille (~600-900 MB)
ls -lh nixos-minimal-ttyS0.iso
```

### Depuis ton Mac (si build local a marché)

```bash
# L'ISO est déjà dans result/iso/
cp ~/nix-config/iso/result/iso/nixos-minimal-ttyS0.iso ~/Downloads/
```

---

## ☁️ Étape 7 : Uploader sur Proxmox

### Via l'interface web Proxmox

1. **Aller dans Proxmox Web UI**
   - Ouvrir https://ton-proxmox:8006

2. **Sélectionner le stockage ISO**
   - Datacenter → Storage → local
   - Ou ton storage ISO personnalisé

3. **Upload**
   - Cliquer sur "Upload"
   - Sélectionner `nixos-minimal-ttyS0.iso`
   - Attendre la fin de l'upload (~2-5 min selon connexion)

### Via SCP (plus rapide si tu as accès SSH à Proxmox)

```bash
# Sur ton Mac
scp ~/Downloads/nixos-minimal-ttyS0.iso root@proxmox:/var/lib/vz/template/iso/

# Vérifier que c'est bien arrivé
ssh root@proxmox "ls -lh /var/lib/vz/template/iso/nixos-minimal-ttyS0.iso"
```

---

## 🎬 Étape 8 : Utiliser la nouvelle ISO

### 8.1 : Attacher l'ISO à la VM

```bash
# SSH vers Proxmox
ssh root@proxmox

# Lister tes VMs
qm list

# Attacher la nouvelle ISO (remplace 100 par ton VMID)
qm set 100 --ide2 local:iso/nixos-minimal-ttyS0.iso,media=cdrom

# Démarrer la VM
qm start 100
```

### 8.2 : Installer minimal

Une fois dans l'ISO :

```bash
# Lancer l'installation
sudo ./scripts/install-nixos.sh minimal

# Quand demandé, utilise la branche:
# claude/rename-demo-minimal-01FJuak6GBW28EmCkaTVNvJd
```

---

## ⏱️ Gains de temps attendus

### Avec ISO à jour (même nixpkgs que le flake)

```
Premier install: ~2-3 minutes ✅
└─ Télécharge uniquement les nouveaux packages
└─ Pas de gap de version
└─ Utilise cache.nixos.org efficacement
```

### Avec ISO ancienne (gap de plusieurs semaines)

```
Premier install: ~5-8 minutes ⚠️
└─ Doit télécharger TOUS les packages mis à jour
└─ Gap de version important
└─ Même avec cache, c'est plus long
```

**Gain** : **3-5 minutes économisées** par installation ! 🚀

---

## 🔍 Vérifier que ça a marché

Après l'installation avec la nouvelle ISO :

```bash
# Sur la VM minimal fraîchement installée
ssh root@<IP-minimal>

# Vérifier la version nixpkgs
nix-info -m | grep nixpkgs

# Comparer avec le flake principal
cd /etc/nixos
git rev-parse HEAD
jq -r '.nodes.nixpkgs.locked.rev' flake.lock

# Les versions devraient matcher ! ✅
```

---

## 📝 Maintenance

### Quand rebuilder l'ISO ?

- ❌ Pas besoin à chaque petit changement
- ✅ Tous les 1-2 mois (quand nixpkgs a beaucoup avancé)
- ✅ Avant une grosse session d'installation de VMs
- ✅ Après une mise à jour majeure (24.11 → 25.05)

### Automatisation future (optionnel)

Tu pourrais créer un GitHub Action pour builder l'ISO automatiquement chaque mois :

```yaml
# .github/workflows/build-iso.yml
name: Build ISO monthly
on:
  schedule:
    - cron: '0 0 1 * *'  # 1er de chaque mois
  workflow_dispatch:       # Manuel aussi

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Build ISO
        run: |
          cd iso
          nix flake update
          nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: nixos-iso
          path: iso/result/iso/*.iso
```

---

## 🆘 Dépannage

### Erreur : "platform mismatch"

→ Builder sur magnolia au lieu de macOS (Étape 5)

### Erreur : "out of disk space"

```bash
# Libérer de l'espace
nix-collect-garbage -d
```

### Build très lent (>30 min)

```bash
# Vérifier que le cache est utilisé
nix build ... --print-build-logs 2>&1 | grep -E 'copying|building'

# Devrait voir plein de "copying path" (téléchargement)
# Peu de "building" (compilation)
```

### ISO ne boote pas dans Proxmox

- Vérifier que la VM est en mode UEFI
- Vérifier que l'ISO est bien attachée (ide2)
- Essayer de redémarrer la VM

---

## ✅ Checklist finale

- [ ] ISO buildée avec succès
- [ ] ISO uploadée sur Proxmox
- [ ] ISO testée (boote correctement)
- [ ] Version nixpkgs match le flake principal
- [ ] Installation de minimal en ~2-3 minutes ✅

---

**Résultat** : Des installations NixOS ultra-rapides grâce à une ISO toujours à jour ! 🎉

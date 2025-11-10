# Scripts d'installation NixOS

Ce dossier contient les scripts pour installer et configurer NixOS automatiquement.

## 📋 Scripts disponibles

### 1. `install-nixos.sh` - Installation dans la VM

Script principal d'installation NixOS, à exécuter **depuis l'ISO d'installation dans la VM**.

**Usage:**
```bash
# Télécharger et lancer depuis l'ISO NixOS
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh [magnolia|mimosa]  # magnolia = Proxmox, mimosa = serveur web
```

**Fonctionnalités:**
- ✅ Nettoyage automatique du disque (évite "partition in use")
- ✅ Partitionnement GPT + UEFI
- ✅ Installation via flake NixOS
- ✅ Configuration des secrets SOPS
- ✅ Arrêt automatique après installation (avec countdown de 10s)

**Workflow:**
1. Le script nettoie le disque
2. Crée les partitions et les formate
3. Clone la configuration depuis GitHub
4. Installe NixOS
5. S'éteint automatiquement après 10 secondes

### 2. `proxmox-post-install.sh` - Automatisation Proxmox (optionnel)

Script compagnon à exécuter **sur l'hôte Proxmox** pour automatiser complètement le processus.

**Usage:**
```bash
# Sur l'hôte Proxmox
./proxmox-post-install.sh <VMID>
```

**Fonctionnalités:**
- ⏳ Attend que la VM s'éteigne (fin d'installation)
- 💿 Détache automatiquement l'ISO
- 🚀 Redémarre la VM sur le système installé

## 🔄 Workflow complet

### Option A: Semi-automatique (recommandé pour débuter)

1. **Dans la VM** (depuis l'ISO NixOS):
   ```bash
   curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
   chmod +x install.sh
   sudo ./install.sh magnolia  # Infrastructure Proxmox
   ```

2. **La VM s'éteint automatiquement**

3. **Sur l'hôte Proxmox** (manuellement):
   ```bash
   qm set <VMID> --ide2 none  # Détacher l'ISO
   qm start <VMID>             # Redémarrer la VM
   ```

4. **Se connecter via SSH**:
   ```bash
   ssh jeremie@<IP>
   ```

### Option B: Entièrement automatique

1. **Sur l'hôte Proxmox** (dans un terminal):
   ```bash
   ./proxmox-post-install.sh <VMID>
   ```

2. **Dans la VM** (depuis la console ou SSH):
   ```bash
   curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
   chmod +x install.sh
   sudo ./install.sh magnolia  # Infrastructure Proxmox
   ```

3. Le script Proxmox attend, détache l'ISO et redémarre automatiquement

4. **Se connecter via SSH**:
   ```bash
   ssh jeremie@<IP>
   ```

## 🔧 Relancer après un échec

Le script `install-nixos.sh` peut être relancé **sans redémarrer la VM** en cas d'échec :

```bash
sudo ./install.sh magnolia
# Si échec...
sudo ./install.sh magnolia  # Relancer directement
```

Le nettoyage automatique du disque évite les erreurs "partition in use".

## 📝 Notes

- Les deux hosts disponibles: `magnolia` (infrastructure Proxmox) et `mimosa` (serveur web)
- Le disque cible est toujours `/dev/sda`
- Les secrets SOPS doivent être présents dans `/var/lib/sops-nix/key.txt` (optionnel)
- L'arrêt automatique peut être annulé avec `Ctrl+C` pendant le countdown

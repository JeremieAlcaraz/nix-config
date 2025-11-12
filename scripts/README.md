# 🚀 Scripts NixOS

Deux scripts **séparés** pour une gestion propre de vos installations NixOS.

## 📋 Script 1 : `install-nixos.sh`

Script d'installation NixOS, à exécuter **depuis l'ISO d'installation dans la VM**.

### ✨ Ce qu'il fait

1. ✅ **Partitionnement** - GPT + UEFI automatique
2. ✅ **Génération hardware-configuration.nix** - Pour l'host spécifique
3. ✅ **Clone de la configuration** - Depuis GitHub
4. ✅ **Installation NixOS** - Via flake
5. ✅ **Arrêt automatique** - Avec countdown de 10s

### ⚠️ Ce qu'il NE fait PAS

- ❌ **Ne crée PAS les secrets** - C'est volontaire !
- ❌ **Ne génère PAS de mots de passe** - Séparation des responsabilités

Les secrets sont gérés **après l'installation** avec `manage-secrets.sh`.

## 🔐 Script 2 : `manage-secrets.sh`

Script **indépendant** pour gérer les secrets, à utiliser **après l'installation**.

### 🎯 Usage

```bash
# Depuis la racine du repo nix-config
sudo ./scripts/manage-secrets.sh [magnolia|mimosa|whitelily]

# Ou sans argument pour un menu interactif
sudo ./scripts/manage-secrets.sh
```

### ✨ Ce qu'il fait

1. ✅ **Vérifications** - Outils nécessaires (sops, age, openssl, mkpasswd)
2. ✅ **Clé age** - Vérifie ou demande la clé de chiffrement
3. ✅ **Génération interactive** - Crée les secrets étape par étape
4. ✅ **Backup automatique** - Sauvegarde les anciens secrets avant régénération
5. ✅ **Chiffrement automatique** - Chiffre immédiatement avec sops
6. ✅ **Guide post-génération** - Instructions pour commit et déploiement

### 💡 Quand l'utiliser

- ✅ **Après chaque installation** - Créer les secrets pour un nouveau système
- ✅ **Rotation des secrets** - Régénérer n'importe quel secret à tout moment
- ✅ **Mise à jour** - Changer un mot de passe, un token Cloudflare, etc.

### 🎯 Usage ultra-simple

```bash
# Dans la console de la VM (boot sur ISO NixOS)
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh [magnolia|mimosa|whitelily]
```

**C'est tout !** Le script fait le reste. ⚡

### 🎨 Hosts disponibles

- **`magnolia`** - Infrastructure Proxmox
- **`mimosa`** - Serveur web (j12zdotcom)
- **`whitelily`** - n8n automation

### 🔐 Séparation des responsabilités

**`install-nixos.sh`** s'occupe uniquement de l'installation :
- ✅ Partitionnement et formatage
- ✅ Configuration matérielle
- ✅ Installation du système de base

**`manage-secrets.sh`** s'occupe uniquement des secrets :
- ✅ Génération interactive des secrets
- ✅ Chiffrement avec sops
- ✅ Rotation et mise à jour

Cette séparation offre plusieurs avantages :
- 📦 **Build reproductible** : Pas d'effets de bord pendant l'installation
- 🔄 **Rotation facile** : Changez les secrets sans réinstaller
- 🔒 **Sécurité** : Les secrets ne sont jamais créés au build time
- 🧹 **Code propre** : Chaque script a une responsabilité claire

#### Secrets par host

**`magnolia`**
- Mot de passe SSH pour `jeremie`

**`mimosa`**
- Mot de passe SSH pour `jeremie`
- Token Cloudflare Tunnel (avec instructions)

**`whitelily`**
- Mot de passe SSH pour `jeremie`
- Secrets n8n générés automatiquement :
  - `N8N_ENCRYPTION_KEY` (64 caractères)
  - `N8N_BASIC_PASS` (mot de passe fort)
  - `DB_PASSWORD` (PostgreSQL)
- Nom d'utilisateur n8n (défaut: admin)
- Domaine (ex: n8n.votredomaine.com)
- Token Cloudflare Tunnel (avec validation)

### 🗂️ Hardware configuration automatique

Le script génère `hardware-configuration.nix` et le place automatiquement :

```
hosts/
├── magnolia/
│   └── hardware-configuration.nix  ← Généré automatiquement
├── mimosa/
│   └── hardware-configuration.nix  ← Généré automatiquement
└── whitelily/
    └── hardware-configuration.nix  ← Généré automatiquement
```

**Aucune manipulation manuelle nécessaire !**

### 📝 Workflow complet

```bash
# ========================================
# Partie 1 : Installation (install-nixos.sh)
# ========================================

# 1. Créer une VM dans Proxmox
#    - Boot sur ISO NixOS 24.11
#    - 2 CPU, 4GB RAM, 32GB disque (whitelily)
#    - 2 CPU, 2GB RAM, 20GB disque (magnolia/mimosa)

# 2. Dans la console VM
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh whitelily  # Ou magnolia/mimosa

# 3. Attendre la fin de l'installation (5-10 min)
#    Le script s'arrête automatiquement

# 4. Sur Proxmox : détacher l'ISO et redémarrer
qm set <VMID> --ide2 none
qm start <VMID>

# ========================================
# Partie 2 : Création des secrets (manage-secrets.sh)
# ========================================

# 5. Se connecter en root
ssh root@<IP>

# 6. Créer les secrets
cd /etc/nixos
./scripts/manage-secrets.sh whitelily

# 7. Déployer la configuration avec les secrets
nixos-rebuild switch --flake .#whitelily

# 8. Se reconnecter avec l'utilisateur normal
exit
ssh jeremie@<IP>
```

**Temps total : ~15-20 minutes** ⏱️

### 🎯 Exemple concret pour whitelily (n8n)

**Partie 1 : Installation**
```bash
# Dans la VM
sudo ./install.sh whitelily
# → Installe le système (5-10 min)
# → S'arrête automatiquement
```

**Partie 2 : Création des secrets**
```bash
# Après redémarrage
ssh root@<IP>
cd /etc/nixos
./scripts/manage-secrets.sh whitelily

# Le script demande :
# 1. Mot de passe SSH pour jeremie
# 2. Nom d'utilisateur n8n (défaut: admin)
# 3. Domaine complet (ex: n8n.jeremiealcaraz.com)
# 4. Token Cloudflare Tunnel

# Puis déployer :
nixos-rebuild switch --flake .#whitelily
```

### 🔄 Relancer après un échec

Le script peut être relancé **sans redémarrer la VM** :

```bash
sudo ./install.sh whitelily  # Relancer directement
```

Le nettoyage automatique du disque évite les erreurs "partition in use".

### ⚡ Avantages de cette approche

| Avantage | Bénéfice |
|----------|----------|
| **🔒 Sécurité** | Les secrets ne sont jamais créés au build time |
| **📦 Reproductibilité** | Le build est déterministe, sans effets de bord |
| **🔄 Rotation facile** | Changez n'importe quel secret sans réinstaller |
| **🧹 Code propre** | Séparation claire : installation ≠ gestion des secrets |
| **💾 Backup automatique** | Les anciens secrets sont sauvegardés avant modification |
| **🎯 Flexibilité** | Gérez les secrets quand vous voulez |
| **📝 Assistant interactif** | Guide pas à pas pour tous les secrets |

### 📚 Pour plus d'infos

Voir le guide complet : [`docs/WHITELILY-N8N-SETUP.md`](../docs/WHITELILY-N8N-SETUP.md)

---

## 🎉 C'est tout !

Deux scripts, deux responsabilités, une architecture propre. 🚀

**`install-nixos.sh`** → Installation du système
**`manage-secrets.sh`** → Gestion des secrets

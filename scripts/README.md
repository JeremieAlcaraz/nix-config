# 🚀 Scripts NixOS

Deux scripts principaux pour gérer vos installations NixOS.

## 📋 Script 1 : `install-nixos.sh`

Script complet d'installation NixOS, à exécuter **depuis l'ISO d'installation dans la VM**.

### ✨ Ce qu'il fait automatiquement

1. ✅ **Partitionnement** - GPT + UEFI automatique
2. ✅ **Génération hardware-configuration.nix** - Pour l'host spécifique
3. ✅ **Clone de la configuration** - Depuis GitHub
4. ✅ **Gestion flexible des secrets** - Créer maintenant, utiliser existants, ou reporter
5. ✅ **Chiffrement sops** - Automatique si clé age présente
6. ✅ **Installation NixOS** - Via flake
7. ✅ **Arrêt automatique** - Avec countdown de 10s

## 🔐 Script 2 : `manage-secrets.sh` (NOUVEAU)

Script **indépendant** pour gérer les secrets après l'installation.

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

- ✅ **Après l'installation** - Si vous avez choisi de reporter la création des secrets
- ✅ **Rotation des secrets** - Régénérer n'importe quel secret à tout moment
- ✅ **Mise à jour** - Changer un mot de passe, un token Cloudflare, etc.
- ✅ **Setup initial** - Créer les secrets avant l'installation

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

### 🔐 Gestion flexible des secrets

Pendant l'installation, vous avez **3 options** :

**Option 1 : Créer les secrets maintenant** (génération interactive)
- Le script lance l'assistant interactif
- Les secrets sont créés et chiffrés immédiatement
- Idéal pour une installation complète en une fois

**Option 2 : Utiliser des secrets existants**
- Si vous avez déjà créé les secrets dans le repo
- Le script utilise les fichiers chiffrés existants
- Utile pour réinstaller un système

**Option 3 : Reporter la création des secrets** ⭐ **RECOMMANDÉ**
- L'installation se fait sans les secrets
- Vous créez les secrets **après l'installation** avec `manage-secrets.sh`
- **Séparation propre** : build/install vs gestion des secrets
- Facilite la rotation future des secrets

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

### 🔒 Chiffrement des secrets

Si une clé age est présente dans `/var/lib/sops-nix/key.txt` :
- ✅ Les secrets sont chiffrés automatiquement avec sops
- ✅ La clé est copiée dans le système cible
- ✅ Le fichier `secrets/{host}.yaml` est créé et chiffré

Sinon :
- ⚠️ Les secrets sont copiés non chiffrés (warning affiché)

### 📝 Workflow recommandé (avec secrets différés)

```bash
# 1. Créer une VM dans Proxmox
#    - Boot sur ISO NixOS 24.11
#    - 2 CPU, 4GB RAM, 32GB disque (whitelily)
#    - 2 CPU, 2GB RAM, 20GB disque (magnolia/mimosa)

# 2. Dans la console VM
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh whitelily  # Ou magnolia/mimosa

# 3. Choisir l'option 3 (Reporter la création des secrets)

# 4. Attendre la fin de l'installation (5-10 min)

# 5. La VM s'éteint automatiquement

# 6. Sur Proxmox : détacher l'ISO et redémarrer
qm set <VMID> --ide2 none
qm start <VMID>

# 7. Se connecter et créer les secrets
ssh root@<IP>  # Première connexion en root
cd /etc/nixos
./scripts/manage-secrets.sh whitelily

# 8. Déployer la configuration avec les secrets
nixos-rebuild switch --flake .#whitelily

# 9. Se reconnecter avec l'utilisateur normal
ssh jeremie@<IP>
```

**Temps total : ~15-20 minutes** ⏱️

### 📝 Workflow alternatif (avec secrets pendant l'installation)

Si vous préférez tout faire en une fois :

```bash
# Étapes 1-2 identiques

# 3. Choisir l'option 1 (Créer les secrets maintenant)
#    Suivre l'assistant interactif pour générer les secrets

# 4-5 identiques

# 6. Sur Proxmox : détacher l'ISO et redémarrer
qm set <VMID> --ide2 none
qm start <VMID>

# 7. Se connecter directement
ssh jeremie@<IP>
```

**Temps total : ~15 minutes** ⏱️

### 🎯 Exemple complet pour whitelily (n8n)

```bash
# Dans la VM
sudo ./install.sh whitelily

# Le script demande :
# 1. Branche git (défaut: main)
# 2. Confirmation de l'effacement du disque
# 3. Mot de passe SSH pour jeremie
# 4. Nom d'utilisateur n8n (défaut: admin)
# 5. Domaine complet (ex: n8nv2.jeremiealcaraz.com)
# 6. Credentials JSON Cloudflare Tunnel

# Le script affiche ensuite :
# ✅ Domaine          : n8nv2.jeremiealcaraz.com
# ✅ Utilisateur      : admin
# ✅ Mot de passe     : Abc123XYZ789...
# ✅ Clé chiffrement  : 64 caractères hex

# Puis il installe, configure tout, et éteint la VM
```

### 🔄 Relancer après un échec

Le script peut être relancé **sans redémarrer la VM** :

```bash
sudo ./install.sh whitelily  # Relancer directement
```

Le nettoyage automatique du disque évite les erreurs "partition in use".

### ⚡ Améliorations et nouveautés

| Fonctionnalité | Description |
|----------------|-------------|
| **2 scripts séparés** | `install-nixos.sh` pour l'installation, `manage-secrets.sh` pour les secrets |
| **Gestion flexible des secrets** | 3 options : créer maintenant, utiliser existants, ou reporter |
| **Séparation des responsabilités** | Build/Install séparé de la gestion des secrets |
| **Rotation facile** | `manage-secrets.sh` permet de régénérer n'importe quel secret |
| **Backup automatique** | Les anciens secrets sont sauvegardés avant régénération |
| **Assistant interactif** | Guide pas à pas pour tous les secrets |
| **Configuration automatique** | hardware-configuration.nix et domaine n8n gérés automatiquement |

### 📚 Pour plus d'infos

Voir le guide complet : [`docs/WHITELILY-N8N-SETUP.md`](../docs/WHITELILY-N8N-SETUP.md)

---

## 🎉 C'est tout !

Un seul script, une seule commande, tout est automatique. 🚀

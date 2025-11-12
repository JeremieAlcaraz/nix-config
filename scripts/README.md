# 🚀 Script d'installation NixOS all-in-one

Un seul script qui fait **TOUT** automatiquement !

## 📋 Le script : `install-nixos.sh`

Script complet d'installation NixOS, à exécuter **depuis l'ISO d'installation dans la VM**.

### ✨ Ce qu'il fait automatiquement

1. ✅ **Partitionnement** - GPT + UEFI automatique
2. ✅ **Génération hardware-configuration.nix** - Pour l'host spécifique
3. ✅ **Clone de la configuration** - Depuis GitHub
4. ✅ **Génération interactive des secrets** - Si absents ou incomplets
5. ✅ **Chiffrement sops** - Automatique si clé age présente
6. ✅ **Installation NixOS** - Via flake
7. ✅ **Arrêt automatique** - Avec countdown de 10s

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

### 🔐 Génération automatique des secrets

Si les secrets n'existent pas (ou sont incomplets), le script lance un **assistant interactif** :

#### Pour `magnolia`
- Mot de passe SSH pour `jeremie`

#### Pour `mimosa`
- Mot de passe SSH pour `jeremie`
- Token Cloudflare Tunnel (avec instructions)

#### Pour `whitelily`
- Mot de passe SSH pour `jeremie`
- Secrets n8n générés automatiquement :
  - `N8N_ENCRYPTION_KEY` (64 caractères)
  - `N8N_BASIC_PASS` (mot de passe fort)
  - `DB_PASSWORD` (PostgreSQL)
- Nom d'utilisateur n8n (défaut: admin)
- Domaine (ex: n8n.votredomaine.com)
- Credentials JSON Cloudflare Tunnel (avec validation)

Le script affiche **toutes les credentials générées** avant de continuer.

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

### 📝 Workflow complet

```bash
# 1. Créer une VM dans Proxmox
#    - Boot sur ISO NixOS 24.11
#    - 2 CPU, 4GB RAM, 32GB disque (whitelily)
#    - 2 CPU, 2GB RAM, 20GB disque (magnolia/mimosa)

# 2. Dans la console VM
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh whitelily  # Ou magnolia/mimosa

# 3. Suivre l'assistant interactif pour les secrets

# 4. Attendre la fin de l'installation (5-10 min)

# 5. La VM s'éteint automatiquement

# 6. Sur Proxmox : détacher l'ISO et redémarrer
qm set <VMID> --ide2 none
qm start <VMID>

# 7. Se connecter
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
# 5. Domaine complet (ex: n8n.jeremiealcaraz.com)
# 6. Credentials JSON Cloudflare Tunnel

# Le script affiche ensuite :
# ✅ Domaine          : n8n.jeremiealcaraz.com
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

### ⚡ Différences avec l'ancienne version

| Avant | Maintenant |
|-------|------------|
| 4 scripts différents | **1 seul script** |
| Génération manuelle des secrets | **Assistant interactif** |
| Configuration manuelle de hardware-configuration.nix | **Automatique** |
| Édition manuelle du domaine n8n | **Automatique** |
| ~45 minutes | **~15 minutes** |

### 📚 Pour plus d'infos

Voir le guide complet : [`docs/WHITELILY-N8N-SETUP.md`](../docs/WHITELILY-N8N-SETUP.md)

---

## 🎉 C'est tout !

Un seul script, une seule commande, tout est automatique. 🚀

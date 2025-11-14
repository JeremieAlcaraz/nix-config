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
./scripts/manage-secrets.sh [magnolia|mimosa|whitelily]

# Ou sans argument pour un menu interactif
./scripts/manage-secrets.sh

# Note: Sur NixOS, utilisez sudo si nécessaire
# Sur macOS, pas besoin de sudo
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

### 📝 Workflow recommandé : Secrets depuis votre Mac ⭐

**Le meilleur workflow** : créez les secrets depuis votre machine de dev, puis installez !

```bash
# ========================================
# Partie 1 : Création des secrets (depuis votre Mac)
# ========================================

# Sur votre Mac
cd ~/nix-config
./scripts/manage-secrets.sh whitelily

# Commit et push
git add secrets/whitelily.yaml
git commit -m "🔒 Add secrets for whitelily"
git push

# ========================================
# Partie 2 : Installation (dans la VM)
# ========================================

# 1. Créer une VM dans Proxmox
#    - Boot sur ISO NixOS 24.11
#    - 2 CPU, 4GB RAM, 32GB disque (whitelily)

# 2. Dans la console VM
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
sudo ./install.sh whitelily

# → Le script détecte les secrets dans le repo
# → Installation complète avec les secrets

# 3. Détacher l'ISO et redémarrer
qm set <VMID> --ide2 none
qm start <VMID>

# 4. Se connecter
ssh jeremie@<IP>
```

**Temps total : ~10-15 minutes** ⏱️

**Avantages** :
- ✅ Plus rapide (pas de création de secrets après l'installation)
- ✅ Plus sûr (secrets commités avant, versionnés dans git)
- ✅ Environnement familier (votre Mac)
- ✅ Réutilisable (secrets déjà là pour réinstaller)

### 📝 Workflow alternatif : Secrets après installation

Si vous préférez créer les secrets après l'installation :

```bash
# 1-3. Installation (comme ci-dessus)

# 4. Se connecter en root
ssh root@<IP>

# 5. Créer les secrets
cd /etc/nixos
./scripts/manage-secrets.sh whitelily

# 6. Déployer la configuration avec les secrets
nixos-rebuild switch --flake .#whitelily

# 7. Se reconnecter avec l'utilisateur normal
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

## 🔍 Script 3 : `check-n8n.sh`

Script de **diagnostic automatique** pour n8n, à utiliser en cas de problème.

### 🎯 Usage

```bash
# Depuis la racine du repo
sudo ./scripts/check-n8n.sh
```

### ✨ Ce qu'il fait

1. ✅ **Vérifie les services** - PostgreSQL, n8n, Caddy, Cloudflared
2. ✅ **Analyse les secrets** - Détecte les guillemets parasites dans les secrets sops
3. ✅ **Vérifie le .env** - Contrôle le fichier `/run/n8n/n8n.env` généré
4. ✅ **Test connexion DB** - Essaye de se connecter à PostgreSQL
5. ✅ **Affiche les erreurs** - Montre les dernières erreurs dans les logs
6. ✅ **Test port local** - Vérifie si n8n répond sur `localhost:5678`
7. ✅ **Résumé clair** - Diagnostic complet avec actions suggérées

### 💡 Quand l'utiliser

- ✅ **Après un `nixos-rebuild switch`** - Vérifier que tout est OK
- ✅ **Si n8n ne démarre pas** - Identifier le problème
- ✅ **Erreur d'authentification** - "password authentication failed"
- ✅ **Diagnostic rapide** - État global du système n8n

### 📊 Exemple de sortie

```
╔══════════════════════════════════╗
║  DIAGNOSTIC n8n AUTOMATIQUE      ║
╚══════════════════════════════════╝

📊 Services
✅ PostgreSQL actif
✅ n8n actif
✅ Caddy actif
✅ Cloudflared actif

🔐 Secrets (longueur en caractères)
Encryption key: 33 caractères
DB password: 13 caractères

⚙️  Variables .env
Encryption key: [xyz...] (32 chars)
DB password: [n8n_password] (12 chars)
✅ Pas de guillemets parasites dans le mot de passe

🗄️  Test connexion PostgreSQL
✅ Connexion DB réussie avec le mot de passe du .env

📝 Dernières erreurs n8n
✅ Aucune erreur récente

🌐 Test port local
✅ n8n répond sur localhost:5678 (HTTP 401)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RÉSUMÉ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Tout est OK ! n8n fonctionne correctement.
```

### 🐛 Problème résolu : Guillemets dans les mots de passe

**Contexte du bug** : Les secrets sops contenaient parfois des guillemets littéraux (`"password"`) qui étaient écrits dans le fichier `.env` de n8n. PostgreSQL recevait donc le mot de passe avec les guillemets, provoquant l'erreur :

```
password authentication failed for user "n8n"
```

**Solution appliquée** :
1. Ajout de `tr -d '\n"'` pour supprimer tous les guillemets et newlines des secrets sops
2. Suppression des guillemets dans le fichier .env généré
3. Application cohérente dans le script PostgreSQL `postStart` et `n8n-envfile`

**Fichiers modifiés** : `hosts/whitelily/n8n.nix` (lignes 66, 104-110, 115-124)

### 🔧 Vérification manuelle

Si tu veux vérifier manuellement les secrets :

```bash
# Voir les caractères cachés dans les secrets
sudo cat /run/secrets/n8n/db_password | od -c

# Vérifier le fichier .env
sudo cat /run/n8n/n8n.env | grep PASSWORD

# Tester la connexion DB
DB_PASS=$(sudo cat /run/n8n/n8n.env | grep "DB_POSTGRESDB_PASSWORD=" | cut -d= -f2)
PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U n8n -d n8n -c "SELECT 1;"
```

---

## 🎉 C'est tout !

Trois scripts pour une gestion complète de votre infrastructure NixOS. 🚀

**`install-nixos.sh`** → Installation du système
**`manage-secrets.sh`** → Gestion des secrets
**`check-n8n.sh`** → Diagnostic automatique n8n

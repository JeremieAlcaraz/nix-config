# 🔐 Gestion Sécurisée des Mots de Passe avec sops-nix

Ce guide explique comment gérer de manière sécurisée les mots de passe des utilisateurs avec **sops-nix**.

## 🎯 Pourquoi cette approche ?

### ❌ Problème avec `initialPassword` ou `password`
```nix
users.users.jeremie = {
  initialPassword = "nixos";  # ❌ Mot de passe EN CLAIR dans le repo public !
};
```

**Problèmes** :
- Mot de passe visible par tout le monde sur GitHub
- Risque de sécurité majeur si oublié de le changer
- Pas professionnel pour un environnement de production

### ⚠️ Amélioration avec `hashedPassword`
```nix
users.users.jeremie = {
  hashedPassword = "$6$vwZmaAkvi9Sjgv60$...";  # ⚠️ Hash visible dans le repo
};
```

**Avantages** :
- Impossible de retrouver le mot de passe depuis le hash
- Acceptable pour du développement/test

**Inconvénient** :
- Le hash est quand même visible dans le repo public
- Si quelqu'un a accès au hash ET à la VM, il peut tenter du brute-force

### ✅ Solution ULTIME : `hashedPasswordFile` + sops-nix
```nix
sops.secrets.jeremie-password-hash = {
  neededForUsers = true;
};

users.users.jeremie = {
  hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};
```

**Avantages** :
- ✅ Hash chiffré dans le repo (personne ne peut le voir)
- ✅ Seul l'hôte peut déchiffrer le secret
- ✅ Sécurité maximale pour la production
- ✅ Vous avez déjà sops-nix configuré !

## 📋 État Actuel

✅ **Configuration mise en place** :
- sops-nix activé pour `magnolia` ET `mimosa`
- Fichiers de secrets example créés (`secrets/magnolia.yaml.example`, `secrets/mimosa.yaml.example`)
- `.sops.yaml` configuré pour les deux hosts
- Les hosts utilisent maintenant `hashedPasswordFile` au lieu de `initialPassword` ou `hashedPassword`

⚠️ **À faire APRÈS le premier boot** :
1. Récupérer les clés publiques des hosts
2. Créer et chiffrer les fichiers de secrets
3. Redéployer avec les secrets chiffrés

## 🚀 Guide d'Utilisation

### Étape 1 : Premier Déploiement (Bootstrap)

Pour le **premier déploiement**, les secrets ne sont pas encore disponibles. Vous avez deux options :

#### Option A : Déployer avec initialPassword temporaire (simple)

Modifier temporairement les fichiers de configuration pour utiliser `initialPassword` :

```nix
# Dans hosts/mimosa/configuration.nix ou hosts/magnolia/configuration.nix
users.users.jeremie = {
  isNormalUser = true;
  createHome = true;
  home = "/home/jeremie";
  extraGroups = [ "wheel" ];
  # Temporaire pour le premier boot
  initialPassword = "nixos";
  # Commentez temporairement :
  # hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};

# Commentez aussi temporairement la section sops
# sops = { ... };
```

Après le premier boot, vous pourrez suivre les étapes 2-5 pour activer sops.

#### Option B : Utiliser hashedPassword sans sops (plus rapide)

Modifier temporairement pour utiliser directement un hash :

```bash
# Générer un hash sur votre machine locale
python3 -c "import crypt; print(crypt.crypt('votre-mot-de-passe', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Puis dans la configuration :
```nix
users.users.jeremie = {
  isNormalUser = true;
  createHome = true;
  home = "/home/jeremie";
  extraGroups = [ "wheel" ];
  hashedPassword = "$6$...";  # Votre hash ici
  # Commentez temporairement :
  # hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};

# Commentez aussi temporairement la section sops
# sops = { ... };
```

### Étape 2 : Récupérer les Clés Publiques des Hosts

Une fois les VMs déployées et démarrées, récupérez leurs clés publiques :

```bash
# Pour mimosa
ssh root@mimosa "cat /var/lib/sops-nix/key.pub"
# Exemple de sortie: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Pour magnolia
ssh root@magnolia "cat /var/lib/sops-nix/key.pub"
# Exemple de sortie: age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

**Note** : Si `/var/lib/sops-nix/key.pub` n'existe pas, c'est que sops-nix n'a pas encore généré la clé.
Cela se produit au premier boot avec la configuration sops activée. Si vous avez déployé avec l'Option A ou B,
vous devrez d'abord activer la configuration sops (étape 5) et redéployer.

### Étape 3 : Mettre à Jour `.sops.yaml`

Remplacez les clés placeholder par les vraies clés :

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/mimosa\.yaml$
    key_groups:
      - age:
          - &mimosa age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Remplacez par la vraie clé

  - path_regex: secrets/magnolia\.yaml$
    key_groups:
      - age:
          - &magnolia age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy  # Remplacez par la vraie clé
```

**Optionnel mais recommandé** : Ajoutez votre propre clé age pour pouvoir éditer les secrets :

```bash
# Générer votre clé personnelle
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
# Affichez la clé publique
grep "public key:" ~/.config/sops/age/keys.txt
```

Ajoutez votre clé dans `.sops.yaml` :
```yaml
creation_rules:
  - path_regex: secrets/mimosa\.yaml$
    key_groups:
      - age:
          - &mimosa age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
          - &admin age1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz  # Votre clé
```

### Étape 4 : Créer et Chiffrer les Secrets

#### Pour mimosa :

```bash
# 1. Copier le fichier example
cp secrets/mimosa.yaml.example secrets/mimosa.yaml

# 2. (Optionnel) Générer un nouveau hash de mot de passe sécurisé
python3 -c "import crypt; print(crypt.crypt('VotreMotDePasseSecurise', crypt.mksalt(crypt.METHOD_SHA512)))"

# 3. Éditer et chiffrer avec sops
nix-shell -p sops --run "sops secrets/mimosa.yaml"
# Remplacez le hash du mot de passe par votre nouveau hash (si généré à l'étape 2)
# Remplacez aussi le token Cloudflare si vous en avez un
# Sauvegardez et quittez (Ctrl+O, Enter, Ctrl+X dans nano)

# 4. Vérifier que le fichier est bien chiffré
cat secrets/mimosa.yaml | grep "sops:"
# Si vous voyez "sops: ... mac: ..." alors c'est bon !
```

#### Pour magnolia :

```bash
# Même processus
cp secrets/magnolia.yaml.example secrets/magnolia.yaml
nix-shell -p sops --run "sops secrets/magnolia.yaml"
# Remplacez le hash du mot de passe si nécessaire
# Sauvegardez et quittez

# Vérifier le chiffrement
cat secrets/magnolia.yaml | grep "sops:"
```

### Étape 5 : Activer la Configuration sops et Redéployer

Si vous aviez commenté la configuration sops pour le premier déploiement, décommentez-la maintenant :

```nix
# Dans hosts/mimosa/configuration.nix et hosts/magnolia/configuration.nix

# Décommentez la section sops
sops = {
  defaultSopsFile = ../../secrets/mimosa.yaml;  # ou magnolia.yaml
  age = {
    keyFile = "/var/lib/sops-nix/key.txt";
  };
  secrets = {
    jeremie-password-hash = {
      neededForUsers = true;
    };
  };
};

# Et dans la définition de l'utilisateur
users.users.jeremie = {
  isNormalUser = true;
  createHome = true;
  home = "/home/jeremie";
  extraGroups = [ "wheel" ];
  hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;  # Décommentez
  # Supprimez ou commentez initialPassword/hashedPassword
};
```

Committez et poussez :

```bash
git add secrets/mimosa.yaml secrets/magnolia.yaml
git add hosts/mimosa/configuration.nix hosts/magnolia/configuration.nix
git commit -m "🔒 Activer sops-nix pour les mots de passe"
git push
```

Redéployez sur vos VMs :

```bash
# Pour mimosa
ssh root@mimosa
cd /etc/nixos
git pull
nixos-rebuild switch --flake .#mimosa

# Pour magnolia
ssh root@magnolia
cd /etc/nixos
git pull
nixos-rebuild switch --flake .#magnolia
```

### Étape 6 : Committer les Secrets (Chiffrés)

Les fichiers de secrets chiffrés peuvent être committés en toute sécurité :

```bash
# Ajouter avec -f car .gitignore bloque les .yaml par sécurité
git add -f secrets/mimosa.yaml secrets/magnolia.yaml
git commit -m "🔒 Add encrypted password hashes with sops"
git push
```

## 🔄 Modifier un Secret

Pour modifier un secret existant :

```bash
# Éditer le secret (sops le déchiffre automatiquement pour l'édition)
nix-shell -p sops --run "sops secrets/mimosa.yaml"

# Modifier les valeurs
# Sauvegarder et quitter

# Committer les changements
git add secrets/mimosa.yaml
git commit -m "🔒 Update secrets"
git push

# Redéployer sur la VM
ssh root@mimosa
cd /etc/nixos
git pull
nixos-rebuild switch --flake .#mimosa
```

## 🔑 Changer le Mot de Passe

Pour changer le mot de passe d'un utilisateur :

```bash
# 1. Générer un nouveau hash
python3 -c "import crypt; print(crypt.crypt('NouveauMotDePasse', crypt.mksalt(crypt.METHOD_SHA512)))"

# 2. Éditer le secret
nix-shell -p sops --run "sops secrets/mimosa.yaml"
# Remplacer la valeur de jeremie-password-hash

# 3. Committer et redéployer
git add secrets/mimosa.yaml
git commit -m "🔒 Update password hash"
git push

# 4. Redéployer
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## 📊 Comparaison des Approches

| Approche | Sécurité | Complexité | Cas d'usage |
|----------|----------|------------|-------------|
| `initialPassword` | ⚠️ Très faible | ✅ Très simple | Test temporaire uniquement |
| `password` | ⚠️ Très faible | ✅ Très simple | Jamais en production |
| `hashedPassword` | ✅ Bon | ✅ Simple | Dev/test, petits projets |
| `hashedPasswordFile` + sops | 🔒 Excellent | ⚠️ Moyen | **Production (recommandé)** |

## 🆘 Dépannage

### Le fichier secret n'est pas déchiffré au boot

Vérifiez que :
1. La clé publique dans `.sops.yaml` correspond bien à celle de l'hôte
2. Le fichier `/var/lib/sops-nix/key.txt` existe sur l'hôte
3. L'option `neededForUsers = true;` est bien présente dans la configuration du secret

### Je ne peux plus me connecter après le redéploiement

Si vous vous retrouvez bloqué :
1. Connectez-vous via la console Proxmox (pas SSH)
2. Réinitialisez le mot de passe manuellement : `passwd jeremie`
3. Vérifiez la configuration sops et corrigez
4. Redéployez

### sops ne trouve pas ma clé pour éditer

Si vous avez ajouté votre clé personnelle dans `.sops.yaml` mais sops ne la trouve pas :

```bash
# Assurez-vous que votre clé est dans le bon répertoire
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
nix-shell -p sops --run "sops secrets/mimosa.yaml"
```

## 🎓 Ressources

- [Documentation sops-nix](https://github.com/Mic92/sops-nix)
- [Guide Age encryption](https://github.com/FiloSottile/age)
- [NixOS Manual - User Management](https://nixos.org/manual/nixos/stable/index.html#sec-user-management)

## 🎯 Résumé Rapide

**Pour le premier déploiement** :
1. Utilisez `initialPassword` ou `hashedPassword` temporairement
2. Déployez et démarrez les VMs
3. Récupérez les clés publiques des hosts
4. Mettez à jour `.sops.yaml`
5. Créez et chiffrez les secrets
6. Activez la configuration sops
7. Redéployez avec les secrets chiffrés

**Pour modifier un secret** :
1. `sops secrets/host.yaml`
2. Modifiez et sauvegardez
3. Committez et redéployez

**Sécurité** : 🔒 Ultime avec sops-nix !

# 🚀 Déploiement Rapide avec sops-nix (Clé Partagée)

Ce guide te permet de déployer tes VMs NixOS avec des mots de passe sécurisés chiffrés avec sops.

## 🎯 Vue d'ensemble

**Configuration utilisée** : Clé age partagée (la même pour toutes les VMs)

**Avantages** :
- ✅ Une seule clé à gérer
- ✅ Tu peux créer/éditer les secrets depuis ton Mac
- ✅ Pas besoin de récupérer les clés des VMs
- ✅ Parfait pour un homelab personnel

## 📋 Étapes de Déploiement

### Étape 1 : Créer les Secrets Chiffrés (sur ton Mac)

Tu as déjà généré ta clé age ici : `~/.config/sops/age/nixos-shared-key.txt` ✅

Maintenant, va dans le repo sur ton Mac et crée les secrets :

```bash
# 1. Aller dans le repo
cd /path/to/nix-config

# 2. Configurer sops pour utiliser ta clé
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt

# 3. Créer le secret pour mimosa (serveur web)
cp secrets/mimosa.yaml.example secrets/mimosa.yaml
sops secrets/mimosa.yaml
# Un éditeur s'ouvre (nano ou vi)
# Le fichier contient déjà un hash de mot de passe par défaut (mot de passe: "nixos")
# Tu peux le garder ou le changer (voir section "Changer le mot de passe" ci-dessous)
# Sauvegarde et quitte (Ctrl+X, puis Y, puis Enter dans nano)

# 4. Créer le secret pour magnolia (infrastructure Proxmox)
cp secrets/magnolia.yaml.example secrets/magnolia.yaml
sops secrets/magnolia.yaml
# Même chose, sauvegarde et quitte

# 5. Vérifier que les fichiers sont bien chiffrés
cat secrets/mimosa.yaml | grep "sops:"
# Tu dois voir : sops: ... mac: ...
# Si c'est le cas, c'est bon ! 🎉

cat secrets/magnolia.yaml | grep "sops:"
# Pareil ici

# 6. Committer les secrets chiffrés
git add -f secrets/mimosa.yaml secrets/magnolia.yaml
git commit -m "🔒 Add encrypted secrets with shared age key"
git push
```

### Étape 2 : Copier la Clé Privée sur les VMs

**IMPORTANT** : Cette étape doit être faite AVANT le premier build de chaque VM.

Tu as deux options :

#### Option A : Via ISO Live (Avant installation)

Si tu n'as pas encore installé les VMs, tu peux copier la clé via l'ISO live :

```bash
# Sur ton Mac, depuis le repo
# Copier la clé sur une VM via SSH (pendant l'installation)
ssh nixos@<ip-de-la-vm>
sudo mkdir -p /mnt/var/lib/sops-nix
sudo chmod 755 /mnt/var/lib/sops-nix

# Depuis ton Mac
cat ~/.config/sops/age/nixos-shared-key.txt | ssh nixos@<ip-de-la-vm> "sudo tee /mnt/var/lib/sops-nix/key.txt"
ssh nixos@<ip-de-la-vm> "sudo chmod 600 /mnt/var/lib/sops-nix/key.txt"
```

Puis continue avec l'installation normale.

#### Option B : Après Installation (avec initialPassword temporaire)

Si tu veux installer d'abord puis copier la clé après :

1. **Modifier temporairement les configs** pour utiliser `initialPassword` :

```nix
# Dans hosts/mimosa/configuration.nix et hosts/magnolia/configuration.nix

# Commentez temporairement la section sops
# sops = { ... };

# Et dans users.users.jeremie
users.users.jeremie = {
  isNormalUser = true;
  createHome = true;
  home = "/home/jeremie";
  extraGroups = [ "wheel" ];
  initialPassword = "nixos";  # Temporaire !
  # hashedPasswordFile = config.sops.secrets.jeremie-password-hash.path;
};
```

2. **Déployer les VMs** avec cette config temporaire

3. **Copier la clé** sur chaque VM :

```bash
# Pour mimosa (serveur web)
cat ~/.config/sops/age/nixos-shared-key.txt | ssh root@mimosa "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@mimosa "chmod 600 /var/lib/sops-nix/key.txt"

# Pour magnolia (infrastructure Proxmox)
cat ~/.config/sops/age/nixos-shared-key.txt | ssh root@magnolia "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@magnolia "chmod 600 /var/lib/sops-nix/key.txt"
```

4. **Réactiver la config sops** (décommenter les sections)

5. **Redéployer** :

```bash
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
ssh root@magnolia "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#magnolia"
```

### Étape 3 : Déployer les VMs

Si tu as suivi l'Option A, ta clé est déjà en place. Déploie normalement :

```bash
# Après avoir cloné le repo dans /etc/nixos sur la VM
nixos-rebuild switch --flake .#mimosa
# ou
nixos-rebuild switch --flake .#magnolia
```

## 🔑 Changer le Mot de Passe

Le hash par défaut correspond au mot de passe `"nixos"`. Pour le changer :

```bash
# Sur ton Mac

# 1. Générer un nouveau hash
python3 -c "import crypt; print(crypt.crypt('TonNouveauMotDePasse', crypt.mksalt(crypt.METHOD_SHA512)))"
# Copie le hash généré ($6$...)

# 2. Éditer le secret
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt
sops secrets/mimosa.yaml
# Remplace la valeur de jeremie-password-hash par ton nouveau hash
# Sauvegarde et quitte

# 3. Même chose pour magnolia si besoin
sops secrets/magnolia.yaml

# 4. Commit et push
git add secrets/*.yaml
git commit -m "🔒 Update password hash"
git push

# 5. Redéployer sur les VMs
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
ssh root@magnolia "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#magnolia"
```

## 🔄 Workflow Quotidien

### Ajouter un Nouveau Secret

```bash
# Sur ton Mac
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt
sops secrets/mimosa.yaml
# Ajoute ton nouveau secret (ex: api-key: ma-clé-secrète)
# Sauvegarde et quitte

# Commit et push
git add secrets/mimosa.yaml
git commit -m "🔒 Add new secret"
git push

# Utilise le secret dans la config
sops.secrets.api-key = {};

# Redéploie
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

### Éditer un Secret Existant

```bash
# Sur ton Mac
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt
sops secrets/mimosa.yaml
# Modifie le secret
# Sauvegarde et quitte

git add secrets/mimosa.yaml
git commit -m "🔒 Update secret"
git push

# Redéploie
ssh root@mimosa "cd /etc/nixos && git pull && nixos-rebuild switch --flake .#mimosa"
```

## 🆘 Dépannage

### Erreur : "no keys could decrypt the data key"

**Cause** : La clé privée n'est pas sur la VM ou est incorrecte.

**Solution** :
```bash
# Vérifie que la clé existe sur la VM
ssh root@mimosa "ls -la /var/lib/sops-nix/key.txt"

# Si elle n'existe pas, copie-la depuis ton Mac
cat ~/.config/sops/age/nixos-shared-key.txt | ssh root@mimosa "mkdir -p /var/lib/sops-nix && cat > /var/lib/sops-nix/key.txt"
ssh root@mimosa "chmod 600 /var/lib/sops-nix/key.txt"

# Redéploie
ssh root@mimosa "nixos-rebuild switch --flake /etc/nixos#mimosa"
```

### Erreur : "file 'secrets/mimosa.yaml' not found"

**Cause** : Le fichier de secrets n'a pas été créé ou committé.

**Solution** :
```bash
# Sur ton Mac
cd /path/to/nix-config
cp secrets/mimosa.yaml.example secrets/mimosa.yaml
export SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt
sops secrets/mimosa.yaml
# Sauvegarde et quitte

git add -f secrets/mimosa.yaml
git commit -m "🔒 Add encrypted secrets"
git push
```

### Je ne peux plus me connecter après le redéploiement

**Cause** : Le hash de mot de passe est incorrect ou le secret n'est pas déchiffré.

**Solution** :
1. Connecte-toi via la console Proxmox (pas SSH)
2. Réinitialise le mot de passe manuellement : `passwd jeremie`
3. Vérifie la configuration sops et corrige
4. Redéploie

## 💡 Astuces

### Alias pour simplifier

Ajoute ces alias dans ton `~/.zshrc` ou `~/.bashrc` sur ton Mac :

```bash
# sops avec la bonne clé
alias sops-edit='SOPS_AGE_KEY_FILE=~/.config/sops/age/nixos-shared-key.txt sops'

# Éditer les secrets rapidement
alias sops-mimosa='sops-edit ~/path/to/nix-config/secrets/mimosa.yaml'
alias sops-magnolia='sops-edit ~/path/to/nix-config/secrets/magnolia.yaml'
```

Utilisation :
```bash
sops-mimosa  # Édite directement mimosa.yaml
```

### Sauvegarder la Clé Privée

⚠️ **IMPORTANT** : Sauvegarde ta clé privée dans un endroit sûr !

```bash
# Option 1 : iCloud/Dropbox (dans un dossier chiffré)
cp ~/.config/sops/age/nixos-shared-key.txt ~/Documents/Backup/

# Option 2 : USB chiffrée

# Option 3 : Password manager (1Password, Bitwarden)
cat ~/.config/sops/age/nixos-shared-key.txt
# Copie le contenu dans ton password manager
```

Si tu perds cette clé, tu ne pourras plus déchiffrer tes secrets ! 🚨

## 🎯 Checklist de Déploiement

- [ ] Clé age générée sur le Mac (✅ déjà fait)
- [ ] `.sops.yaml` configuré avec ta clé publique (✅ déjà fait)
- [ ] Secrets créés et chiffrés (`secrets/mimosa.yaml`, `secrets/magnolia.yaml`)
- [ ] Secrets committés et pushés
- [ ] Clé privée copiée sur les VMs (`/var/lib/sops-nix/key.txt`)
- [ ] VMs déployées avec `nixos-rebuild switch`
- [ ] Test de connexion avec le mot de passe
- [ ] Clé privée sauvegardée en lieu sûr

## 🎉 C'est Fini !

Une fois tout ça fait, tes VMs sont configurées avec des mots de passe ultra-sécurisés chiffrés avec sops ! 🔒

Tes secrets sont dans le repo public GitHub, mais personne ne peut les lire sans ta clé privée.

Professionnel et sécurisé ! 💪

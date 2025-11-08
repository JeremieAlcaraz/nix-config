# Gestion des secrets avec sops-nix

Ce document explique comment gérer les secrets dans la configuration NixOS learnix en utilisant [sops-nix](https://github.com/Mic92/sops-nix).

## Vue d'ensemble

Les secrets (tokens, mots de passe, clés API) sont chiffrés avec **age** et déchiffrés automatiquement au déploiement par sops-nix. Chaque secret est chiffré avec les clés publiques des hôtes qui doivent y accéder.

## Prérequis

Installer les outils nécessaires :

```bash
# Sur NixOS
nix-shell -p sops age ssh-to-age

# Ou ajouter dans votre configuration personnelle
environment.systemPackages = with pkgs; [ sops age ssh-to-age ];
```

## Configuration initiale

### 1. Déployer l'hôte une première fois

Avant de configurer les secrets, déployez l'hôte jeremie-web pour générer ses clés SSH :

```bash
sudo nixos-rebuild switch --flake .#jeremie-web
```

À ce stade, le déploiement échouera probablement car le fichier de secrets n'existe pas encore. C'est normal.

### 2. Récupérer la clé publique age de l'hôte

Depuis l'hôte jeremie-web, récupérez la clé publique age :

```bash
# Option 1: Via SSH depuis votre machine locale
ssh root@jeremie-web "cat /var/lib/sops-nix/key.pub"

# Option 2: Convertir la clé SSH de l'hôte
ssh root@jeremie-web "cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age

# Option 3: Directement sur l'hôte
ssh root@jeremie-web
cat /var/lib/sops-nix/key.pub
```

La clé ressemble à : `age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 3. Mettre à jour .sops.yaml

Éditez `.sops.yaml` et remplacez la clé placeholder par la vraie clé publique :

```yaml
creation_rules:
  - path_regex: secrets/jeremie-web\.yaml$
    key_groups:
      - age:
          - &jeremie-web age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 4. Générer votre clé age personnelle (optionnel mais recommandé)

Pour pouvoir éditer les secrets depuis votre machine :

```bash
# Générer une clé age personnelle
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Afficher la clé publique
cat ~/.config/sops/age/keys.txt | grep "public key:"
```

Ajoutez votre clé publique dans `.sops.yaml` :

```yaml
creation_rules:
  - path_regex: secrets/jeremie-web\.yaml$
    key_groups:
      - age:
          - &jeremie-web age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
          - &admin age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy  # Votre clé
```

## Créer et chiffrer les secrets

### 1. Créer le fichier de secrets

```bash
# Copier le template
cp secrets/jeremie-web.yaml.example secrets/jeremie-web.yaml

# Éditer avec sops (chiffre automatiquement)
sops secrets/jeremie-web.yaml
```

### 2. Ajouter le token Cloudflare Tunnel

Dans l'éditeur sops, ajoutez votre token :

```yaml
cloudflare-tunnel-token: eyJhIjoiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX...
```

**Où trouver le token Cloudflare ?**

1. Connectez-vous à [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Allez dans **Access** → **Tunnels**
3. Créez un nouveau tunnel ou sélectionnez un tunnel existant
4. Dans la configuration du tunnel, cherchez le token dans :
   - L'onglet **Install and run a connector**
   - Ou copiez la commande d'installation et extrayez le token après `--token`

Le token est la longue chaîne après `cloudflared tunnel run --token` :
```bash
cloudflared tunnel run --token eyJhIjoiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX...
```

### 3. Sauvegarder et vérifier

Sauvegardez dans sops (`:wq` dans vim). Le fichier est maintenant chiffré :

```bash
# Vérifier que le fichier est chiffré
cat secrets/jeremie-web.yaml
# Devrait contenir "sops:" et des données chiffrées

# Vérifier qu'on peut le déchiffrer
sops -d secrets/jeremie-web.yaml
```

### 4. Committer le fichier chiffré

```bash
# Ajouter explicitement le fichier chiffré
git add -f secrets/jeremie-web.yaml

# Vérifier qu'il est bien chiffré avant de committer !
cat secrets/jeremie-web.yaml | grep "sops:"

# Committer
git commit -m "🔒 Add encrypted secrets for jeremie-web"
```

## Déploiement

Une fois les secrets configurés, déployez normalement :

```bash
# Sur la VM directement
sudo nixos-rebuild switch --flake .#jeremie-web

# Ou via déploiement distant
sudo nixos-rebuild switch --flake .#jeremie-web --target-host root@jeremie-web
```

sops-nix déchiffrera automatiquement les secrets au démarrage et les rendra disponibles dans `/run/secrets/`.

## Éditer les secrets

```bash
# Éditer le fichier chiffré
sops secrets/jeremie-web.yaml

# Ajouter/modifier des secrets
# Sauvegarder et committer
git add secrets/jeremie-web.yaml
git commit -m "🔒 Update secrets"
```

## Ajouter un nouveau secret

1. Éditez `hosts/jeremie-web/configuration.nix` :

```nix
sops.secrets = {
  cloudflare-tunnel-token = { ... };

  # Nouveau secret
  mon-api-key = {
    owner = "mon-service";
    group = "mon-service";
    mode = "0400";
  };
};
```

2. Ajoutez le secret dans le fichier chiffré :

```bash
sops secrets/jeremie-web.yaml
# Ajouter:
# mon-api-key: ma-valeur-secrète
```

3. Utilisez le secret dans votre configuration :

```nix
services.mon-service = {
  apiKeyFile = config.sops.secrets.mon-api-key.path;
};
```

## Ajouter un nouvel hôte

1. Créez `secrets/mon-host.yaml.example`
2. Ajoutez une règle dans `.sops.yaml` :

```yaml
- path_regex: secrets/mon-host\.yaml$
  key_groups:
    - age:
        - &mon-host age1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
```

3. Configurez sops dans `hosts/mon-host/configuration.nix` :

```nix
sops = {
  defaultSopsFile = ../../secrets/mon-host.yaml;
  age.keyFile = "/var/lib/sops-nix/key.txt";
  secrets = { ... };
};
```

## Rotation des clés

Si vous devez changer la clé d'un hôte (par exemple après une réinstallation) :

1. Récupérez la nouvelle clé publique age
2. Mettez à jour `.sops.yaml`
3. Re-chiffrez les secrets :

```bash
sops updatekeys secrets/jeremie-web.yaml
```

## Debugging

### Le secret n'est pas disponible

```bash
# Sur l'hôte, vérifier les secrets déchiffrés
ls -la /run/secrets/

# Vérifier les logs systemd
journalctl -u sops-nix-jeremie-web.service

# Vérifier la clé age
cat /var/lib/sops-nix/key.pub
```

### Erreur de déchiffrement

Vérifiez que :
- La clé publique dans `.sops.yaml` correspond à celle de l'hôte
- Le fichier secrets est bien chiffré avec cette clé
- Le fichier de clé privée existe sur l'hôte : `/var/lib/sops-nix/key.txt`

### Re-chiffrer avec les nouvelles clés

```bash
sops updatekeys secrets/jeremie-web.yaml
```

## Sécurité

- ✅ Les fichiers chiffrés peuvent être committés dans git
- ✅ Chaque hôte ne peut déchiffrer que ses propres secrets
- ❌ Ne JAMAIS committer les fichiers `.yaml` non chiffrés
- ❌ Ne JAMAIS committer les clés privées (`.txt`)
- ✅ Gardez votre clé privée personnelle en sécurité (`~/.config/sops/age/keys.txt`)
- ✅ Utilisez `.gitignore` dans `secrets/` pour éviter les accidents

## Ressources

- [Documentation sops-nix](https://github.com/Mic92/sops-nix)
- [Documentation sops](https://github.com/getsops/sops)
- [Documentation age](https://github.com/FiloSottile/age)
- [Guide Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

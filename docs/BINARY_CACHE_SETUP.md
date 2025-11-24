# Binary Cache Setup Guide

Ce guide explique comment configurer le système de binary cache avec nix-serve pour accélérer les déploiements.

## Architecture

```
┌──────────────┐                    ┌──────────────┐
│   magnolia   │  ← build machine   │    mimosa    │  ← web server
│              │                     │              │
│  nix-serve   │ ────────────────→  │   client     │
│  :5000       │    Tailscale       │              │
└──────────────┘                    └──────────────┘
```

- **magnolia** : Serveur de cache (nix-serve) qui stocke les packages pré-compilés
- **mimosa** : Client qui télécharge depuis magnolia au lieu de rebuilder
- **Tailscale** : Réseau privé pour la communication sécurisée

## Étape 1 : Configuration du serveur de cache (magnolia)

### 1.1 Générer les clés de signature

Sur magnolia, exécutez :

```bash
# Créer le répertoire pour les clés
sudo mkdir -p /var/cache-keys

# Générer la paire de clés (publique + privée)
sudo nix-store --generate-binary-cache-key magnolia.cache /var/cache-keys/cache-private-key.pem /var/cache-keys/cache-public-key.pem

# Protéger la clé privée
sudo chmod 600 /var/cache-keys/cache-private-key.pem

# Afficher la clé publique (à noter pour les clients)
sudo cat /var/cache-keys/cache-public-key.pem
```

**Important** : Notez la clé publique affichée (format : `magnolia.cache:XXXXXX...XXXXX=`)

### 1.2 Créer le module nix-serve

Créez `/etc/nixos/modules/nix-serve.nix` :

```nix
{ config, lib, ... }:

{
  # Active le serveur de cache binaire Nix
  services.nix-serve = {
    enable = true;

    # Port d'écoute (accessible via Tailscale)
    port = 5000;

    # Clé privée pour signer les packages
    secretKeyFile = "/var/cache-keys/cache-private-key.pem";

    # Écoute sur toutes les interfaces (nécessaire pour Tailscale)
    bindAddress = "0.0.0.0";
  };

  # Ouvre le port 5000 dans le firewall
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
```

### 1.3 Activer le module

Dans `/etc/nixos/hosts/magnolia/configuration.nix`, ajoutez :

```nix
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nix-serve.nix  # ← Ajouter cette ligne
    # ... autres imports
  ];
}
```

### 1.4 Appliquer la configuration

```bash
sudo nixos-rebuild switch --flake .#magnolia
```

### 1.5 Vérifier que nix-serve fonctionne

```bash
# Vérifier le service
systemctl status nix-serve

# Tester l'accès local
curl http://localhost:5000/nix-cache-info

# Devrait afficher :
# StoreDir: /nix/store
# WantMassQuery: 1
# Priority: 30
```

## Étape 2 : Configuration des clients (mimosa, etc.)

### 2.1 Ajouter la configuration du cache

Dans `/etc/nixos/hosts/mimosa/configuration.nix`, ajoutez :

```nix
{
  nix.settings = {
    sandbox = true;
    ssl-cert-file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    extra-sandbox-paths = [ "/etc/resolv.conf" ];

    # Binary caches : sources de packages pré-compilés
    substituters = [
      "https://cache.nixos.org"  # Cache officiel (fallback)
      "http://magnolia:5000"     # Notre cache local (prioritaire)
    ];

    # Clés publiques pour vérifier les signatures
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "magnolia.cache:XXXXXX...XXXXX="  # ← Remplacer par votre clé publique
    ];
  };
}
```

**Important** : Remplacez `magnolia.cache:XXXXXX...XXXXX=` par la clé publique obtenue à l'étape 1.1

### 2.2 Appliquer la configuration

```bash
sudo nixos-rebuild switch --flake .#mimosa
```

### 2.3 Tester la connexion au cache

```bash
# Vérifier que mimosa peut contacter magnolia
nix store ping --store http://magnolia:5000

# Devrait afficher :
# Store URL: http://magnolia:5000

# Tester la récupération d'un package
nix path-info --store http://magnolia:5000 $(which bash)
```

## Étape 3 : Utilisation du cache

### Peupler le cache sur magnolia

Pour que le cache serve des packages, il faut d'abord les builder sur magnolia :

```bash
# Exemple : builder j12zdotcom sur magnolia
nix build github:JeremieAlcaraz/j12zdotcom#site

# Le package est maintenant dans /nix/store de magnolia
# nix-serve le sert automatiquement aux clients
```

### Déployer sur les clients

Quand vous déployez sur mimosa :

```bash
sudo nixos-rebuild switch --flake .#mimosa
```

**Ce qui se passe :**
1. Nix interroge magnolia : "Tu as ce package ?"
2. Si oui : téléchargement depuis magnolia (rapide !)
3. Si non : téléchargement depuis cache.nixos.org ou build local

### Vérifier que le cache est utilisé

```bash
# Rebuild avec logs verbeux
nix build ... --verbose 2>&1 | grep magnolia

# Vous devriez voir :
# copying path '...' from 'http://magnolia:5000'...
# downloading 'http://magnolia:5000/nar/...'
```

## Étape 4 : Reproduction sur une nouvelle VM

### 4.1 Nouvelle VM "jasmine"

```bash
# Sur jasmine
git clone https://github.com/JeremieAlcaraz/nix-config /etc/nixos
cd /etc/nixos

# Générer hardware-configuration.nix
nixos-generate-config --show-hardware-config > hosts/jasmine/hardware-configuration.nix

# Créer configuration.nix (copier depuis mimosa)
cp hosts/mimosa/configuration.nix hosts/jasmine/configuration.nix

# Éditer pour changer le hostname
sed -i 's/mimosa/jasmine/g' hosts/jasmine/configuration.nix
```

### 4.2 Ajouter dans flake.nix

```nix
nixosConfigurations = {
  # ... configs existantes

  jasmine = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit j12z-site; };
    modules = [
      ./hosts/jasmine/configuration.nix
      # Importer les modules nécessaires
    ];
  };
};
```

### 4.3 Déployer

```bash
# Sur jasmine
sudo nixos-rebuild switch --flake .#jasmine

# Le cache magnolia sera automatiquement utilisé !
# Pas besoin de tout rebuilder
```

## Avantages du binary cache

✅ **Rapidité** : Téléchargement vs compilation (secondes vs minutes)
✅ **Cohérence** : Même build sur toutes les VMs
✅ **Économie** : Moins de CPU/RAM utilisés
✅ **Simplicité** : Automatique une fois configuré

## Dépannage

### Le cache ne répond pas

```bash
# Vérifier que nix-serve tourne sur magnolia
ssh magnolia 'systemctl status nix-serve'

# Vérifier le firewall
ssh magnolia 'sudo nft list ruleset | grep 5000'

# Vérifier Tailscale
ping magnolia
```

### Les packages ne sont pas trouvés

```bash
# Vérifier que le package existe sur magnolia
ssh magnolia 'ls /nix/store/*nom-du-package*'

# Forcer la reconstruction du cache info
ssh magnolia 'sudo systemctl restart nix-serve'
```

### Erreur de signature

```bash
# Vérifier que la clé publique est correcte
cat /etc/nixos/hosts/mimosa/configuration.nix | grep magnolia.cache

# Comparer avec la clé sur magnolia
ssh magnolia 'sudo cat /var/cache-keys/cache-public-key.pem'
```

## Maintenance

### Nettoyer le cache

```bash
# Sur magnolia (libérer de l'espace)
sudo nix-collect-garbage -d

# Garder seulement les 30 derniers jours
sudo nix-collect-garbage --delete-older-than 30d
```

### Monitorer l'utilisation

```bash
# Voir les logs de nix-serve
ssh magnolia 'journalctl -u nix-serve -f'

# Voir l'espace disque utilisé
ssh magnolia 'du -sh /nix/store'
```

## Références

- [NixOS Binary Cache](https://nixos.org/manual/nix/stable/package-management/binary-cache.html)
- [nix-serve documentation](https://github.com/edolstra/nix-serve)
- [Nix Substituters](https://nixos.wiki/wiki/Binary_Cache)

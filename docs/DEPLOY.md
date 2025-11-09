# Déploiement sur une nouvelle machine

Guide rapide pour déployer votre configuration NixOS sur une machine fraîche.

## 🚀 Installation rapide

### 1. Installation de NixOS minimale

Installez NixOS avec la configuration minimale. Créez juste un utilisateur root, la config NixOS créera les autres utilisateurs.

### 2. Premier déploiement (depuis la console Proxmox)

```bash
# En tant que root dans la console Proxmox
git clone https://github.com/JeremieAlcaraz/nix-config.git /root/nix-config
cd /root/nix-config

# Pour jeremie-web
nixos-rebuild switch --flake .#jeremie-web

# Pour proxmox
nixos-rebuild switch --flake .#proxmox
```

### 3. Vérification

```bash
# Vérifier le hostname
hostnamectl

# Tester la connexion SSH depuis votre Mac
ssh jeremie@IP_DE_LA_VM
```

## 🔄 Déploiements suivants

```bash
# Depuis la VM (SSH)
ssh jeremie@IP_DE_LA_VM
cd ~/nix-config
git pull
sudo nixos-rebuild switch --flake .#jeremie-web  # ou .#proxmox
```

## ⚠️ Important

**Toujours spécifier le nom de l'host** après `#` dans la commande `nixos-rebuild` :
- `--flake .#jeremie-web` pour jeremie-web
- `--flake .#proxmox` pour proxmox

Sans cela, NixOS ne saura pas quelle configuration utiliser et pourrait garder le hostname par défaut "nixos".

## 🔑 Premiers accès

- **Utilisateur** : `jeremie`
- **Mot de passe initial** : `nixos` (seulement pour le premier boot)
- **SSH** : Authentification par clé publique uniquement
- **Sudo** : Pas de mot de passe requis (après le premier déploiement)

## 📝 Créer un nouvel host

1. Créer le dossier : `hosts/mon-nouveau-host/`
2. Copier `configuration.nix` et `hardware-configuration.nix` depuis un host existant
3. Modifier `networking.hostName = "mon-nouveau-host";`
4. Ajouter la configuration dans `flake.nix` :

```nix
nixosConfigurations = {
  # ... configs existantes ...

  mon-nouveau-host = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ./hosts/mon-nouveau-host/configuration.nix
    ];
  };
};
```

5. Déployer :

```bash
nixos-rebuild switch --flake .#mon-nouveau-host
```

## 📚 Documentation complète

Pour plus de détails sur le bootstrap, les VMs Proxmox et les secrets, consultez :
- [BOOTSTRAP.md](./BOOTSTRAP.md) - Guide complet du bootstrap
- [SECRETS.md](./SECRETS.md) - Gestion des secrets avec sops

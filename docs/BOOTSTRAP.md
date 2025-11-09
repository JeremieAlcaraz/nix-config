# Workflow de Bootstrap pour les VMs NixOS

Ce document décrit le workflow recommandé pour créer et configurer de nouvelles VMs NixOS dans Proxmox.

## Philosophie

En NixOS, on utilise **`initialPassword`** plutôt que `password` pour les utilisateurs. Cette option :
- ✅ Définit un mot de passe **uniquement lors de la première création**
- ✅ N'est **jamais réécrit** lors des déploiements suivants
- ✅ Permet de bootstrap la VM avant d'activer `wheelNeedsPassword = false`
- ✅ Évite le problème de la poule et l'œuf

## Workflow complet : Créer une nouvelle VM

### 1. Installation initiale de NixOS

```bash
# Lors de l'installation NixOS minimale, créer juste un utilisateur root
# Pas besoin de créer d'autres utilisateurs, la config NixOS s'en chargera
```

### 2. Créer la configuration dans nix-config

```nix
# Dans nix-config/hosts/mon-nouveau-host/configuration.nix
{
  # ... configuration de base ...

  users.users.jeremie = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Mot de passe initial pour bootstrap (utilisé une seule fois)
    initialPassword = "nixos";
    # Clé SSH pour se connecter après le bootstrap
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3Nza... jeremie@mac"
    ];
  };

  # Sudo sans mot de passe après le bootstrap
  security.sudo.wheelNeedsPassword = false;
}
```

### 3. Premier déploiement (Bootstrap)

**Option A : Depuis la console Proxmox (recommandé)**

```bash
# Dans la console Proxmox, en tant que root
git clone https://github.com/JeremieAlcaraz/nix-config.git /root/nix-config
cd /root/nix-config
nixos-rebuild switch --flake .#mon-nouveau-host
```

**Option B : Via SSH avec l'utilisateur bootstrap**

```bash
# SSH en tant que jeremie (mot de passe: nixos)
ssh jeremie@IP_DE_LA_VM
# Mot de passe: nixos

cd ~
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config
sudo nixos-rebuild switch --flake .#mon-nouveau-host
# Mot de passe sudo: nixos (une seule fois)
```

### 4. Après le bootstrap

Après le premier déploiement :
- ✅ `wheelNeedsPassword = false` est activé
- ✅ Sudo ne demande plus de mot de passe
- ✅ SSH fonctionne avec la clé publique
- ✅ L'`initialPassword` ne sera jamais réécrit

**Le mot de passe initial reste actif** (pour dépannage si besoin), mais n'est plus nécessaire pour sudo.

### 5. Déploiements suivants

```bash
# Depuis ton Mac ou n'importe où
ssh jeremie@IP_DE_LA_VM
cd ~/nix-config
git pull
sudo nixos-rebuild switch --flake .#mon-nouveau-host
# ✨ Pas de mot de passe demandé !
```

## Clonage de VMs Proxmox

Lorsque tu clones une VM dans Proxmox :

### Problème
Les VMs clonées gardent :
- Les mêmes clés SSH de l'hôte → ⚠️ **Problème de sécurité !**
- Le même hostname
- La même configuration réseau

### Solution : Régénérer les identifiants

Après avoir cloné une VM :

```bash
# 1. Console Proxmox, boot la VM clonée, connecte-toi en root

# 2. Supprimer les anciennes clés SSH de l'hôte
rm /etc/ssh/ssh_host_*

# 3. Régénérer les clés SSH
ssh-keygen -A

# 4. Changer le hostname temporairement
hostnamectl set-hostname nouveau-nom

# 5. Cloner le repo et déployer la nouvelle config
cd /root
git clone https://github.com/JeremieAlcaraz/nix-config.git
cd nix-config
nixos-rebuild switch --flake .#nouveau-host

# 6. Récupérer la nouvelle clé age pour sops
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"

# 7. Mettre à jour .sops.yaml et les secrets dans le repo
# 8. Pull et redéployer
```

## Template de configuration pour nouveaux hôtes

```nix
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Système
  networking.hostName = "mon-host";
  time.timeZone = "Europe/Paris";
  system.stateVersion = "24.05";

  # Réseau
  networking.useDHCP = true;
  networking.firewall.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };

  # Utilisateur avec bootstrap
  users.users.jeremie = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nixos";  # Bootstrap uniquement
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac"
    ];
  };

  # Sudo sans mot de passe (après bootstrap)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Paquets de base
  environment.systemPackages = with pkgs; [
    vim git curl wget htop
  ];
}
```

## Bonnes pratiques

### ✅ Faire
- Utiliser `initialPassword` pour le bootstrap
- Activer `wheelNeedsPassword = false` pour l'usage quotidien
- Régénérer les clés SSH lors du clonage
- Documenter le mot de passe initial dans la config (c'est public et temporaire)
- Mettre à jour les secrets sops pour chaque nouvel hôte

### ❌ Ne pas faire
- Utiliser `password` (réécrit à chaque déploiement)
- Laisser `wheelNeedsPassword = true` en production
- Cloner des VMs sans régénérer les clés SSH
- Utiliser le même mot de passe pour plusieurs environnements critiques
- Oublier de mettre à jour `.sops.yaml` pour les nouveaux hôtes

## Sécurité

Cette approche est sécurisée car :
- 🔐 SSH n'autorise que l'authentification par clé (PasswordAuthentication = false)
- 🔐 Root login désactivé via SSH
- 🔐 Le mot de passe initial est simple (car SSH le rend inutile)
- 🔐 Sudo sans mot de passe OK car l'accès SSH est déjà sécurisé
- 🔐 Chaque hôte a ses propres clés SSH uniques
- 🔐 Les secrets sont chiffrés avec sops par hôte

## Aide rapide

| Situation | Solution |
|-----------|----------|
| Première installation | Console Proxmox + `nixos-rebuild switch` en root |
| VM clonée | Régénérer clés SSH + déployer nouvelle config |
| Mot de passe oublié | Utiliser SSH avec clé + sudo sans mot de passe |
| Sudo demande mot de passe | Vérifier `wheelNeedsPassword = false` déployé |
| Secrets ne fonctionnent pas | Régénérer clé age + mettre à jour `.sops.yaml` |

## Ressources

- [NixOS Manual - User Management](https://nixos.org/manual/nixos/stable/#sec-user-management)
- [NixOS Wiki - SSH](https://nixos.wiki/wiki/SSH)
- [docs/SECRETS.md](./SECRETS.md) - Gestion des secrets avec sops

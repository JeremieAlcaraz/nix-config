# 🚀 Getting Started - Démarrage Rapide

Guide express pour déployer votre première VM NixOS en **10 minutes**.

## 📋 Prérequis

- Serveur Proxmox avec ISO NixOS 24.11
- VM créée avec :
  - 2 CPU, 2 GB RAM minimum
  - 32 GB disque minimum
  - Boot UEFI activé
  - ISO NixOS montée

## ⚡ Installation Express

### Étape 1 : Télécharger le script (1 min)

Depuis la console de votre VM bootée sur l'ISO NixOS :

```bash
curl -L https://raw.githubusercontent.com/JeremieAlcaraz/nix-config/main/scripts/install-nixos.sh -o install.sh
chmod +x install.sh
```

### Étape 2 : Lancer l'installation (5-8 min)

```bash
sudo ./install.sh <hostname>
```

Remplacez `<hostname>` par le nom de votre VM. Exemples :
- `magnolia` (infrastructure Proxmox)
- `mimosa` (serveur web)
- `whitelily` (n8n production)
- Ou n'importe quel nom personnalisé

**Le script va automatiquement :**
1. ✅ Partitionner et formater le disque
2. ✅ Générer `hardware-configuration.nix`
3. ✅ Cloner ce repository
4. ✅ Installer NixOS avec la configuration
5. ✅ Éteindre la VM

### Étape 3 : Démarrer la VM (1 min)

1. Dans Proxmox : **retirer l'ISO** (Hardware > CD/DVD > Remove)
2. Redémarrer la VM
3. Trouver l'IP de la VM (dans Proxmox ou via DHCP)
4. Se connecter :

```bash
ssh jeremie@<IP_DE_LA_VM>
# Mot de passe : nixos
```

## ✅ C'est terminé !

Votre VM NixOS est installée et fonctionnelle.

### Prochaines étapes

**Changer le mot de passe :**
```bash
passwd
```

**Mettre à jour la configuration :**
```bash
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#<hostname>
```

**Gérer des secrets :**
Voir [SECRETS.md](./SECRETS.md)

**Déployer des services (n8n, etc.) :**
Voir [DEPLOYMENT.md](./DEPLOYMENT.md) - Section Services

## 🔑 Informations de connexion

| Info | Valeur |
|------|--------|
| **Utilisateur** | `jeremie` |
| **Mot de passe initial** | `nixos` |
| **SSH** | Clé publique uniquement (après le premier boot) |
| **Sudo** | Pas de mot de passe requis |

### Clé SSH autorisée

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmKLrSci3dXG3uHdfhGXCgOXj/ZP2wwQGi36mkbH/YM jeremie@mac
```

## 🆘 Problèmes courants

### Le script échoue sur le partitionnement

**Cause** : Disque déjà partitionné

**Solution** :
```bash
# Nettoyer le disque manuellement
sudo wipefs -a /dev/sda
# Relancer le script
sudo ./install.sh <hostname>
```

### Cannot find hostname in flake.nix

**Cause** : Le hostname n'existe pas dans la configuration

**Solution** : Vérifier les hostnames disponibles :
- `magnolia`
- `mimosa`
- `whitelily`

Ou créer un nouveau host (voir [DEPLOYMENT.md](./DEPLOYMENT.md) - Section "Créer un nouvel host")

### Connexion SSH refuse la connexion

**Cause** : SSH n'est pas encore démarré ou mauvaise IP

**Solutions** :
1. Vérifier que la VM a bien redémarré
2. Vérifier l'IP dans Proxmox (Summary > IPs)
3. Tester la connectivité : `ping <IP>`

### Mot de passe refusé

**Cause** : Le mot de passe initial n'a pas été défini correctement

**Solution** :
1. Accéder via la console Proxmox
2. Réinitialiser le mot de passe : `passwd jeremie`
3. Réessayer la connexion SSH

## 📚 Documentation complète

Pour aller plus loin :
- **Déploiement avancé** : [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Gestion des secrets** : [SECRETS.md](./SECRETS.md)
- **Index complet** : [README.md](./README.md)

## 🎯 Workflows Rapides

### Cloner une VM existante (méthode la plus rapide !)

Au lieu d'installer depuis zéro, vous pouvez cloner une VM existante dans Proxmox :

1. Clic droit sur une VM > **Clone** > Full Clone
2. Démarrer la VM clonée
3. Se connecter en SSH
4. Appliquer la nouvelle configuration :

```bash
cd /etc/nixos
git pull
sudo nixos-rebuild switch --flake .#nouveau-hostname
sudo reboot
```

Voir [DEPLOYMENT.md](./DEPLOYMENT.md) - Section "Clonage de VM" pour les détails.

### Déployer whitelily (n8n) avec secrets

Pour déployer whitelily avec tous les secrets générés automatiquement :

```bash
# Depuis l'ISO NixOS
sudo ./install.sh whitelily
```

Le script va vous demander :
- Token Cloudflare Tunnel
- Domaine n8n
- Utilisateur n8n

Et générer automatiquement tous les secrets chiffrés.

Voir [DEPLOYMENT.md](./DEPLOYMENT.md) - Section "Services > n8n" pour le guide complet.

---

**Bon déploiement ! 🎉**

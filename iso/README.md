# 💿 ISO NixOS minimale pour Proxmox/NoVNC

Ce dossier contient la configuration pour générer une ISO NixOS personnalisée avec support de la console série (ttyS0), optimisée pour Proxmox et NoVNC.

## 🎯 Pourquoi cette ISO ?

L'ISO standard NixOS ne configure pas la console série par défaut, ce qui rend l'utilisation dans Proxmox/NoVNC problématique. Cette ISO personnalisée résout ce problème en activant `ttyS0` dès le boot.

## 🚀 Utilisation rapide

### Builder l'ISO

```bash
# Depuis ce dossier
nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage

# L'ISO sera disponible dans
ls -lh result/iso/
```

### Caractéristiques de l'ISO

- ✅ Console série (ttyS0) active automatiquement
- ✅ Autologin utilisateur `nixos`
- ✅ ZSH + Starship comme shell
- ✅ Environnement X11 minimal (xterm + twm)
- ✅ SSH activé avec mot de passe (user: nixos, pass: nixos)
- ✅ Réseau DHCP automatique
- ✅ Outils de base : vim, git, curl, wget, htop, tree

## 📖 Documentation complète

Pour un guide détaillé avec instructions pas-à-pas depuis une VM, consultez :

**[../docs/ISO-BUILDER.md](../docs/ISO-BUILDER.md)**

## 🎨 Personnalisation

Le fichier `flake.nix` est entièrement modulable. Vous pouvez :

- Ajouter des packages dans `environment.systemPackages`
- Changer le shell par défaut
- Activer des services supplémentaires
- Modifier le nom de l'ISO dans `isoImage`

Après modification, rebuildez simplement avec la même commande.

## 📦 Résultat

L'ISO générée pèse environ **950 MB** et contient tout le nécessaire pour :

- Installer NixOS sur une nouvelle machine
- Tester une configuration
- Faire du rescue/debugging
- Utiliser comme live USB avec persistance

## 🔬 Détails techniques

### Paramètres de boot

```nix
boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
```

- `console=ttyS0,115200n8` : Active le port série à 115200 bauds
- `console=tty1` : Garde aussi la console VGA standard

### Architecture

```
ISO
├── Kernel avec params série
├── initrd
├── NixOS base
│   ├── Getty sur ttyS0 (autologin)
│   ├── Getty sur tty1
│   └── Getty sur tty2
├── X11 (xterm + twm)
└── Outils (vim, git, etc.)
```

## 🤝 Contribution

Des idées pour améliorer cette ISO ? Ouvre une issue ou une PR !

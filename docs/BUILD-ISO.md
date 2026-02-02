# Build ISO

## But

Ce guide explique comment regenerer l'ISO d'installation NixOS adapte a Proxmox (console serie ttyS0) et comment recuperer le fichier sur le Mac.

## Script

Depuis le dossier `iso/` :

```bash
./build-iso.sh
```

Options utiles:

```bash
./build-iso.sh --sync    # par defaut, aligne l'ISO sur le flake principal
./build-iso.sh --update  # met a jour nixpkgs dans l'ISO
```

## Resultat attendu

Le script genere une copie datee dans `iso/` :

```
nixos-installer-ttyS0-YYYY-MM-DD.iso
```

## Recuperer l'ISO sur le Mac (marigold)

Depuis magnolia:

```bash
scp /etc/nixos/iso/nixos-installer-ttyS0-YYYY-MM-DD.iso marigold:~/Downloads/
```

Ensuite, tu peux uploader l'ISO sur Proxmox ou l'attacher a une VM.

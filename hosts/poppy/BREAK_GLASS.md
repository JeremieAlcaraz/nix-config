# BREAK-GLASS — restauration d'urgence (poppy)

Objectif: pouvoir restaurer vite si `poppy` est perdu/inaccessible.

## 1) Ce qu'il faut absolument avoir (hors serveur)

- `RESTIC_PASSWORD` (clé de chiffrement restic)
- accès Drive/rclone (`gdrive_capsule`)
- accès SSH d'urgence vers une machine de recovery
- ce guide + `hosts/poppy/URGENT_RESTORE.md`

Sans `RESTIC_PASSWORD`, **pas de restore possible**.

## 2) Où est la clé aujourd'hui

Sur poppy:
- fichier: `/root/.config/restic/env`
- variable utilisée: `RESTIC_PASSWORD`

## 3) Procédure d'urgence minimale

1. Vérifier l'accès aux repos restic:
   ```bash
   export RESTIC_PASSWORD='***'
   for r in garage memos vikunja moodboard twenty; do
     restic snapshots --repo "rclone:gdrive_capsule:$r" --compact | tail -n 5
   done
   ```
2. Restaurer stack-aware (garage-first pour apps S3):
   ```bash
   just --justfile hosts/poppy/justfile restore-stack app=memos
   # ou moodboard / twenty / vikunja
   ```
3. Vérifier services:
   ```bash
   systemctl is-active garage.service memos.service moodboard.service twenty.service vikunja.service
   ```

## 4) Politique recommandée de conservation de la clé

- Copier `RESTIC_PASSWORD` dans un gestionnaire de secrets (vault/password manager)
- Ajouter une copie scellée (offline)
- Limiter l'accès au strict nécessaire (2 personnes max)
- Rotation uniquement planifiée + test de restore immédiat

## 5) Test trimestriel "break-glass"

- Lancer la batterie complète:
  ```bash
  just --justfile hosts/poppy/justfile smoke-all
  ```
- Archiver le rapport:
  - `/var/log/restic-smoke-restore-all-report-*.md`
- Valider que le dernier rapport est PASS.

# Guide d'urgence — Restore Poppy (restic-only)

Ce guide est volontairement court pour une situation incident.

## 0) Règle clé: dépendance Garage (S3)

Services dépendants de Garage (objets S3):
- `memos`
- `moodboard`
- `twenty`

Service sans dépendance Garage:
- `vikunja`

👉 Pour `memos`, `moodboard`, `twenty`: **restaurer Garage d'abord**.

---

## 1) Pré-check rapide

```bash
ssh poppy
systemctl is-active garage.service memos.service moodboard.service twenty.service vikunja.service
RESTIC_PASSWORD="$(grep ^RESTIC_PASSWORD= /root/.config/restic/env | tr -d "'" | cut -d= -f2)"; export RESTIC_PASSWORD
for repo in memos vikunja moodboard twenty; do
  echo "=== $repo ==="
  restic snapshots --repo "rclone:gdrive_capsule:$repo" --compact | tail -n 6
done
```

---

## 2) Restore recommandé (stack-aware)

Depuis la machine opérateur (repo local):

```bash
just --justfile hosts/poppy/justfile restore-stack app=memos
# ou moodboard / twenty / vikunja
```

- Pour `memos|moodboard|twenty`, le flux propose un restore `garage-first`.
- Pour `vikunja`, le flux fait un restore app-only.

---

## 3) Restore expert (app-only)

```bash
just --justfile hosts/poppy/justfile restore
```

À éviter pour apps S3 dépendantes si Garage n'est pas déjà restauré.

---

## 4) Validation post-restore

```bash
ssh poppy
systemctl is-active garage.service memos.service moodboard.service twenty.service vikunja.service

RESTIC_PASSWORD="$(grep ^RESTIC_PASSWORD= /root/.config/restic/env | tr -d "'" | cut -d= -f2)"; export RESTIC_PASSWORD
for repo in memos vikunja moodboard twenty; do
  echo "=== $repo ==="
  restic snapshots --repo "rclone:gdrive_capsule:$repo" --compact | tail -n 6
done
```

Validation fonctionnelle minimale:
- memos: ouvrir notes + pièce jointe
- moodboard: ouvrir un board avec assets
- twenty: ouvrir app + vérifier fichiers
- vikunja: vérifier tâches/fichiers

---

## 5) État actuel important (à date)

- Backups restic actifs pour `memos|vikunja|moodboard|twenty`.
- Flux `restore-stack` disponible.
- ✅ Backup restic **Garage** dédié activé (`garage-restic-backup.timer`).

Conséquence: les restores `garage-first` pour apps S3 dépendantes sont désormais couverts de bout en bout.

---

## 6) En cas d'urgence sévère

1. Ne rien supprimer.
2. Restaurer vers un dossier temporaire si doute.
3. Consulter logs:

```bash
tail -n 200 /var/log/restic-restore.log
tail -n 200 /var/log/restic-restore-stack.log
```

4. Refaire un restore d'un snapshot plus ancien si nécessaire.

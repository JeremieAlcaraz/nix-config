# Epic spec — Déployer Twenty CRM sur Poppy

## Contexte
Twenty CRM tourne actuellement en local sur Desktop (docker-compose). L'objectif est de le migrer sur le serveur Poppy avec une stack 100% déclarative via nix-config + SOPS + podman-compose, comme les autres apps (memos, vikunja, moodboard).

## Problème
Twenty n'est pas déployé sur Poppy, donc inaccessible via Tailscale depuis l'extérieur. De plus, le `.env` et `docker-compose.yml` sont sur Desktop — il faut extraire le strict nécessaire pour le déploiement sans copier tout le projet.

## Objectifs
- Extraire uniquement `docker-compose.yml` et `.env` du projet Desktop
- Adapter `docker-compose.yml` → `podman-compose.yml` (runtime podman, pas docker)
- Créer le bucket Garage S3 `twenty` et la key `twenty-app`
- Stocker les secrets dans SOPS (`apps.twenty.*`)
- Générer `.env` depuis template SOPS (pattern memos/moodboard)
- Créer service systemd + timer backup (style `memos-s3-backup.timer`)
- Ajouter drift detection dans `poppy-check.sh`
- Service Tailscale via `tailscale-service-golden-path` skill

## Non-objectifs
- Ne PAS copier tout le projet Twenty (/Users/jeremiealcaraz/Desktop/twenty)
- Ne PAS modifier le projet Desktop (reste en local)
- Pas de migrate de données existantes (fresh deploy)

## Scope
- Extraction: `docker-compose.yml`, `.env` (seuls ces 2 fichiers)
- SOPS: secrets twenty (APP_SECRET, PG_PASSWORD, GOOGLE_*)
- Garage S3: bucket `twenty`, key `twenty-app`
- Deployment: compose + env + systemd + scripts
- Tailscale: svc:twenty → https://twenty.inanga-sirius.ts.net

## Hors scope
- Migration de données depuis Desktop
- Modification du projet source Desktop
- Monitoring / Grafana pour twenty (sujet futur)
- Intégration avec moodboard ou memos

## Critères d'acceptation
- [ ] Twenty accessible via `https://twenty.inanga-sirius.ts.net`
- [ ] Tous les secrets dans SOPS (jamais en clair)
- [ ] `just poppy-apply` fonctionne (deploy idempotent)
- [ ] `just poppy-check` passe (drift + timer)
- [ ] Storage S3 fonctionnel (bucket twenty dans Garage)
- [ ] Backup timer active (dump SQL + sync S3 → Drive)

## Risques
- Collision de ports si 5432 ou 3000 déjà pris → reviewer les ports
- Credentials Google OAuth tied to localhost → ajuster CALLBACK_URL

## Dépendances
- Garage S3 déjà opérationnel sur Poppy
- SOPS age key fonctionnelle
- Tailscale magic DNS configuré

## Questions ouvertes
- Quel port pour twenty-server ? (3000 ? autre ?)
- Backup SQL vingt/quinze minutes ?

## Definition of done
- [x] Spec validated
- [ ] Tasks plan validated
- [ ] Lot issues ready
# Backlog V2 - poppy

## Objectif

Durcir l'exploitation de `poppy` apres la baseline documentaire v1.

## Priorites

1. Migrer le cron vers `systemd timer` pour un pilotage plus propre (etat, logs, retry).
2. Ajouter des garde-fous pre-sync (`rclone --dry-run` optionnel, checks de cible).
3. Centraliser les logs et alertes (integrer avec stack observabilite existante).
4. Clarifier le cycle de retention (PBS + miroir Drive) et documenter impacts.
5. Documenter/automatiser la procedure de re-auth OAuth `rclone`.
6. Capturer le nom exact de l'ISO d'installation PBS dans la doc.

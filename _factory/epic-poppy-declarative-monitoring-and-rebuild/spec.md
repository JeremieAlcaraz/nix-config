# [EPIC] Rendre poppy déclarative pour monitoring, inventaire et réinstallation PBS

## Contexte
`poppy` est un hôte Debian (PBS) non-NixOS. Il est déjà documenté dans le repo, mais il manque encore une couverture déclarative complète équivalente aux autres hosts côté observabilité et exploitabilité.

## Problème
- Les métriques de `poppy` ne remontent pas actuellement dans Grafana/VictoriaMetrics.
- Une partie de l'état métier (`/apps`, scripts de backup) n'est pas encore capturée de manière structurée et versionnée.
- Le README host n'est pas encore au niveau “rebuild-ready” (rôle, noyau/distro, version PBS, procédure de réinstallation rapide).

## Objectifs
1. Afficher `poppy` dans Grafana avec CPU/RAM/stockage/uptime comme les autres hosts.
2. Capturer et versionner l'inventaire des apps et scripts de backup de `poppy`.
3. Renforcer la documentation host pour réinstallation et recovery rapides.
4. Garder une approche 100% déclarative dans le repo, sans transformer `poppy` en NixOS.

## Non-objectifs
- Migrer `poppy` vers NixOS.
- Refondre complètement l'architecture PBS.

## Résultat attendu
- `up{host="poppy"}` stable à `1` dans VictoriaMetrics.
- Dashboards Grafana affichant `poppy` comme les autres hosts monitorés.
- Dossier `hosts/poppy/` enrichi (README, runbook, inventaire apps, backup scripts déclarés).
- Procédure de réinstallation PBS documentée de bout en bout.

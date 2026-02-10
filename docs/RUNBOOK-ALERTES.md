# Runbook Alertes - Myosotis

Guide operationnel : que faire quand une alerte Grafana se declenche.

---

## Acces rapide

- **Grafana** : https://myosotis.inanga-sirius.ts.net (admin / mot de passe sops)
- **Alertes actives** : Grafana > Alerting > Alert rules
- **Silencer une alerte** : Grafana > Alerting > Silences > New silence

---

## Architecture de reference

```
magnolia (builder)  ─┐
hawthorn (gateway)  ─┤
mimosa (web)        ─┤── Node Exporter :9100 ──► VictoriaMetrics (myosotis:8428)
dandelion (gitea)   ─┤── Promtail ──────────────► Loki (myosotis:3100)
whitelily (n8n)     ─┤
rhizanthella (bknd) ─┤
muscari (proxmox)   ─┤── Node Exporter :9100 (binaire statique)
crocus (proxmox)    ─┘
```

**Notifications** : severity=critical → email + slack | severity=warning/info → slack uniquement
**Repeat interval** : rappel toutes les 24h tant que l'alerte est active

---

## Commandes utiles (a connaitre)

### Connexion aux hosts

```bash
# NixOS VMs (depuis magnolia ou Mac)
ssh magnolia / hawthorn / mimosa / dandelion / whitelily / myosotis

# Proxmox nodes (SSH en root)
ssh root@muscari
ssh root@crocus

# rhizanthella (souvent offline)
ssh rhizanthella
```

### Verification rapide d'un host

```bash
# CPU / RAM / disque en temps reel
htop

# Espace disque
df -h

# Services en erreur
systemctl --failed

# Logs d'un service specifique
journalctl -u <service> --since "1 hour ago"

# Logs systeme recents
journalctl --since "30 min ago" --priority err
```

### Commandes monitoring

```bash
# Verifier que Node Exporter repond
curl -s http://<host>:9100/metrics | head -5

# Verifier que VictoriaMetrics repond
curl -s http://myosotis:8428/health

# Verifier que Loki repond
curl -s http://myosotis:3100/ready

# Verifier que Grafana repond
curl -s http://myosotis:3000/api/health

# Redemarrer VictoriaMetrics (apres changement scrape config)
ssh myosotis 'sudo systemctl restart victoriametrics'

# Redemarrer Grafana
ssh myosotis 'sudo systemctl restart grafana'
```

### Deploiement

```bash
# Deployer un host NixOS specifique (depuis magnolia)
ssh <host> 'sudo bash -c "cd /etc/nixos && git fetch origin && git reset --hard origin/main && nixos-rebuild switch --flake .#<host>"'

# Deployer tous les hosts NixOS
cd /etc/nixos && ./scripts/deploy-all.sh

# Deployer Node Exporter sur les Proxmox
nix run .#deploy-proxmox
```

---

## Alerte 1 : Disk usage > 80%

| | |
|---|---|
| **Severite** | critical (email + slack) |
| **Seuil** | > 80% pendant 5 minutes |
| **PromQL** | `100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100` |

### Symptomes

- Alerte : "Disque > 80% sur {host}"
- Les services peuvent ralentir ou planter si le disque se remplit completement
- PostgreSQL peut refuser d'ecrire (PANIC) si 0% libre

### Diagnostic

```bash
# 1. Se connecter au host concerne
ssh <host>

# 2. Voir l'espace disque global
df -h

# 3. Trouver les plus gros repertoires
sudo du -sh /* 2>/dev/null | sort -rh | head -10

# 4. Chercher dans les suspects habituels
sudo du -sh /nix/store      # Paquets Nix (souvent le plus gros)
sudo du -sh /var/log         # Logs systeme
sudo du -sh /var/lib         # Donnees applicatives
sudo du -sh /tmp             # Fichiers temporaires
```

### Causes frequentes et resolution

#### Nix store trop volumineux

```bash
# Voir la taille du store
du -sh /nix/store

# Lancer le garbage collector (supprime les anciennes generations)
sudo nix-collect-garbage -d

# Verifier l'espace recupere
df -h
```

**Prevention** : ajouter un GC automatique dans la config NixOS :
```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

#### Logs trop volumineux

```bash
# Voir la taille des journaux systemd
journalctl --disk-usage

# Nettoyer les vieux journaux (garder 7 jours)
sudo journalctl --vacuum-time=7d

# Verifier les logs applicatifs
sudo du -sh /var/log/caddy/     # hawthorn
sudo du -sh /var/log/journal/   # tous les hosts
```

**Prevention** : les journaux systemd ont une limite configurable :
```nix
services.journald.extraConfig = "SystemMaxUse=500M";
```

#### Donnees applicatives

| Host | Repertoire a verifier | Quoi |
|---|---|---|
| myosotis | `/var/lib/victoriametrics` | Metriques 12 mois |
| myosotis | `/var/lib/loki` | Logs 30 jours |
| myosotis | `/var/lib/grafana` | Base Grafana |
| dandelion | `/var/lib/gitea` | Repos Git + base |
| whitelily | `/var/lib/n8n` | Workflows + base |

#### Fichiers temporaires

```bash
# Nettoyer /tmp
sudo rm -rf /tmp/*

# Nettoyer les caches
sudo rm -rf /var/cache/*
```

### Si le disque est a 100%

**URGENCE** : les services peuvent crasher (surtout PostgreSQL).

```bash
# 1. Liberer immediatement de l'espace
sudo journalctl --vacuum-size=100M
sudo nix-collect-garbage

# 2. Si PostgreSQL a crash
sudo systemctl restart postgresql
sudo systemctl restart gitea      # dandelion
sudo systemctl restart n8n        # whitelily

# 3. Verifier que les services sont repartis
systemctl --failed
```

---

## Alerte 2 : RAM usage > 90%

| | |
|---|---|
| **Severite** | warning (slack) |
| **Seuil** | > 90% pendant 5 minutes |
| **PromQL** | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |

### Symptomes

- Alerte : "RAM > 90% sur {host}"
- Le systeme peut devenir lent (swap)
- OOM killer peut tuer des processus si 100%

### Diagnostic

```bash
# 1. Se connecter au host
ssh <host>

# 2. Voir la memoire globale
free -h

# 3. Top processus par memoire
ps aux --sort=-%mem | head -10

# 4. Monitoring en temps reel
htop   # Trier par MEM% avec Shift+M
```

### Causes frequentes et resolution

#### Processus qui fuit (memory leak)

```bash
# Identifier le processus gourmand
ps aux --sort=-%mem | head -5

# Si c'est un service NixOS, le redemarrer
sudo systemctl restart <service>
```

#### Pas assez de RAM pour la VM

Les VMs ont 2 Go de RAM par defaut. Certains services sont gourmands :

| Host | Service | RAM typique |
|---|---|---|
| myosotis | VictoriaMetrics + Loki + Grafana | ~800 Mo |
| dandelion | Gitea + PostgreSQL + Runner | ~600 Mo |
| whitelily | n8n + PostgreSQL | ~400 Mo |
| magnolia | Nix builds | Variable (peut exploser pendant un build) |

**Resolution** : augmenter la RAM de la VM dans Proxmox :
1. Arreter la VM dans Proxmox
2. Hardware > Memory > augmenter (4 Go recommande pour myosotis)
3. Redemarrer la VM

#### Cache filesystem (normal)

Linux utilise la RAM libre comme cache disque. C'est **normal et souhaitable**.
La metrique `MemAvailable` tient deja compte du cache recuperable.
Si l'alerte fire, c'est que la RAM **reellement utilisee** depasse 90%.

#### Magnolia pendant un build

Les builds Nix peuvent consommer beaucoup de RAM temporairement.
Si l'alerte fire sur magnolia pendant un `nixos-rebuild`, c'est normal.
Elle se resoudra d'elle-meme une fois le build termine.

**Prevention** : le swapfile de 8 Go sur magnolia aide a absorber les pics.

---

## Alerte 3 : CPU usage > 90%

| | |
|---|---|
| **Severite** | warning (slack) |
| **Seuil** | > 90% pendant 5 minutes |
| **PromQL** | `100 - (avg by(host) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` |

### Symptomes

- Alerte : "CPU > 90% sur {host}"
- Le host repond lentement
- Les services mettent plus de temps a repondre

### Diagnostic

```bash
# 1. Se connecter au host
ssh <host>

# 2. Voir les processus les plus gourmands
htop   # Trier par CPU% avec Shift+P

# 3. Load average
uptime
# Valeurs normales : < nombre de vCPU (2 pour la plupart des VMs)

# 4. Processus en cours
ps aux --sort=-%cpu | head -10
```

### Causes frequentes et resolution

#### Build Nix en cours (magnolia)

```bash
# Verifier si un build tourne
ps aux | grep nix-build

# Si c'est un build attendu, attendre qu'il finisse
# L'alerte se resoudra d'elle-meme
```

C'est la cause la plus frequente sur magnolia. **Pas d'action necessaire**.

#### Gitea Actions runner (dandelion)

```bash
# Verifier si un workflow CI tourne
sudo podman ps

# Si un container consomme trop
sudo podman stats
```

Les CI/CD jobs sont temporaires. Attendre la fin du job.

#### Boucle applicative / bug

```bash
# Identifier le processus
ps aux --sort=-%cpu | head -3

# Si c'est un service NixOS
sudo systemctl restart <service>

# Verifier les logs pour comprendre la cause
journalctl -u <service> --since "10 min ago"
```

#### Proxmox (muscari / crocus)

```bash
# Se connecter en root
ssh root@muscari

# Verifier les VMs actives
qm list

# Verifier la charge globale
htop

# Une VM peut consommer beaucoup si elle fait un build
# Verifier quelle VM consomme : Proxmox UI > Node > Summary
```

---

## Alerte 4 : Host unreachable

| | |
|---|---|
| **Severite** | critical (email + slack) |
| **Seuil** | aucune metrique recue pendant 2 minutes |
| **PromQL** | `up{job="node"} < 1` |
| **noDataState** | Alerting (pas de donnee = alerte) |

### Symptomes

- Alerte : "Host {host} injoignable"
- Le host ne repond plus aux scrapes de VictoriaMetrics
- Potentiellement inaccessible en SSH aussi

### Diagnostic

```bash
# 1. Tester le ping (depuis magnolia ou Mac)
ping <host>

# 2. Tester SSH
ssh <host>

# 3. Si le ping echoue, tester via Tailscale
tailscale ping <host>

# 4. Verifier le statut dans la console Tailscale
# https://login.tailscale.com/admin/machines
# Le host apparait-il comme "Connected" ?

# 5. Si c'est une VM, verifier dans Proxmox
ssh root@muscari   # ou root@crocus
qm list            # La VM est-elle running ?
```

### Causes frequentes et resolution

#### VM arretee / crashee

```bash
# 1. Se connecter au node Proxmox hebergeant la VM
ssh root@muscari   # magnolia, mimosa, dandelion, hawthorn
ssh root@crocus    # whitelily, rhizanthella, myosotis

# 2. Lister les VMs et leur statut
qm list

# 3. Demarrer la VM si elle est arretee
qm start <VMID>

# 4. Si la VM est bloquee, forcer l'arret puis redemarrer
qm stop <VMID>
qm start <VMID>
```

**VMIDs** (a adapter selon ta config Proxmox) :
Verifier avec `qm list` sur chaque node.

#### Tailscale deconnecte

```bash
# 1. Si SSH fonctionne via IP LAN mais pas via hostname Tailscale
# Le probleme est Tailscale, pas la VM

# 2. Sur le host concerne
sudo systemctl status tailscaled
sudo systemctl restart tailscaled

# 3. Verifier la connexion
tailscale status
```

#### Node Exporter arrete

```bash
# Le host repond en SSH mais VictoriaMetrics ne recoit pas de metriques

# 1. Verifier le service
ssh <host> 'systemctl status prometheus-node-exporter'

# 2. Tester l'endpoint
curl http://<host>:9100/metrics

# 3. Redemarrer si necessaire
ssh <host> 'sudo systemctl restart prometheus-node-exporter'

# Pour les nodes Proxmox, le service s'appelle node-exporter
ssh root@muscari 'systemctl status node-exporter'
ssh root@muscari 'systemctl restart node-exporter'
```

#### Node Proxmox injoignable

**CRITIQUE** : si muscari ou crocus est down, toutes les VMs hebergees sont aussi down.

```
muscari heberge : magnolia, mimosa, dandelion, hawthorn
crocus heberge  : whitelily, rhizanthella, myosotis
```

```bash
# 1. Tester depuis le Mac
ping muscari
ssh root@muscari

# 2. Si pas de reponse : probleme reseau ou machine physique
# - Verifier le reseau physique (cable, switch)
# - Verifier l'alimentation du serveur
# - Acceder a la console IPMI/iDRAC si disponible
# - En dernier recours : redemarrer physiquement le serveur
```

#### rhizanthella (cas particulier)

rhizanthella est souvent offline volontairement.
L'alerte "Host unreachable" pour rhizanthella est **attendue** tant que la VM n'est pas demarree.

**Pour silencer** : Grafana > Alerting > Silences > New silence
- Matcher : `host = rhizanthella`
- Duree : choisir selon les besoins

---

## Alerte 5 : Host reboot detected

| | |
|---|---|
| **Severite** | info (slack) |
| **Seuil** | uptime < 5 minutes |
| **PromQL** | `node_time_seconds - node_boot_time_seconds < 300` |
| **for** | 0s (notification immediate) |

### Symptomes

- Alerte : "Reboot detecte sur {host}"
- Le host vient de redemarrer
- L'alerte se resout automatiquement apres 5 minutes

### Diagnostic

```bash
# 1. Verifier depuis quand le host est up
ssh <host> 'uptime'

# 2. Verifier pourquoi il a reboot
# Derniers messages avant le reboot
journalctl --boot=-1 --since "$(journalctl --boot=-1 -o short-iso | tail -1 | cut -d' ' -f1)" | tail -30

# Plus simple : derniers logs du boot precedent
journalctl -b -1 -n 50

# 3. Verifier si c'etait un reboot planifie (nixos-rebuild, update)
journalctl -b -1 | grep -i "reboot\|shutdown\|switch"
```

### Causes frequentes

#### Reboot attendu (deploiement)

Apres un `nixos-rebuild switch` avec changement de kernel, NixOS peut demander un reboot.
**Pas d'action necessaire.**

#### Reboot automatique Proxmox

Proxmox peut redemarrer les VMs apres une mise a jour du node.
Verifier dans les logs Proxmox :
```bash
ssh root@muscari 'journalctl --since "1 hour ago" | grep -i "vm\|qemu\|reboot"'
```

#### OOM kill suivi d'un reboot

```bash
# Verifier si l'OOM killer s'est active avant le reboot
journalctl -b -1 | grep -i "oom\|out of memory\|killed process"

# Si oui, augmenter la RAM de la VM (voir Alerte 2)
```

#### Reboot inattendu / crash

Si le reboot n'est pas explique par les causes ci-dessus :

```bash
# 1. Verifier les logs kernel du boot precedent
journalctl -b -1 -k | tail -50

# 2. Verifier s'il y a des erreurs hardware
dmesg | grep -i "error\|fail\|hardware"

# 3. Pour les Proxmox : verifier les logs SMART des disques
ssh root@muscari 'smartctl -a /dev/sda | grep -A5 "SMART overall"'
```

**Si les reboots inattendus se repetent** : probleme hardware probable (RAM, disque, alimentation).
Investiguer avec les logs et envisager un remplacement.

---

## Operations courantes

### Silencer une alerte temporairement

1. Grafana > Alerting > Silences
2. Click "New silence"
3. Ajouter un matcher (ex: `host = rhizanthella` ou `alertname = Host unreachable`)
4. Choisir la duree
5. Ajouter un commentaire expliquant pourquoi
6. "Submit"

### Voir l'historique des alertes

1. Grafana > Alerting > Alert rules
2. Cliquer sur une regle
3. L'onglet "History" montre les transitions (Normal → Firing → Resolved)

### Ajouter un nouveau host au monitoring

1. **NixOS** : ajouter les imports dans `hosts/<host>/configuration.nix` :
   ```nix
   ../../modules/monitoring/node-exporter.nix
   ../../modules/monitoring/promtail.nix
   ```
2. Ajouter le hostname dans `config.nix` > `tailscale.monitoredHosts`
3. Deployer le host + myosotis
4. `ssh myosotis 'sudo systemctl restart victoriametrics'`

5. **Proxmox** : ajouter dans `config.nix` > `infrastructure` avec `os = "debian"`
6. `nix run .#deploy-proxmox`
7. Ajouter dans `monitoredHosts` + redeployer myosotis

### Ajouter une nouvelle regle d'alerte

Editer `hosts/myosotis/configuration.nix`, section `provision.alerting.rules.settings`.
Chaque regle suit le pattern :
1. **Query (A)** : requete PromQL vers VictoriaMetrics
2. **Reduce (B)** : prend la derniere valeur
3. **Threshold (C)** : compare au seuil

Labels de severite :
- `critical` → email + slack
- `warning` → slack
- `info` → slack

### Explorer les metriques manuellement

1. Grafana > Explore
2. Choisir la datasource (VictoriaMetrics ou Loki)
3. Passer en mode "Code"
4. Exemples de requetes utiles :

```promql
# CPU par host
100 - (avg by(host) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# RAM par host
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Espace disque par host
100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Requetes HTTP Caddy par seconde
rate(caddy_http_requests_total[5m])

# Sante des backends Caddy
caddy_reverse_proxy_upstreams_healthy

# Taille des bases PostgreSQL
pg_database_size_bytes

# Nombre de connexions PostgreSQL
pg_stat_database_numbackends
```

### Explorer les logs manuellement

1. Grafana > Explore > Loki
2. Exemples de requetes LogQL :

```logql
# Logs d'un host specifique
{host="dandelion"}

# Logs d'un service specifique
{host="dandelion", unit="gitea.service"}

# Erreurs uniquement
{host="dandelion"} |= "error"

# Logs SSH (connexions)
{unit="sshd.service"}

# Logs de deploiement
{unit="nixos-rebuild.service"}
```

---

## Contacts et escalade

| Niveau | Action | Delai |
|---|---|---|
| Info (slack) | Lire, pas d'action immediate | Quand disponible |
| Warning (slack) | Investiguer dans les heures qui suivent | < 4h |
| Critical (email + slack) | Investiguer rapidement | < 1h |
| Node Proxmox down | Intervention physique possible | ASAP |

---

## Checklist post-incident

Apres avoir resolu un incident :

- [ ] L'alerte est passee en "Resolved" dans Grafana
- [ ] La cause racine est identifiee
- [ ] Une action preventive est mise en place si necessaire (ex: GC automatique, plus de RAM)
- [ ] Ce runbook est mis a jour si la procedure etait manquante ou incorrecte

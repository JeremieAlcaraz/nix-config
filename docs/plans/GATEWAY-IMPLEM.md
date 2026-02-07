# Plan de tâches — Migration Gateway Hawthorn

Objectif: Déplacer Caddy + Cloudflare Tunnel de mimosa vers hawthorn pour centraliser le point d'entrée web, en commençant par la route `/` uniquement.

Contraintes:
- Incrémental (V1 simple puis V2 complète)
- Testable à chaque étape (build, curl, switch)
- Sans branches (trunk-based, feature flags si besoin)
- Rollback immédiat possible (réactivation mimosa cloudflared)
- Zero downtime (bascule < 5sec)

## Suivi

- **Phase active:** `P1` (retour pour finaliser T06)
- **Dernière tâche terminée:** `T10` (P2 complète - secrets configurés)
- **Prochaine tâche:** `T06` (débloquer le build, puis T07)
- **Mode d'intégration:** `trunk-based + secrets sops`
- **Dernier commit:** En attente (P1+P2 à committer ensemble)
- **Date maj:** 2026-02-07

---

## P0 — Documentation et préparation

> But: Poser le cadre de travail et sécuriser le rollback avant tout changement infra

- [ ] **T01** Créer la documentation du plan
  **depends_on:** `-`
  **test:** `cat docs/plans/GATEWAY-IMPLEM.md` affiche ce fichier complet
  **commit:** `docs(gateway): add GATEWAY-IMPLEM.md migration plan`
  **gain:** Cadre de travail partagé, checklist de progression visible

- [ ] **T02** Documenter l'état actuel de mimosa (baseline)
  **depends_on:** `T01`
  **test:** `grep -A 10 "# État initial mimosa" docs/plans/GATEWAY-IMPLEM.md` liste services actifs, ports, domaine
  **commit:** `docs(gateway): document mimosa baseline config`
  **gain:** Point de référence pour comparer avant/après et debug

---

## P1 — Squelette host Hawthorn (sans trafic public)

> But: Créer la structure NixOS pour hawthorn et valider que le flake peut builder

- [ ] **T03** Créer l'arborescence `hosts/hawthorn/`
  **depends_on:** `T02`
  **test:** `ls -la hosts/hawthorn/` affiche `configuration.nix`, `gateway.nix`, `README.md`, `hardware-configuration.nix.example`
  **commit:** `feat(hawthorn): add host skeleton structure`
  **gain:** Dossier dédié isolé des autres hosts

- [ ] **T04** Écrire `hosts/hawthorn/configuration.nix` minimal (common modules + Tailscale)
  **depends_on:** `T03`
  **test:** `grep "imports.*common.nix" hosts/hawthorn/configuration.nix` trouve le module
  **commit:** `feat(hawthorn): add base configuration with common modules`
  **gain:** Host fonctionnel avec SSH, users, Tailscale comme les autres

- [ ] **T05** Ajouter `hawthorn` dans `flake.nix` sous `nixosConfigurations`
  **depends_on:** `T04`
  **test:** `nix flake show | grep hawthorn` affiche la config
  **commit:** `feat(hawthorn): register host in flake.nix`
  **gain:** Le flake reconnaît hawthorn comme target de build

- [ ] **T06** Valider le build complet de hawthorn
  **depends_on:** `T10` ⚠️ **BLOQUÉ** : nécessite secrets/hawthorn.yaml (P2 doit être faite avant)
  **test:** `nix build .#nixosConfigurations.hawthorn.config.system.build.toplevel` réussit (exit 0)
  **commit:** `-` (pas de changement, juste validation)
  **gain:** Garantie que la config NixOS est syntaxiquement valide
  **note:** En pratique, faire P2 (secrets) avant de valider ce test

- [ ] **T07** Ajouter `hawthorn` dans `install-hosts.tsv`
  **depends_on:** `T06`
  **test:** `grep hawthorn docs/install-hosts.tsv` trouve une ligne
  **commit:** `docs(hawthorn): add to install-hosts inventory`
  **gain:** Traçabilité de l'infra, documentation d'onboarding

---

## P2 — Secrets et onboarding host

> But: Réutiliser les secrets de mimosa pour hawthorn (même utilisateur, même tunnel)

- [ ] **T08** Ajouter la règle `hawthorn.yaml` dans `.sops.yaml`
  **depends_on:** `T07`
  **test:** `grep "path_regex.*hawthorn.yaml" .sops.yaml` trouve la règle avec age key
  **commit:** `feat(secrets): add hawthorn sops rule`
  **gain:** Activation du chiffrement sops pour hawthorn

- [ ] **T09** Copier `secrets/mimosa.yaml` vers `secrets/hawthorn.yaml`
  **depends_on:** `T08`
  **test:** `ls -la secrets/hawthorn.yaml` affiche le fichier, `diff secrets/mimosa.yaml secrets/hawthorn.yaml` retourne 0
  **commit:** `feat(secrets): copy mimosa secrets to hawthorn`
  **gain:** Réutilisation des secrets existants (même user, même tunnel Cloudflare)

- [ ] **T10** Valider que `hawthorn.yaml` peut être déchiffré avec sops
  **depends_on:** `T09`
  **test:** `sops -d secrets/hawthorn.yaml | yq '.cloudflare-tunnel-token'` affiche le token (non vide)
  **commit:** `-` (validation uniquement)
  **gain:** Assurance que le fichier est correctement chiffré et déchiffrable

---

## P3 — Caddy Hawthorn V1 (route / uniquement, reverse vers mimosa:80)

> But: Configurer Caddy sur hawthorn pour router / vers mimosa (Caddy actuel), sans activer le tunnel

- [ ] **T11** Créer `hosts/hawthorn/gateway.nix` avec config Caddy basique
  **depends_on:** `T11`
  **test:** `grep "services.caddy.enable = true" hosts/hawthorn/gateway.nix` trouve la déclaration
  **commit:** `feat(hawthorn): add gateway.nix with Caddy config skeleton`
  **gain:** Fichier dédié pour la logique gateway (séparation SoC)

- [ ] **T12** Configurer Caddy vhost `jeremiealcaraz.com` avec reverse_proxy vers `mimosa:80`
  **depends_on:** `T11`
  **test:** `grep "reverse_proxy mimosa:80" hosts/hawthorn/gateway.nix` trouve la directive
  **commit:** `feat(hawthorn): configure Caddy reverse proxy to mimosa:80`
  **gain:** Logique de routage V1 définie (comportement identique à l'actuel)

- [ ] **T13** Ajouter headers `X-Forwarded-*` dans la config Caddy
  **depends_on:** `T12`
  **test:** `grep "header_up X-Forwarded" hosts/hawthorn/gateway.nix` trouve au moins 3 headers
  **commit:** `feat(hawthorn): add X-Forwarded headers to Caddy proxy`
  **gain:** Préservation de l'IP client et protocole pour mimosa

- [ ] **T14** Activer logs JSON Caddy dans `/var/log/caddy/access.log`
  **depends_on:** `T13`
  **test:** `grep 'format json' hosts/hawthorn/gateway.nix` trouve la directive log
  **commit:** `feat(hawthorn): enable JSON access logs for Caddy`
  **gain:** Logs structurés prêts pour ingestion future (Myosotis/Loki)

- [ ] **T15** Importer `gateway.nix` dans `hosts/hawthorn/configuration.nix`
  **depends_on:** `T14`
  **test:** `grep "imports.*gateway.nix" hosts/hawthorn/configuration.nix` trouve l'import
  **commit:** `feat(hawthorn): import gateway module in main config`
  **gain:** Activation effective de Caddy lors du build

- [ ] **T16** Rebuild et valider la config complète
  **depends_on:** `T15`
  **test:** `nix build .#nixosConfigurations.hawthorn.config.system.build.toplevel` réussit
  **commit:** `-` (validation uniquement)
  **gain:** Assurance que la config Caddy + gateway est syntaxiquement correcte

---

## P4 — Déploiement hawthorn et tests réseau interne

> But: Installer hawthorn sur Proxmox et valider la connectivité Tailscale + Caddy en interne

- [ ] **T17** Créer la VM hawthorn sur Proxmox (1 vCPU, 1GB RAM, 10GB disk)
  **depends_on:** `T16`
  **test:** `ssh hawthorn "uname -n"` retourne `hawthorn`
  **commit:** `-` (action infra, pas de code)
  **gain:** VM physique disponible pour installation NixOS

- [ ] **T18** Installer NixOS sur hawthorn avec `hardware-configuration.nix` généré
  **depends_on:** `T17`
  **test:** `ssh hawthorn "nixos-version"` affiche la version installée
  **commit:** `-` (hardware-configuration copié localement pour référence)
  **gain:** OS de base fonctionnel sur hawthorn

- [ ] **T19** Déployer la config flake sur hawthorn (`nixos-rebuild switch --flake`)
  **depends_on:** `T18`
  **test:** `ssh hawthorn "systemctl status tailscale"` affiche `active (running)`
  **commit:** `-` (déploiement, pas de changement code)
  **gain:** Tailscale + modules common actifs sur hawthorn

- [ ] **T20** Vérifier la connectivité Tailscale hawthorn -> mimosa
  **depends_on:** `T19`
  **test:** `ssh hawthorn "ping -c 3 mimosa"` réussit (0% packet loss)
  **commit:** `-` (test réseau)
  **gain:** Confirmation que le réseau privé Tailscale fonctionne

- [ ] **T21** Tester Caddy hawthorn vers mimosa:80 en local (sans tunnel)
  **depends_on:** `T20`
  **test:** `ssh hawthorn 'curl -H "Host: jeremiealcaraz.com" -I http://127.0.0.1/'` retourne 200/302 attendu
  **commit:** `-` (test fonctionnel)
  **gain:** Validation que Caddy hawthorn proxy correctement vers mimosa

- [ ] **T22** Vérifier les logs Caddy hawthorn pour détecter erreurs
  **depends_on:** `T21`
  **test:** `ssh hawthorn "journalctl -u caddy -n 50 --no-pager"` ne montre pas d'erreur critique
  **commit:** `-` (diagnostic)
  **gain:** Assurance que Caddy fonctionne sans erreur interne

---

## P5 — Tunnel Cloudflare sur Hawthorn (préproduction)

> But: Activer cloudflared sur hawthorn avec un hostname de test avant la bascule prod

- [ ] **T23** Ajouter config `services.cloudflared` dans `gateway.nix`
  **depends_on:** `T22`
  **test:** `grep "services.cloudflared.enable" hosts/hawthorn/gateway.nix` trouve `true`
  **commit:** `feat(hawthorn): add cloudflared tunnel configuration`
  **gain:** Service tunnel défini dans la config NixOS

- [ ] **T24** Configurer l'ingress tunnel vers `http://127.0.0.1:80` (Caddy local)
  **depends_on:** `T23`
  **test:** `grep 'service.*http://127.0.0.1' hosts/hawthorn/gateway.nix` trouve la directive
  **commit:** `feat(hawthorn): configure tunnel ingress to local Caddy`
  **gain:** Cloudflare Tunnel pointera vers Caddy hawthorn

- [ ] **T25** Lire le token tunnel depuis sops secrets
  **depends_on:** `T24`
  **test:** `grep 'sops.secrets.*cloudflare-tunnel-token' hosts/hawthorn/gateway.nix` trouve la référence
  **commit:** `feat(hawthorn): load cloudflare token from sops secrets`
  **gain:** Token sécurisé, jamais en clair dans le code

- [ ] **T26** Rebuild et déployer la config avec cloudflared sur hawthorn
  **depends_on:** `T25`
  **test:** `ssh hawthorn "systemctl status cloudflared"` affiche `active (running)`
  **commit:** `-` (déploiement)
  **gain:** Service cloudflared actif sur hawthorn

- [ ] **T27** Créer un hostname de test dans Cloudflare (`hawthorn-preview.jeremiealcaraz.com`)
  **depends_on:** `T26`
  **test:** `dig +short hawthorn-preview.jeremiealcaraz.com` retourne une IP Cloudflare
  **commit:** `-` (action Cloudflare dashboard/API)
  **gain:** Point d'entrée de validation avant switch prod

- [ ] **T28** Tester l'accès externe via le hostname de préproduction
  **depends_on:** `T27`
  **test:** `curl -I https://hawthorn-preview.jeremiealcaraz.com/` retourne 200/302 (même comportement que prod actuel)
  **commit:** `-` (test fonctionnel)
  **gain:** Validation end-to-end du flux Cloudflare -> hawthorn -> mimosa

---

## P6 — Bascule production contrôlée

> But: Déplacer le domaine principal vers hawthorn avec rollback immédiat possible

- [ ] **T29** Documenter la procédure de rollback avant la bascule
  **depends_on:** `T28`
  **test:** `grep -A 5 "# Procédure rollback" docs/plans/GATEWAY-IMPLEM.md` liste les commandes exactes
  **commit:** `docs(gateway): add rollback procedure for production switch`
  **gain:** Sécurité cognitive, réduction stress lors du switch

- [ ] **T30** Basculer l'ingress Cloudflare principal vers hawthorn
  **depends_on:** `T29`
  **test:** `curl -I https://jeremiealcaraz.com/` retourne 200/302 et les headers montrent passage par hawthorn
  **commit:** `-` (action Cloudflare, pas de code)
  **gain:** Trafic production passe par hawthorn

- [ ] **T31** Désactiver `services.cloudflared` sur mimosa
  **depends_on:** `T30`
  **test:** `ssh mimosa "systemctl status cloudflared"` affiche `inactive (dead)`
  **commit:** `feat(mimosa): disable cloudflared tunnel service`
  **gain:** Un seul tunnel actif, pas de conflit

- [ ] **T32** Tester le site en production depuis plusieurs points (navigateur, curl, mobile)
  **depends_on:** `T31`
  **test:** Checklist manuelle: accueil, route /about, /blog, assets /_astro/* chargent correctement
  **commit:** `-` (validation fonctionnelle)
  **gain:** Confirmation que le comportement utilisateur est intact

- [ ] **T33** Vérifier les logs hawthorn et mimosa pour erreurs post-bascule
  **depends_on:** `T32`
  **test:** `ssh hawthorn "journalctl -u caddy -u cloudflared --since '10 minutes ago' | grep -i error"` vide ou erreurs connues uniquement
  **commit:** `-` (diagnostic)
  **gain:** Détection rapide de problèmes cachés

---

## P7 — Stabilisation V1 et préparation V2

> But: Observer la V1 en production et planifier la V2 (Caddy uniquement sur hawthorn)

- [ ] **T34** Observer les métriques pendant 24h (disponibilité, latence, erreurs 5xx)
  **depends_on:** `T33`
  **test:** Notes dans GATEWAY-IMPLEM.md section "Observations V1" avec timestamp, uptime, incidents éventuels
  **commit:** `docs(gateway): add V1 stability observations`
  **gain:** Données réelles pour décider si V2 ou fix V1 d'abord

- [ ] **T35** Tester un rollback volontaire (basculer vers mimosa puis re-basculer vers hawthorn)
  **depends_on:** `T34`
  **test:** Downtime mesuré < 10 secondes lors des 2 bascules
  **commit:** `-` (test résilience)
  **gain:** Validation que le rollback fonctionne vraiment en condition réelle

- [ ] **T36** Documenter les incidents fréquents rencontrés (si any)
  **depends_on:** `T35`
  **test:** Section "FAQ incidents V1" dans GATEWAY-IMPLEM.md liste au moins 3 scénarios + résolution
  **commit:** `docs(gateway): add V1 incident FAQ and troubleshooting`
  **gain:** Playbook pour les futurs problèmes similaires

- [ ] **T37** Critère de sortie V1 validé (zéro interruption prolongée, rollback OK)
  **depends_on:** `T36`
  **test:** Checklist cochée dans GATEWAY-IMPLEM.md "V1 stable ✅"
  **commit:** `docs(gateway): mark V1 as stable and production-ready`
  **gain:** Feu vert pour passer en V2 sans régression

---

## P8 — V2 : Centralisation finale (Caddy uniquement sur Hawthorn)

> But: Retirer Caddy de mimosa et router directement vers l'app (port 4321)

- [ ] **T38** Modifier `gateway.nix` : reverse_proxy de `mimosa:80` vers `mimosa:4321`
  **depends_on:** `T37`
  **test:** `grep "reverse_proxy mimosa:4321" hosts/hawthorn/gateway.nix` trouve la directive
  **commit:** `feat(hawthorn): change reverse proxy to mimosa app port 4321`
  **gain:** Hawthorn parle directement à l'app, pas au Caddy intermédiaire

- [ ] **T39** Répliquer les headers de sécurité nécessaires dans Caddy hawthorn
  **depends_on:** `T38`
  **test:** `grep -E "(X-Frame-Options|Strict-Transport)" hosts/hawthorn/gateway.nix` trouve les headers
  **commit:** `feat(hawthorn): add security headers previously managed by mimosa Caddy`
  **gain:** Maintien de la posture sécurité identique à avant

- [ ] **T40** Déployer la nouvelle config hawthorn (test en preprod d'abord si hostname dispo)
  **depends_on:** `T39`
  **test:** `curl -I https://hawthorn-preview.jeremiealcaraz.com/` retourne toujours 200/302 avec nouveaux headers
  **commit:** `-` (déploiement)
  **gain:** Validation sans risque avant prod

- [ ] **T41** Basculer en production (ingress prod vers hawthorn V2)
  **depends_on:** `T40`
  **test:** `curl -I https://jeremiealcaraz.com/` retourne 200/302 et headers de sécurité présents
  **commit:** `-` (action Cloudflare)
  **gain:** V2 active en production

- [ ] **T42** Désactiver `services.caddy` sur mimosa
  **depends_on:** `T41`
  **test:** `ssh mimosa "systemctl status caddy"` affiche `inactive (dead)`
  **commit:** `feat(mimosa): disable Caddy service (gateway centralized on hawthorn)`
  **gain:** Un seul Caddy actif, simplification infra

- [ ] **T43** Restreindre le firewall mimosa à Tailscale uniquement (port 4321)
  **depends_on:** `T42`
  **test:** `ssh mimosa "iptables-save | grep 4321"` montre règle interface tailscale0 uniquement
  **commit:** `feat(mimosa): restrict firewall to tailscale interface only`
  **gain:** Mimosa non exposée directement, sécurité renforcée

- [ ] **T44** Tester le site en production V2 (checklist complète)
  **depends_on:** `T43`
  **test:** Checklist manuelle identique à T32 + vérification headers sécurité
  **commit:** `-` (validation fonctionnelle)
  **gain:** Confirmation que V2 est équivalente ou meilleure que V1

- [ ] **T45** Observer 24h et documenter la V2
  **depends_on:** `T44`
  **test:** Section "Observations V2" dans GATEWAY-IMPLEM.md avec métriques et incidents
  **commit:** `docs(gateway): add V2 stability observations and final state`
  **gain:** Documentation de l'état final de l'architecture

- [ ] **T46** Critère de sortie V2 validé (hawthorn unique point d'entrée, mimosa non exposée)
  **depends_on:** `T45`
  **test:** Checklist cochée "V2 stable ✅" + schéma architecture mis à jour
  **commit:** `docs(gateway): mark V2 as complete and update architecture diagram`
  **gain:** Migration complète, architecture gateway centralisée validée

---

## Règles (pour agents et humains)

- Une tâche = **1 action + 1 test + 1 commit** (ou `-` si test/validation uniquement)
- **Scope minimal**, pas d'effet de bord sur d'autres hosts
- **Dépendances explicites** via `depends_on`
- Toujours un **gain observable** (technique ou produit)
- Mettre à jour la section **Suivi** après chaque tâche terminée
- **Rollback** : si une tâche casse quelque chose, revenir à l'état précédent et documenter l'échec
- **Secrets** : jamais de token/password en clair, toujours via sops
- **Tests externes** : utiliser `hawthorn-preview.jeremiealcaraz.com` avant la bascule prod

---

## État initial mimosa (baseline)

**Date snapshot:** 2026-02-07

### Services actifs (systemd)

1. **`caddy.service`**
   - Rôle : Reverse proxy HTTP pour jeremiealcaraz.com
   - Écoute : port 80 (HTTP only, Cloudflare gère TLS)
   - Config : `hosts/mimosa/webserver.nix` lignes 17-79
   - Restart trigger : redémarre automatiquement quand le site change

2. **`cloudflared.service`**
   - Rôle : Tunnel Cloudflare (connexion sortante chiffrée)
   - Type : systemd custom (DynamicUser)
   - Token : chargé via `LoadCredential` depuis sops
   - Config : `hosts/mimosa/webserver.nix` lignes 118-141

3. **`j12zdotcom.service`**
   - Rôle : Application web Astro SSR (Node.js 22)
   - Port : 4321 (localhost uniquement)
   - WorkingDirectory : package buildé depuis cache magnolia
   - Config : `hosts/mimosa/webserver.nix` lignes 82-100

### Ports et endpoints

- **Port 4321** : Application Astro (127.0.0.1 only, pas exposé)
- **Port 80** : Caddy HTTP (écoute locale pour le tunnel)
- **Tunnel Cloudflare** : pas de port public direct, connexion sortante chiffrée
- **IP Tailscale dev** : `http://100.88.163.121` (bypass maintenance, accès direct)

### Domaine principal

- `jeremiealcaraz.com` (HTTP via Cloudflare Tunnel)

### Configuration Caddy actuelle (comportement référence)

**VirtualHost principal** : `http://jeremiealcaraz.com`

**Compression** : gzip + zstd

**Headers de sécurité** (lignes 42-52) :
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' ...`
- `Permissions-Policy: geolocation=(), microphone=(), camera=()`
- `Cache-Control: public, must-revalidate, max-age=0`
- `-Server` (masque le header Server)

**Logs** :
- Fichier : `/var/log/caddy/jeremiealcaraz.com.log`
- Format : JSON
- Rotation : 100MB, garde 10 fichiers, 30 jours

**Mode maintenance actif** (lignes 64-76) :
- Routes whitelistées (proxy vers app) : `/wip*`, `/_astro/*`, `/assets/*`, `/favicon*`, `/robots.txt`, `/sitemap*`, `/site.webmanifest`
- Tout le reste : redirection 302 vers `https://jeremiealcaraz.com/wip`

**Reverse proxy** :
- Destination : `127.0.0.1:4321` (service j12zdotcom)
- Trusted proxies : `127.0.0.1/32`, `::1`
- Client IP headers : `CF-Connecting-IP`, `X-Forwarded-For`

**VirtualHost dev Tailscale** : `http://100.88.163.121`
- Pas de headers, pas de maintenance, direct vers app
- Utile pour debug sans passer par Cloudflare

### Secrets (sops)

- `cloudflare-tunnel-token` : token tunnel Cloudflare (mode 0444)
- `jeremie-password-hash` : hash password utilisateur (hérité de common modules)

### Modules importés

- `sops.nix` (secrets chiffrés)
- `tailscale.nix` + `tailscale-dns.nix` (réseau privé)
- `github-actions.nix` (clés SSH pour déploiement)

### Architecture actuelle

```
Internet (HTTPS)
    ↓
Cloudflare Edge (TLS termination)
    ↓
Cloudflare Tunnel (chiffré)
    ↓
mimosa: cloudflared.service (127.0.0.1)
    ↓
mimosa: caddy.service (port 80)
    ↓ (reverse_proxy)
mimosa: j12zdotcom.service (port 4321)
```

---

## Procédure rollback

**Si problème détecté après T30 (bascule prod) :**

1. **Immédiatement** : réactiver cloudflared sur mimosa
   ```bash
   ssh mimosa "sudo systemctl start cloudflared"
   ```

2. **Cloudflare Dashboard** : basculer l'ingress principal vers l'ancien tunnel (mimosa)
   - Ou via CLI : `cloudflare tunnel route dns <tunnel-id> jeremiealcaraz.com`

3. **Vérifier** : `curl -I https://jeremiealcaraz.com/` retourne le comportement attendu

4. **Analyser** les logs hawthorn :
   ```bash
   ssh hawthorn "journalctl -u caddy -u cloudflared --since '30 minutes ago'"
   ```

5. **Documenter** l'incident dans ce fichier (section dédiée)

**Temps estimé de rollback :** < 2 minutes

---

## Observations V1

*(À remplir après T34)*

| Métrique | Valeur | Notes |
|----------|--------|-------|
| Uptime 24h | - | - |
| Erreurs 5xx | - | - |
| Latence P95 | - | - |
| Incidents | - | - |

---

## Observations V2

*(À remplir après T46)*

| Métrique | Valeur | Notes |
|----------|--------|-------|
| Uptime 24h | - | - |
| Erreurs 5xx | - | - |
| Latence P95 | - | - |
| Incidents | - | - |

---

## FAQ incidents V1

*(À remplir après T37 si incidents rencontrés)*

### Incident 1 : [Titre]
- **Symptôme :**
- **Cause :**
- **Résolution :**
- **Prévention :**

---

## Architecture finale (schéma)

```
┌──────────────┐
│ Utilisateur  │
└──────┬───────┘
       │ HTTPS
       ▼
┌──────────────────────────────────┐
│ Cloudflare Tunnel                │
└──────┬───────────────────────────┘
       │ (tunnel chiffré)
       ▼
┌──────────────────────────────────┐
│ 🌸 Hawthorn (Gateway)            │
│  ├─ Caddy (vhost jeremiealcaraz) │
│  └─ cloudflared                  │
└──────┬───────────────────────────┘
       │ Tailscale (réseau privé)
       ▼
┌──────────────────────────────────┐
│ 🌸 Mimosa (App uniquement)       │
│  └─ Astro SSR :4321              │
└──────────────────────────────────┘
```

**V1** : Hawthorn -> mimosa:80 (Caddy encore actif sur mimosa)
**V2** : Hawthorn -> mimosa:4321 (Caddy désactivé sur mimosa)

---

## Prochaines étapes (hors scope V1/V2)

- [ ] Ajouter `/api/*` routing vers dandelion (future VM backend)
- [ ] Migrer vers **Myosotis** (observabilité : Loki, Grafana)
- [ ] Ajouter page de maintenance statique sur hawthorn (fallback si mimosa down)
- [ ] Activer compression `zstd` dans Caddy hawthorn
- [ ] Rate limiting Caddy pour protection DDoS basique

# Tailscale Services automation

Automatisation de la création et publication des services Tailscale (VIP + serve) depuis `nix-config`.

## Commande principale

```bash
cd ~/c/nix-config
just ts-service-add <service> <host> <port>
```

### Exemple

```bash
just ts-service-add immich poppy 2283
```

## Ce que la commande fait automatiquement

1. Met à jour `ops/tailscale/services.json`
2. Synchronise la policy ACL (`autoApprovers.services` + `grants`) via API OAuth
3. Crée/met à jour le service VIP Tailscale `svc:<service>`
4. Configure `tailscale serve --service=...` sur l'host cible
5. Exécute `tailscale serve advertise ...` et affiche le status JSON

## Vérification

```bash
ssh <host> 'tailscale serve status --json'
```

## Commandes utiles

- Dry-run policy only:
  ```bash
  just ts-policy-sync
  ```

- Apply policy only:
  ```bash
  just ts-policy-sync --apply
  ```

- Ensure VIP service only:
  ```bash
  just ts-service-ensure <service> 443
  ```

- Configure serve on host only:
  ```bash
  just ts-serve <host> <service> <port>
  ```

## Pré-requis

Secrets SOPS dans `secrets/common.yaml`:

- `tailscale_oauth_client_id`
- `tailscale_oauth_client_secret`
- `tailscale_tailnet`

Scripts de validation OAuth disponibles:

```bash
./scripts/tailscale/test-oauth-common.py
./scripts/tailscale/test-oauth-acl-write-noop.py
```

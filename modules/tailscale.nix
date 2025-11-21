({ config, pkgs, lib, ... }:
let
  # Script qui gère l'authentification OAuth et la connexion à Tailscale
  tailscaleAuthScript = pkgs.writeShellScript "tailscale" ''
    set -euo pipefail  # Arrête le script dès la première erreur

    log() {
      printf '%s\n' "$@"
    }

    # === RÉCUPÉRATION DES SECRETS ===
    log "📦 Lecture des secrets SOPS (client_id, client_secret, tailnet)"
    CLIENT_ID=$(cat ${config.sops.secrets.tailscale_oauth_client_id.path})
    CLIENT_SECRET=$(cat ${config.sops.secrets.tailscale_oauth_client_secret.path})
    TAILNET=$(cat ${config.sops.secrets.tailscale_tailnet.path})

    # === VÉRIFICATION : Est-on déjà connecté ? ===
    log "🔍 Vérification de l'état actuel de Tailscale"
    if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running" and .Self.Online == true' > /dev/null; then
      log "✅ Déjà connecté à Tailscale"
      exit 0  # On quitte proprement, pas d'erreur
    fi

    log "ℹ️  Déconnexion détectée, tentative de reconnexion"

    # === RÉCUPÉRATION D'UN ACCESS TOKEN OAUTH ===
    log "🔑 Demande d'un access token OAuth (grant_type=client_credentials)"
    OAUTH_RESPONSE=$(${pkgs.curl}/bin/curl -sf --max-time 30 \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -X POST "https://api.tailscale.com/api/v2/oauth/token" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "grant_type=client_credentials")

    ACCESS_TOKEN=$(printf '%s' "$OAUTH_RESPONSE" | ${pkgs.jq}/bin/jq -r '.access_token // empty')

    if [ -z "$ACCESS_TOKEN" ]; then
      log "❌ Échec lors de la récupération de l'access token. Réponse brute : $OAUTH_RESPONSE" >&2
      exit 1
    fi

    log "✅ Access token obtenu"

    # === APPEL API POUR CRÉER UNE CLÉ D'AUTHENTIFICATION ===
    log "🛠️  Création d'une auth key Tailscale via l'API (avec tags obligatoires)"
    AUTH_PAYLOAD=$(cat <<'EOF'
{
  "capabilities": {
    "devices": {
      "create": {
        "reusable": true,
        "ephemeral": false,
        "tags": [
          "tag:newmachine"
        ]
      }
    }
  }
}
EOF
    )

    # Capturer à la fois le body ET le code HTTP
    AUTH_RESPONSE=$(${pkgs.curl}/bin/curl -s -w "\n%{http_code}" --max-time 30 \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -X POST "https://api.tailscale.com/api/v2/tailnet/$TAILNET/keys" \
      -d "$AUTH_PAYLOAD")

    HTTP_CODE=$(printf '%s' "$AUTH_RESPONSE" | tail -n1)
    BODY=$(printf '%s' "$AUTH_RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" != "200" ]; then
      log "❌ Erreur API (HTTP $HTTP_CODE): $BODY" >&2
      exit 22
    fi

    AUTH_KEY=$(printf '%s' "$BODY" | ${pkgs.jq}/bin/jq -r '.key // empty')

    # === VÉRIFICATION : La clé a-t-elle été générée ? ===
    if [ -z "$AUTH_KEY" ]; then
      log "❌ Erreur: impossible de générer l'auth key. Réponse brute : $BODY" >&2
      exit 1
    fi

    log "✅ Auth key générée, connexion à Tailscale..."

    # === CONNEXION À TAILSCALE ===
    # --reset : réinitialise tous les paramètres à leurs valeurs par défaut
    # --auth-key : utilise la clé qu'on vient de générer
    # --hostname : définit le nom de la machine dans le réseau Tailscale
    # --accept-dns=false : n'accepte pas le DNS Tailscale pour éviter les conflits
    ${pkgs.tailscale}/bin/tailscale up \
      --reset \
      --auth-key="$AUTH_KEY" \
      --hostname="${config.networking.hostName}" \
      --accept-dns=true

    log "🎉 Machine ${config.networking.hostName} connectée à Tailscale !"
  '';
in
{
  # === SERVICE SYSTEMD ===
  # Ce service s'exécute automatiquement au démarrage de la machine
  systemd.services.tailscale = {
    description = "Tailscale OAuth Auto-Join";

    # === DÉPENDANCES : Quand démarrer le service ? ===
    # after : attend que ces services soient démarrés avant de lancer le nôtre
    # - network-online.target : le réseau doit être complètement opérationnel
    # - tailscaled.service : le daemon Tailscale doit être actif
    # - run-secrets.d.mount : les secrets SOPS doivent être montés dans /run/secrets/
    after = [ "network-online.target" "tailscaled.service" "run-secrets.d.mount" ];

    # wants : souhaite que ces services soient démarrés (mais pas bloquant si absent)
    wants = [ "network-online.target" "run-secrets.d.mount" ];

    # requires : EXIGE que ce service soit actif (bloque si tailscaled plante)
    requires = [ "tailscaled.service" ];

    # wantedBy : ce service est démarré par la cible multi-user (boot normal)
    wantedBy = [ "multi-user.target" ];

    # === CONFIGURATION DE L'UNITÉ ===
    # RequiresMountsFor : attend que le système de fichiers /run/secrets soit monté
    # Ceci garantit que les secrets sont accessibles avant que le service démarre
    unitConfig = {
      RequiresMountsFor = [ "/run/secrets" ];
    };

    # === CONFIGURATION DU SERVICE ===
    serviceConfig = {
      # Type oneshot : le service s'exécute une fois puis se termine
      Type = "oneshot";

      # La commande à exécuter (notre script)
      ExecStart = tailscaleAuthScript;

      # RemainAfterExit : systemd considère le service comme "actif" même après qu'il se termine
      # Utile pour savoir que l'initialisation a déjà eu lieu
      RemainAfterExit = true;

      # Logs : envoie stdout et stderr vers journalctl
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # === ACTIVATION DE TAILSCALE ===
  # Active le daemon Tailscale (tailscaled.service)
  services.tailscale.enable = true;

  # === DÉCLARATION DES SECRETS SOPS ===
  # Ces secrets sont chiffrés dans secrets/common.yaml
  # sops-nix les déchiffre automatiquement au boot et les rend accessibles
  # sous /run/secrets/<nom-du-secret>
  sops.secrets = {
    tailscale_oauth_client_id.sopsFile = ../secrets/common.yaml;
    tailscale_oauth_client_secret.sopsFile = ../secrets/common.yaml;
    tailscale_tailnet.sopsFile = ../secrets/common.yaml;  # ← AJOUT
  };
})

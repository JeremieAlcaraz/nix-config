({ config, pkgs, lib, ... }:
let
  # Script qui gère l'authentification OAuth et la connexion à Tailscale
  tailscaleAuthScript = pkgs.writeShellScript "tailscale" ''
    set -euo pipefail  # Arrête le script dès la première erreur

    # === RÉCUPÉRATION DES SECRETS ===
    # Tous les secrets (credentials OAuth + tailnet) sont stockés dans sops
    CLIENT_ID=$(cat ${config.sops.secrets.tailscale_oauth_client_id.path})
    CLIENT_SECRET=$(cat ${config.sops.secrets.tailscale_oauth_client_secret.path})
    TAILNET=$(cat ${config.sops.secrets.tailscale_tailnet.path})

    # === VÉRIFICATION : Est-on déjà connecté ? ===
    # Évite de régénérer une clé si Tailscale fonctionne déjà
    # `tailscale status --json` retourne l'état de la connexion
    # `jq -e '.BackendState == "Running"'` vérifie si le statut est "Running"
    if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' > /dev/null; then
      echo "✅ Déjà connecté à Tailscale"
      exit 0  # On quitte proprement, pas d'erreur
    fi

    echo "🔑 Génération d'une auth key Tailscale via OAuth..."

    # === APPEL API POUR CRÉER UNE CLÉ D'AUTHENTIFICATION ===
    # -sf : silent + fail (pas de barre de progression, erreur si HTTP != 2xx)
    # --max-time 30 : timeout après 30 secondes (évite de bloquer indéfiniment)
    # -u "$CLIENT_ID:$CLIENT_SECRET" : authentification Basic Auth avec OAuth credentials
    # La clé générée est extraite avec jq (champ .key de la réponse JSON)
    AUTH_KEY=$(${pkgs.curl}/bin/curl -sf --max-time 30 \
      -u "$CLIENT_ID:$CLIENT_SECRET" \
      -H "Content-Type: application/json" \
      -X POST "https://api.tailscale.com/api/v2/tailnet/$TAILNET/keys" \
      -d '{
        "capabilities": {
          "devices": {
            "create": {
              "reusable": false,      # Clé à usage unique (plus sécurisé)
              "ephemeral": false,     # La machine reste dans le réseau après déconnexion
              "tags": ["tag:server", "tag:nixos"],  # Tags pour organiser tes machines
              "preauthorized": true   # Pas besoin d'approuver manuellement dans l'interface
            }
          }
        },
        "expirySeconds": 3600  # La clé expire après 1h (suffisant pour s'authentifier)
      }' | ${pkgs.jq}/bin/jq -r '.key')

    # === VÉRIFICATION : La clé a-t-elle été générée ? ===
    # Si l'API échoue, AUTH_KEY sera vide ou "null"
    if [ -z "$AUTH_KEY" ] || [ "$AUTH_KEY" = "null" ]; then
      echo "❌ Erreur: impossible de générer l'auth key" >&2  # >&2 = erreur standard
      exit 1
    fi

    echo "✅ Auth key générée, connexion à Tailscale..."

    # === CONNEXION À TAILSCALE ===
    # --auth-key : utilise la clé qu'on vient de générer
    # --hostname : définit le nom de la machine dans le réseau Tailscale
    # --ssh : active le SSH via Tailscale (pratique pour l'admin à distance)
    # --accept-routes : accepte les routes du réseau (subnet routing)
    ${pkgs.tailscale}/bin/tailscale up \
      --auth-key="$AUTH_KEY" \
      --hostname="${config.networking.hostName}" \
      --ssh \
      --accept-routes

    echo "🎉 Machine ${config.networking.hostName} connectée à Tailscale !"
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
    after = [ "network-online.target" "tailscaled.service" ];
    
    # wants : souhaite que ces services soient démarrés (mais pas bloquant si absent)
    wants = [ "network-online.target" ];
    
    # requires : EXIGE que ce service soit actif (bloque si tailscaled plante)
    requires = [ "tailscaled.service" ];
    
    # wantedBy : ce service est démarré par la cible multi-user (boot normal)
    wantedBy = [ "multi-user.target" ];

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

  # === CONFIGURATION FIREWALL ===
  networking.firewall = {
    # checkReversePath = "loose" : nécessaire pour que Tailscale fonctionne correctement
    # Sinon le noyau Linux peut rejeter les paquets venant de Tailscale
    checkReversePath = "loose";
    
    # tailscale0 : l'interface réseau virtuelle créée par Tailscale
    # En la déclarant "trusted", on autorise tout le trafic qui passe par elle
    trustedInterfaces = [ "tailscale0" ];
    
    # Ouvre le port UDP utilisé par Tailscale (par défaut 41641)
    # config.services.tailscale.port récupère automatiquement le bon port
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

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

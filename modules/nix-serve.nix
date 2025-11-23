{ config, lib, ... }:

{
  # Active le serveur de cache binaire Nix
  services.nix-serve = {
    enable = true;

    # Port d'écoute (accessible via Tailscale)
    port = 5000;

    # Clé privée pour signer les packages
    # Générée avec : nix-store --generate-binary-cache-key
    secretKeyFile = "/var/cache-keys/cache-private-key.pem";

    # Écoute sur toutes les interfaces (nécessaire pour Tailscale)
    bindAddress = "0.0.0.0";
  };

  # Ouvre le port 5000 dans le firewall (uniquement pour Tailscale)
  # Note : Tailscale gère déjà la sécurité, mais on ouvre quand même
  networking.firewall.allowedTCPPorts = [ 5000 ];
}

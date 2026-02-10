{
  # Configuration centralisée du projet
  # Ce fichier contient toutes les variables globales qui peuvent être réutilisées
  # dans les modules NixOS, les scripts, et les déploiements.

  # Configuration Git forge (Gitea vs GitHub)
  gitForge = {
    # Type actuel : "gitea" ou "github"
    # Changer cette valeur pour basculer entre Gitea et GitHub
    type = "gitea";

    gitea = {
      # HTTP URL - Pour les VMs qui font seulement du pull (read-only)
      # Utilise le hostname MagicDNS Tailscale (résolu automatiquement)
      url = "http://dandelion:3000";
      domain = "dandelion:3000";
      host = "dandelion";
      port = 3000;

      # SSH URLs - Pour Magnolia et Mac qui peuvent push
      # Format: gitea@dandelion:username/repo.git
      sshUrl = "gitea@dandelion:jeremiealcaraz/nix-config.git";
      sshHost = "gitea@dandelion";
    };

    github = {
      url = "https://github.com";
      domain = "github.com";
      host = "github.com";
      port = 443;
    };
  };

  # URLs et domaines courants du projet
  services = {
    # n8n automation server
    n8n = {
      url = "https://n8n.jeremiealcaraz.com";
    };

    # Site web principal
    website = {
      url = "https://jeremiealcaraz.com";
    };
  };

  # Inventaire complet de l'infrastructure
  # Single source of truth pour tous les hosts (NixOS + non-NixOS)
  # Exploitable par Nix pour générer configs, scripts, diagrammes
  infrastructure = {
    # --- Proxmox nodes (Debian, pas gérés par NixOS) ---
    muscari = {
      role = "Proxmox node 1 - Hyperviseur principal";
      os = "debian";
      managed = false;
      tailscaleIp = "100.67.122.20";
      vms = [ "magnolia" "mimosa" "dandelion" "hawthorn" ];
    };
    crocus = {
      role = "Proxmox node 2 - Hyperviseur secondaire";
      os = "debian";
      managed = false;
      tailscaleIp = "100.127.90.43";
      vms = [ "whitelily" "rhizanthella" "myosotis" ];
    };

    # --- VMs NixOS (gérées par flake.nix) ---
    magnolia = {
      role = "Builder / Deployer / Cache binaire (nix-serve :5000)";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.96.250.41";
      host = "muscari";
    };
    hawthorn = {
      role = "Gateway - Point d'entree web (Caddy + Cloudflare Tunnel)";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.126.173.95";
      host = "muscari";
    };
    mimosa = {
      role = "Web - Site jeremiealcaraz.com";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.96.250.45";
      host = "muscari";
    };
    dandelion = {
      role = "Gitea - Serveur Git auto-heberge";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.96.250.43";
      host = "muscari";
    };
    whitelily = {
      role = "n8n - Serveur d'automatisation";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.96.250.44";
      host = "crocus";
    };
    rhizanthella = {
      role = "bknd - Backend-as-a-Service";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.127.41.93";
      host = "crocus";
    };
    myosotis = {
      role = "Observabilite - Grafana, Loki, VictoriaMetrics";
      os = "nixos";
      managed = true;
      tailscaleIp = "100.116.189.42";
      host = "crocus";
    };
  };

  # Configuration réseau Tailscale
  tailscale = {
    network = "100.96.0.0/16";

    # IPs Tailscale (fallback, préférer les hostnames MagicDNS)
    hosts = {
      magnolia = "100.96.250.41";
      dandelion = "100.96.250.43";
      whitelily = "100.96.250.44";
      mimosa = "100.96.250.45";
      hawthorn = "100.126.173.95";
      rhizanthella = "100.127.41.93";
      myosotis = "100.116.189.42";
    };

    # Hosts monitorés par VictoriaMetrics (scrape métriques Node Exporter)
    # Ajouter un host ici = automatiquement scrapé par myosotis
    # Utilise les hostnames MagicDNS (pas les IPs) pour la résilience
    monitoredHosts = [ "magnolia" "hawthorn" "mimosa" "dandelion" "whitelily" "rhizanthella" "muscari" "crocus" ];
  };
}

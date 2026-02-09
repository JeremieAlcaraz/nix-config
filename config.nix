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

  # Configuration réseau Tailscale
  tailscale = {
    network = "100.96.0.0/16";
    hosts = {
      magnolia = "100.96.250.41";
      dandelion = "100.96.250.43";
      whitelily = "100.96.250.44";
      mimosa = "100.96.250.45";
      myosotis = "100.116.189.42";
    };
  };
}

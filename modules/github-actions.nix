# ============================================================================
# Module "github-actions.nix"
# ---------------------------------------------------------------------------
# Configure les clés SSH publiques pour permettre à GitHub Actions de se
# connecter aux serveurs via Tailscale pour les déploiements automatisés.
#
# Usage:
#   - Magnolia : Permet à GitHub Actions de builder et pousser au cache
#   - Mimosa : Permet à GitHub Actions de déployer les nouvelles configs
#
# Sécurité:
#   - Les clés privées sont stockées dans GitHub Secrets (chiffrées)
#   - Les clés publiques sont ici (pas sensibles, peuvent être versionnées)
#   - Connexion uniquement via Tailscale (réseau privé chiffré)
# ============================================================================

{ config, lib, ... }:

{
  # Clés SSH publiques pour GitHub Actions
  # Générées dans 1Password et utilisées par le workflow de déploiement
  environment.etc."ssh/authorized_keys.d/jeremie-github-actions" = {
    text = ''
      # GitHub Actions - Magnolia Deploy Key
      # Utilisée pour builder les configurations sur Magnolia
      # Générée le: 2025-11-25
      # Workflow: .github/workflows/deploy.yml (j12zdotcom)
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ5gpDmTT2rn0YEzfNc5/Em5ptIeQ6DktjfAVQvboX6F github-actions@magnolia

      # GitHub Actions - Mimosa Deploy Key
      # Utilisée pour déployer sur Mimosa
      # Générée le: 2025-11-25
      # Workflow: .github/workflows/deploy.yml (j12zdotcom)
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFtEzoTJZxux04Ex1em5erjDq1WPp9YtF7uoP9Sz+no/ github-actions@mimosa
    '';
    mode = "0644";
  };
}

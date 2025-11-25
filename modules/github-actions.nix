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
  # Clé SSH publique pour GitHub Actions
  # Générée dans 1Password et utilisée par le workflow de déploiement
  # Cette clé unique permet à GitHub Actions de se connecter à tous les serveurs
  environment.etc."ssh/authorized_keys.d/jeremie-github-actions" = {
    text = ''
      # GitHub Actions - Deploy Key
      # Utilisée pour builder sur Magnolia ET déployer sur Mimosa
      # Générée le: 2025-11-25
      # Workflow: .github/workflows/deploy.yml (j12zdotcom)
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFtEzoTJZxux04Ex1em5erjDq1WPp9YtF7uoP9Sz+no/ github-actions
    '';
    mode = "0644";
  };
}

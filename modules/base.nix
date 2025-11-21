# ============================================================================
# Module commun "base.nix"
# ---------------------------------------------------------------------------
# Ce module est chargé sur toutes les machines virtuelles définies dans ce
# dépôt. Il regroupe les paquets système de base qui doivent être présents
# partout pour l'administration et le débogage. Actuellement, il assure
# l'installation de `jq` et de `git`, ainsi que la gestion déclarative des
# permissions du dépôt nix-config.
# ============================================================================

{ pkgs, ... }:
{
  imports = [
    ./git.nix
  ];

  environment.systemPackages = [ pkgs.jq ];
}

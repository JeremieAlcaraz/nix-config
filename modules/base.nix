# ============================================================================
# Module commun "base.nix"
# ---------------------------------------------------------------------------
# Ce module est chargé sur toutes les machines virtuelles définies dans ce
# dépôt. Il regroupe les paquets système de base qui doivent être présents
# partout pour l'administration et le débogage. Actuellement, il assure
# l'installation de `jq` pour manipuler facilement du JSON depuis la ligne de
# commande.
# ============================================================================

{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.jq ];
}

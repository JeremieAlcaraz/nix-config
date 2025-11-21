# ============================================================================
# Module commun "base.nix"
# ---------------------------------------------------------------------------
# Ce module est chargé sur toutes les machines virtuelles définies dans ce
# dépôt. Il regroupe les paquets et options de base qui doivent être présents
# partout pour l'administration et le débogage.
# ============================================================================

{ pkgs, ... }:
{
  imports = [
    ./git.nix
  ];

  time.timeZone = "Europe/Paris";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs = {
    fish.enable = true;
    tmux.enable = true;
  };

  environment.systemPackages = with pkgs; [
    curl
    wget
    jq
  ];
}

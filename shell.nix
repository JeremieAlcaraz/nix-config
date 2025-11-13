# Shell development environment for nix-config management
# Usage: nix-shell
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "nix-config-dev";

  buildInputs = with pkgs; [
    # Secret management
    sops
    age

    # Password utilities
    openssl
    mkpasswd

    # Git and development tools
    git

    # Optional: helpful for debugging
    jq
  ];

  shellHook = ''
    echo "🔐 Environnement de gestion nix-config chargé"
    echo ""
    echo "Outils disponibles :"
    echo "  • sops      - Chiffrement des secrets"
    echo "  • age       - Clés de chiffrement"
    echo "  • openssl   - Génération de secrets"
    echo "  • mkpasswd  - Hash de mots de passe"
    echo ""
    echo "Scripts utiles :"
    echo "  • ./scripts/manage-secrets.sh [host]  - Gestion des secrets"
    echo "  • ./scripts/install-nixos.sh [host]   - Installation NixOS"
    echo ""
  '';
}

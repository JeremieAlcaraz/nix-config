# ============================================================================
# Module commun "sops.nix"
# ---------------------------------------------------------------------------
# Configure la gestion des secrets avec sops-nix et centralise le secret
# contenant le hash du mot de passe de l'utilisateur "jeremie".
# ============================================================================

{ defaultSopsFile }:
{ config, lib, ... }:
let
  inherit (lib) mkDefault;
in {
  # Fichier de secrets utilisé par défaut pour l'hôte (fourni via l'import).
  sops.defaultSopsFile = defaultSopsFile;

  # Chemin de la clé age par défaut (modifiable par les hôtes si nécessaire).
  sops.age.keyFile = mkDefault "/var/lib/sops-nix/key.txt";

  # Secret stockant le hash du mot de passe de l'utilisateur jeremie.
  sops.secrets.jeremie-password-hash = {
    neededForUsers = true;
  };

  # L'utilisateur jeremie est défini dans modules/ssh.nix ; ici on ne fait
  # qu'attacher le hash du mot de passe déchiffré par sops-nix.
  users.users.jeremie.hashedPasswordFile =
    mkDefault config.sops.secrets.jeremie-password-hash.path;
}

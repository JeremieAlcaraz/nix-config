{ config, lib, defaultSopsFile, ... }:

let
  inherit (lib) mkDefault mkEnableOption mkIf;
  cfg = config.jeremiePasswordHash;
in {
  options.jeremiePasswordHash = {
    enable = mkEnableOption ''Gestion du hash de mot de passe de l'utilisateur "jeremie" via sops'' // { default = true; };
  };

  config = {
    sops = {
      inherit defaultSopsFile;
      age.keyFile = mkDefault "/var/lib/sops-nix/key.txt";
    };
  } // mkIf cfg.enable {
    # Active uniquement si le hash de mot de passe est géré via sops pour cet hôte
    # (permet de conserver les configurations sans mot de passe comme hosts/demo)
    sops.secrets.jeremie-password-hash.neededForUsers = true;

    users.users.jeremie.hashedPasswordFile =
      config.sops.secrets.jeremie-password-hash.path;
  };
}

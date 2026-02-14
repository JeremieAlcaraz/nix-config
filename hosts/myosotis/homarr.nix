{ config, pkgs, ... }:

{
  # Secret Homarr (à renseigner via sops dans secrets/myosotis.yaml)
  sops.secrets."homarr/secret_encryption_key" = {
    owner = "root";
  };

  # Podman minimal pour exécuter Homarr en OCI
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  systemd.tmpfiles.rules = [
    "d /run/homarr 0700 root root -"
    "d /var/lib/homarr 0750 root root -"
  ];

  # Rend un env file à partir du secret sops
  systemd.services.homarr-envfile = {
    description = "Render Homarr env file from sops secret";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-homarr.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      umask 077

      KEY="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."homarr/secret_encryption_key".path} | ${pkgs.coreutils}/bin/tr -d '\n\"' | ${pkgs.findutils}/bin/xargs)"

      cat > /run/homarr/homarr.env <<EOF
SECRET_ENCRYPTION_KEY=$KEY
EOF
      chmod 0600 /run/homarr/homarr.env
    '';
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.homarr = {
      image = "ghcr.io/homarr-labs/homarr:latest";
      autoStart = true;
      ports = [ "127.0.0.1:7575:7575" ];
      volumes = [
        "/var/lib/homarr:/appdata"
      ];
      environmentFiles = [ "/run/homarr/homarr.env" ];
    };
  };

  # S'assure que le conteneur démarre après génération du envfile
  systemd.services."podman-homarr" = {
    after = [ "homarr-envfile.service" ];
    requires = [ "homarr-envfile.service" ];
  };

  # Exposition HTTPS Homarr sur un service Tailscale dédié (certificat Tailscale)
  systemd.services.tailscale-serve-homarr = {
    description = "Tailscale Serve for Homarr";
    after = [ "tailscaled.service" "podman-homarr.service" ];
    wants = [ "tailscaled.service" "podman-homarr.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --yes --bg --https=8443 http://127.0.0.1:7575";
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=8443 off";
    };
  };
}

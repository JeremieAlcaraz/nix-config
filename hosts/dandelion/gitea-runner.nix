{ config, pkgs, ... }:

let
  runnerDataDir = "/var/lib/gitea-runner";
  runnerRuntimeDir = "/run/gitea-runner";
  runnerName = "dandelion-runner";
  runnerLabels = "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest";
  giteaInstanceUrl = "http://100.96.250.43:3000";
in
{
  ########################################
  # Podman + Docker socket compatibility
  ########################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      dns_enabled = true;
      dns_servers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  virtualisation.containers.containersConf.settings = {
    network = {
      dns_servers = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  ########################################
  # Runtime files
  ########################################
  systemd.tmpfiles.rules = [
    "d ${runnerDataDir} 0750 root root -"
    "d ${runnerRuntimeDir} 0700 root root -"
    # Lien symbolique vers le fichier de config act_runner (force overwrite)
    # L+ permet de remplacer le fichier à chaque rebuild
    "L+ ${runnerDataDir}/config.yaml - - - - ${./act_runner_config.yaml}"
  ];

  ########################################
  # Runner env file (registration token + labels)
  ########################################
  systemd.services."gitea-runner-envfile" = {
    description = "Render Gitea Actions runner env file";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-gitea-runner.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      umask 077

      TOKEN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."gitea/runner_registration_token".path} | ${pkgs.coreutils}/bin/tr -d '\n"' | ${pkgs.findutils}/bin/xargs)

      cat > ${runnerRuntimeDir}/runner.env <<EOF
GITEA_INSTANCE_URL=${giteaInstanceUrl}
GITEA_RUNNER_REGISTRATION_TOKEN=$TOKEN
GITEA_RUNNER_NAME=${runnerName}
GITEA_RUNNER_LABELS=${runnerLabels}
EOF

      chmod 0600 ${runnerRuntimeDir}/runner.env
    '';
  };

  ########################################
  # Wait for Gitea before starting runner
  ########################################
  systemd.services."gitea-runner-wait" = {
    description = "Wait for Gitea to become reachable";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "gitea.service" "gitea-runner-envfile.service" ];
    requires = [ "gitea-runner-envfile.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail

      for i in {1..30}; do
        if ${pkgs.curl}/bin/curl -fsS ${giteaInstanceUrl}/api/v1/version >/dev/null 2>&1; then
          echo "[gitea-runner] Gitea is reachable."
          exit 0
        fi
        echo "[gitea-runner] Waiting for Gitea... ($i/30)"
        sleep 2
      done

      echo "[gitea-runner] Gitea did not become reachable in time."
      exit 1
    '';
  };

  ########################################
  # Gitea Actions runner (act_runner)
  ########################################
  virtualisation.oci-containers = {
    backend = "podman";
    containers.gitea-runner = {
      image = "docker.io/gitea/act_runner:latest";
      autoStart = true;
      # Override la commande par défaut pour passer le fichier de config
      cmd = [ "act_runner" "daemon" "--config" "/data/config.yaml" ];
      extraOptions = [
        "--network=host"
        "--volume=${runnerDataDir}:/data"
        "--volume=/var/run/docker.sock:/var/run/docker.sock"
        "--env-file=${runnerRuntimeDir}/runner.env"
        "--cpus=2"
        "--memory=4g"
      ];
    };
  };

  systemd.services."podman-gitea-runner" = {
    after = [ "gitea-runner-envfile.service" "gitea-runner-wait.service" ];
    requires = [ "gitea-runner-envfile.service" "gitea-runner-wait.service" ];
  };
}

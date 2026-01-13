{ config, pkgs, ... }:

let
  runnerDataDir = "/var/lib/gitea-runner";
  runnerRuntimeDir = "/run/gitea-runner";
  runnerName = "dandelion-runner";
  runnerLabels = "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest";
in
{
  ########################################
  # Podman + Docker socket compatibility
  ########################################
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  ########################################
  # Runtime files
  ########################################
  systemd.tmpfiles.rules = [
    "d ${runnerDataDir} 0750 root root -"
    "d ${runnerRuntimeDir} 0700 root root -"
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
GITEA_INSTANCE_URL=http://dandelion:3000
GITEA_RUNNER_REGISTRATION_TOKEN=$TOKEN
GITEA_RUNNER_NAME=${runnerName}
GITEA_RUNNER_LABELS=${runnerLabels}
EOF

      chmod 0600 ${runnerRuntimeDir}/runner.env
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
    after = [ "gitea-runner-envfile.service" ];
    requires = [ "gitea-runner-envfile.service" ];
  };
}

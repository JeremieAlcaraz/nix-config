# Plan : Création de l'host rhizanthella (bknd)

## Objectif

Créer un nouvel host NixOS "rhizanthella" basé sur dandelion, avec PostgreSQL + bknd (Backend-as-a-Service) au lieu de Gitea.

---

## Analyse comparative dandelion vs rhizanthella

### dandelion (existant)
- **Service principal**: Gitea (serveur Git auto-hébergé)
- **Base de données**: PostgreSQL 16 (database `gitea`)
- **Container**: Podman pour gitea-runner
- **Ports**: 3000 (HTTP), 22/2222 (SSH Git)
- **Backup**: Module complet avec GDrive, Notion, Slack

### rhizanthella (à créer)
- **Service principal**: bknd (Backend-as-a-Service)
- **Base de données**: PostgreSQL 16 (database `bknd`)
- **Container**: Podman pour bknd (build depuis GitHub)
- **Port**: 1337 (HTTP + Admin UI)
- **Backup**: PostgreSQL backup basique (Phase 1)

---

## Architecture bknd

### Qu'est-ce que bknd ?
- Backend-as-a-Service self-hosted
- Alternative à Firebase/Supabase
- Repo: https://github.com/bknd-io/bknd
- Docs: https://docs.bknd.io

### Configuration requise
- **Database**: PostgreSQL via `DB_URL=postgresql://user:pass@host:port/db`
- **Port**: 1337 (défaut)
- **Volume**: `/data` pour persistance
- **Image Docker**: Pas de pre-built, build depuis GitHub

---

## Fichiers à créer

### 1. `hosts/rhizanthella/` (dossier)

### 2. `hosts/rhizanthella/hardware-configuration.nix`
Template QEMU VM (à adapter avec les UUIDs réels lors de l'installation).

```nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/XXXX-XXXX";
    fsType = "vfat";
  };

  swapDevices = [ ];
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

### 3. `hosts/rhizanthella/bknd.nix`

Module bknd avec:
- Podman pour conteneurs OCI
- Service `postgresql-bknd-setup` (password depuis sops)
- Service `bknd-envfile` (génère DB_URL)
- Service `bknd-image-build` (build depuis GitHub)
- Conteneur `podman-bknd` (network=host, port 1337)

```nix
{ config, pkgs, lib, ... }:

let
  bkndDataDir = "/var/lib/bknd";
  bkndRuntimeDir = "/run/bknd";
  bkndPort = 1337;
in
{
  # Podman
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Directories
  systemd.tmpfiles.rules = [
    "d ${bkndDataDir} 0750 root root -"
    "d ${bkndRuntimeDir} 0700 root root -"
  ];

  # PostgreSQL password setup
  systemd.services."postgresql-bknd-setup" = {
    description = "Setup bknd PostgreSQL user";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      # Read password from sops, set PostgreSQL password
    '';
  };

  # Environment file
  systemd.services."bknd-envfile" = {
    description = "Render bknd env file";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-bknd.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      # Generate /run/bknd/bknd.env with DB_URL
    '';
  };

  # Build image from GitHub
  systemd.services."bknd-image-build" = {
    description = "Build bknd Docker image";
    wantedBy = [ "multi-user.target" ];
    before = [ "podman-bknd.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; TimeoutStartSec = 600; };
    script = ''
      podman build -t localhost/bknd:latest https://github.com/bknd-io/bknd.git#main:docker
    '';
  };

  # Container
  virtualisation.oci-containers = {
    backend = "podman";
    containers.bknd = {
      image = "localhost/bknd:latest";
      autoStart = true;
      extraOptions = [
        "--network=host"
        "--volume=${bkndDataDir}:/data"
        "--env-file=${bkndRuntimeDir}/bknd.env"
      ];
    };
  };

  systemd.services."podman-bknd" = {
    after = [ "bknd-envfile.service" "postgresql-bknd-setup.service" "bknd-image-build.service" ];
    requires = [ "bknd-envfile.service" "postgresql-bknd-setup.service" "bknd-image-build.service" ];
  };
}
```

### 4. `hosts/rhizanthella/configuration.nix`

```nix
{ config, pkgs, lib, projectConfig, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./bknd.nix
    (import ../../modules/home-manager/sops.nix { defaultSopsFile = ../../secrets/rhizanthella.yaml; })
    ../../modules/home-manager/tailscale.nix
    ../../modules/home-manager/tailscale-dns.nix
  ];

  system.stateVersion = "25.05";
  networking.hostName = "rhizanthella";
  networking.useDHCP = true;

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none";
    openFirewall = false;
  };

  # Sops
  sops = {
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [];
    };
    secrets = {
      "bknd/db_password" = { owner = "root"; group = "root"; mode = "0400"; };
    };
  };

  # PostgreSQL
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "bknd" ];
    ensureUsers = [{ name = "bknd"; ensureDBOwnership = true; }];
    settings = {
      max_connections = 100;
      shared_buffers = "256MB";
      listen_addresses = lib.mkForce "0.0.0.0";
    };
    authentication = lib.mkOverride 10 ''
      local   all   all   peer
      host    all   all   127.0.0.1/32   scram-sha-256
      host    all   all   ::1/128        scram-sha-256
    '';
  };

  # Firewall
  networking.firewall.allowedTCPPorts = [ 1337 22 ];

  # PostgreSQL backup
  services.postgresqlBackup = {
    enable = true;
    databases = [ "bknd" ];
    startAt = "daily";
    location = "/var/backup/postgresql";
    compression = "gzip";
  };

  systemd.tmpfiles.rules = [
    "d /var/backup 0750 root root -"
    "d /var/backup/postgresql 0750 postgres postgres -"
  ];
}
```

### 5. `secrets/rhizanthella.yaml`

Copie de `dandelion.yaml` avec ajout de:
```yaml
bknd:
  db_password: <mot-de-passe-généré>
```

---

## Fichiers à modifier

### 1. `scripts/install-nixos.sh`
Ajouter rhizanthella dans le menu et la validation:

**Menu interactif** (~ligne 82):
```bash
echo -e "${GREEN}6)${NC} ${YELLOW}rhizanthella${NC}"
echo -e "   🌺 bknd Backend-as-a-Service"
echo -e "   → bknd + PostgreSQL 16 (accès via Tailscale)"
echo ""
```

**Case switch** (~ligne 104):
```bash
6)
    HOST="rhizanthella"
    ;;
```

**Prompt** (ligne 86): Changer `(1-5)` en `(1-6)`

**Validation** (ligne 115-117): Ajouter `rhizanthella` à la liste

### 2. `flake.nix`
Ajouter après dandelion (~ligne 144):

```nix
# Rhizanthella - VM bknd (Backend-as-a-Service)
rhizanthella = nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit projectConfig; };
  modules = [
    ./modules/home-manager/base.nix
    ./modules/home-manager/ssh.nix
    ./hosts/rhizanthella/configuration.nix
    sops-nix.nixosModules.sops
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.jeremie = import ./home/jeremie.nix;
    }
  ];
};
```

### 2. `.sops.yaml`
Ajouter après dandelion (~ligne 44):

```yaml
  # Secrets pour l'hôte rhizanthella (VM bknd)
  - path_regex: secrets/rhizanthella\.yaml$
    key_groups:
      - age:
          - *shared
```

### 3. `config.nix` (après déploiement)
Ajouter l'IP Tailscale de rhizanthella:

```nix
tailscale = {
  hosts = {
    # ...
    rhizanthella = "100.96.250.XX";  # IP assignée par Tailscale
  };
};
```

---

## Checklist d'implémentation

### Phase 1 : Structure de base
- [x] Créer le dossier `hosts/rhizanthella/`
- [x] Créer `hosts/rhizanthella/hardware-configuration.nix` (copie de dandelion)
- [x] Créer `hosts/rhizanthella/configuration.nix`
- [x] Créer `hosts/rhizanthella/bknd.nix`

### Phase 2 : Configuration flake
- [x] Modifier `flake.nix` - ajouter nixosConfiguration rhizanthella

### Phase 3 : Secrets
- [x] Modifier `.sops.yaml` - ajouter règle rhizanthella
- [x] Créer `secrets/rhizanthella.yaml` (copie dandelion.yaml + bknd/db_password)

### Phase 4 : Script d'installation
- [x] Modifier `scripts/install-nixos.sh` - menu interactif (option 6)
- [x] Modifier `scripts/install-nixos.sh` - case switch
- [x] Modifier `scripts/install-nixos.sh` - validation des hosts

### Phase 5 : Vérification
- [ ] `nix flake check` - syntaxe OK
- [ ] `nix build .#nixosConfigurations.rhizanthella.config.system.build.toplevel` - build OK

---

## Vérification

### Build local
```bash
nix flake check
nix build .#nixosConfigurations.rhizanthella.config.system.build.toplevel
```

### Checklist post-déploiement
- [ ] VM créée dans Proxmox
- [ ] Installation NixOS via `install-nixos.sh rhizanthella`
- [ ] Clé age copiée dans `/var/lib/sops-nix/key.txt`
- [ ] Secrets configurés via `manage-secrets.sh`
- [ ] `systemctl status podman-bknd` - conteneur running
- [ ] `curl http://localhost:1337` - bknd répond
- [ ] Tailscale connecté - IP assignée
- [ ] `config.nix` mis à jour avec IP Tailscale
- [ ] Accès `http://rhizanthella:1337` via Tailscale OK

---

## Notes techniques

| Aspect | Valeur |
|--------|--------|
| **Image bknd** | Build depuis `github.com/bknd-io/bknd#main:docker` |
| **Port** | 1337 (HTTP + Admin UI) |
| **Secrets** | `secrets/rhizanthella.yaml` |
| **PostgreSQL** | Connection via `127.0.0.1:5432` (network=host) |
| **Backup** | PostgreSQL dump quotidien dans `/var/backup/postgresql` |

---

## Évolutions futures

- [ ] Module backup complet `bknd-backup.nix` (comme gitea-backup)
- [ ] Notifications Slack/Email pour backups
- [ ] Upload GDrive automatique
- [ ] Healthcheck systemd avec alerting

# Script de déploiement Node Exporter sur les nodes Proxmox (Debian)
#
# Compile un binaire statique via CGO_ENABLED=0 (pure Go, zéro dépendance),
# le copie via SSH et installe un service systemd.
#
# Usage: nix run .#deploy-proxmox
#
{ pkgs, projectConfig }:
let
  # Trouve les nodes Proxmox depuis config.nix (os == "debian")
  proxmoxNodes = builtins.filter (name:
    projectConfig.infrastructure.${name}.os == "debian"
  ) (builtins.attrNames projectConfig.infrastructure);

  # Binaire statique Node Exporter (CGO désactivé = pure Go = zéro dépendance)
  # pkgsStatic échoue car node_exporter utilise CGO par défaut (os/user, net).
  # En désactivant CGO, Go utilise ses implémentations pure-Go et produit
  # un binaire sans aucune dépendance dynamique → tourne sur n'importe quel Linux.
  nodeExporter = pkgs.prometheus-node-exporter.overrideAttrs (old: {
    CGO_ENABLED = "0";
  });

  # Service systemd pour Debian
  nodeExporterService = pkgs.writeText "node-exporter.service" ''
    [Unit]
    Description=Prometheus Node Exporter (deployed via Nix)
    Wants=network-online.target
    After=network-online.target

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/node_exporter
    Restart=always
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
  '';

  nodeList = builtins.concatStringsSep " " proxmoxNodes;
in
pkgs.writeShellScriptBin "deploy-proxmox" ''
  set -euo pipefail

  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'

  echo ""
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo -e "''${CYAN}Deploy Node Exporter to Proxmox nodes''${NC}"
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo ""

  NODES="${nodeList}"
  BINARY="${nodeExporter}/bin/node_exporter"
  SERVICE="${nodeExporterService}"
  DEPLOYED=()
  SKIPPED=()
  FAILED=()

  for node in $NODES; do
    echo -e "''${BLUE}Deploying to $node...''${NC}"

    # Test SSH connectivity
    if ! timeout 5 ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$node" "echo ok" &>/dev/null; then
      echo -e "  ''${YELLOW}$node is offline or unreachable, skipping''${NC}"
      SKIPPED+=("$node")
      echo ""
      continue
    fi

    # Stop service if running
    ssh "root@$node" "systemctl stop node-exporter 2>/dev/null || true"

    # Copy binary
    echo "  Copying node_exporter binary..."
    scp -q "$BINARY" "root@$node:/usr/local/bin/node_exporter"
    ssh "root@$node" "chmod +x /usr/local/bin/node_exporter"

    # Copy service file
    echo "  Installing systemd service..."
    scp -q "$SERVICE" "root@$node:/etc/systemd/system/node-exporter.service"

    # Enable and start
    ssh "root@$node" "systemctl daemon-reload && systemctl enable --now node-exporter"

    # Verify
    if ssh "root@$node" "systemctl is-active node-exporter" &>/dev/null; then
      echo -e "  ''${GREEN}$node: node_exporter running''${NC}"
      DEPLOYED+=("$node")
    else
      echo -e "  ''${RED}$node: failed to start''${NC}"
      FAILED+=("$node")
    fi
    echo ""
  done

  # Summary
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo -e "''${CYAN}Deployment Summary''${NC}"
  echo -e "''${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''${NC}"
  echo ""

  if [ ''${#DEPLOYED[@]} -gt 0 ]; then
    for h in "''${DEPLOYED[@]}"; do
      echo -e "  ''${GREEN}$h''${NC}"
    done
  fi
  if [ ''${#SKIPPED[@]} -gt 0 ]; then
    for h in "''${SKIPPED[@]}"; do
      echo -e "  ''${YELLOW}$h (skipped)''${NC}"
    done
  fi
  if [ ''${#FAILED[@]} -gt 0 ]; then
    for h in "''${FAILED[@]}"; do
      echo -e "  ''${RED}$h (failed)''${NC}"
    done
    exit 1
  fi

  echo ""
  echo -e "''${GREEN}All reachable Proxmox nodes deployed!''${NC}"
''

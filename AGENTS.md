# AGENTS.md

This file gives repo-specific guidance for coding agents.

## Scope
- Nix flake-based configuration for multiple NixOS hosts and one macOS (nix-darwin) host.
- Source of truth is `flake.nix` and the host modules under `hosts/` and `modules/`.

## Repo map (high level)
- `flake.nix`, `flake.lock`: main entry point and inputs.
- `hosts/<host>/`: per-host NixOS or Darwin configuration.
- `modules/`: shared NixOS and Home Manager modules.
- `home/`: Home Manager user configs.
- `secrets/`: sops-encrypted secrets plus `.example` templates.
- `iso/`: standalone flake for building the custom installer ISO.
- `scripts/`: install and activation helpers.
- `docs/`: deployment and operational docs (mostly in French).

## Common commands
Run from repo root unless noted.
- NixOS switch: `sudo nixos-rebuild switch --flake .#<host>`
- Mimosa bootstrap: `sudo nixos-rebuild switch --flake .#mimosa-bootstrap`
- Darwin switch (macOS): `darwin-rebuild switch --flake .#marigold`
- Flake validation (optional): `nix flake check`
- Build installer ISO (root flake): `nix build .#nixosConfigurations.installer.config.system.build.isoImage`
- Build ISO (iso flake): `cd iso && nix build .#nixosConfigurations.iso-minimal-ttyS0.config.system.build.isoImage`

## Secrets and safety
- Do not edit `secrets/*.yaml` in plain text. Use `sops` with the correct age key.
- Keep `.sops.yaml` in sync when adding new secret files or hosts.
- Use `secrets/<host>.yaml.example` as the starting point for new hosts.
- Never commit decrypted secrets or logs that reveal secret values.
- See `docs/SECRETS.md` for the full workflow.

## Conventions
- Documentation is primarily in French; keep tone and structure consistent when editing docs.
- When adding a new host, update `flake.nix`, create `hosts/<host>/`, and add matching secrets and docs.
- Prefer small, isolated changes and include any necessary doc updates in the same PR.

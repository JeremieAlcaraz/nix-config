# SSH (marigold)

- `config`: configuration SSH principale (symlink vers `~/.ssh/config`).
- `public/`: clés publiques + `authorized_keys`.
- Les clés privées sont chiffrées via SOPS et matérialisées par Home Manager
  dans `~/.ssh`.

set shell := ["bash", "-lc"]

# Promote playground → main : commit (si changes), push, merge, hm-prod
promote:
    git add --all
    git diff-index --quiet HEAD -- || git commit -m "chore: promote playground → main"
    git push -u origin playground
    git -C ~/c/nix-config/main fetch origin
    git -C ~/c/nix-config/main merge playground --no-edit
    git -C ~/c/nix-config/main push origin main
    cd ~/c/nix-config/main && home-manager switch -b backup --flake .#jeremiealcaraz

restore-n8n:
	sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-n8n.sh

restore-gitea:
	sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-gitea.sh

update-host-tsv:
	./scripts/update-install-hosts.py --tailscale

build-iso:
	cd iso && ./build-iso.sh

poppy-verify-drive:
	ssh root@poppy 'bash -s' < hosts/poppy/scripts/verify-drive-target.sh

poppy-test-drive-write:
	ssh root@poppy 'bash -s' < hosts/poppy/scripts/test-drive-write.sh

poppy-tail-sync-log:
	ssh root@poppy 'tail -n 80 /var/log/rclone-sync.log'

poppy-dry-run:
	./scripts/poppy/apply-from-magnolia.sh dry-run

poppy-apply:
	./scripts/poppy/apply-from-magnolia.sh apply

poppy-check:
	./scripts/poppy/check.sh

ts-policy-sync *args='':
	./scripts/tailscale/ts-policy-sync.py {{args}}

ts-serve host service port:
	./scripts/tailscale/ts-serve-on-host.sh {{host}} {{service}} {{port}}

ts-service-ensure service port:
	./scripts/tailscale/ts-service-ensure.py {{service}} {{port}}

ts-service-add service host port tag='tag:newmachine':
	./scripts/tailscale/ts-service-add.py {{service}} {{host}} {{port}} --tag {{tag}}

# ── Restic ──────────────────────────────────────────────────────────
poppy-restic-status:
	ssh root@poppy 'RESTIC_PASSWORD="$(grep ^RESTIC_PASSWORD= /root/.config/restic/env | tr -d "\047" | cut -d= -f2)" && export RESTIC_PASSWORD && echo "=== Snapshots ===" && for repo in memos-bak vikunja-bak moodboard-bak twenty-bak; do echo "--- $repo ---" && timeout 60 restic snapshots --repo "rclone:gdrive_capsule:$repo" 2>&1 | head -3; done && echo "" && echo "=== Timers ===" && systemctl list-timers --all | grep restic'

poppy-restic-backup app:
	ssh root@poppy 'RESTIC_PASSWORD="$(grep ^RESTIC_PASSWORD= /root/.config/restic/env | tr -d "\047" | cut -d= -f2)" && export RESTIC_PASSWORD && bash /root/apps/restic/{{app}}-restic-backup.sh'

poppy-restic-restore:
	ssh root@poppy 'bash /root/apps/restic/restic-restore.sh'

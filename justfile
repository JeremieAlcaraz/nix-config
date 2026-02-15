set shell := ["bash", "-lc"]

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

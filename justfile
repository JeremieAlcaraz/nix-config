set shell := ["bash", "-lc"]

restore-n8n:
	sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-n8n.sh

restore-gitea:
	sudo nix-shell -p sops rclone fzf jq yq-go --run ./scripts/restore-gitea.sh

update-host-tsv:
	./scripts/update-install-hosts.py --tailscale

build-iso:
	cd iso && ./build-iso.sh

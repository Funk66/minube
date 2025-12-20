set -o vi

alias pod='sudo -u podman XDG_RUNTIME_DIR=/run/user/2000 podman'
alias pods='pod ps --all --format "table {{.Names}}\t{{.Status}}"'

aws() {
	podman run --rm -v /:/host docker.io/amazon/aws-cli "$@"
}

postgres() {
	# shellcheck source=/dev/null
	. /data/immich/env
	local IMAGE
	IMAGE="$(podman images --format '{{.Repository}}:{{.Tag}}' | grep '^ghcr.io/immich-app/postgres' | head -n 1)"
	podman run --rm -e PGPASSWORD="${DB_PASSWORD}" --network minube-public -it "${IMAGE}" psql -h postgres -U postgres
}

# pods() {
# 	sudo systemctl --machine username@ --user list-unit-files
# }

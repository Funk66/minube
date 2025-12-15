podman run \
	--name postgres \
	-e POSTGRES_PASSWORD=squiggle-traffic-crazy \
	-e POSTGRES_USER=paperless \
	-e POSTGRES_DB=paperless \
	-v /data/paperless/export/paperless.sql:/docker-entrypoint-initdb.d/backup.sql \
	-v /data/paperless/postgres:/var/lib/postgresql \
	--userns=keep-id:uid=0,gid=0 \
	-it \
	docker.io/library/postgres:18

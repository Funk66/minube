# Devcontainer template

Adapted from Coder's (Docker (Dev Containers))[[https://github.com/coder/coder/tree/main/examples/templates/docker-devcontainer]] starter template:

Add `signal (receive) set=(term) peer=podman,` to the `profile pasta`
block in `/etc/apparmor.d/usr.bin.pasta` to allow `SIGTERM` from
processes under the `podman` profile.

## Deploy

```sh
coder templates push devcontainer \
  --directory . \
  --icon /icon/docker.svg \
  --name "$(git rev-parse --short HEAD)"
```

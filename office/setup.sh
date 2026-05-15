#!/usr/bin/env bash
#
# One-time setup for the office server (run as root).
# Configures cgroups, systemd delegation, and kernel tunables
# required by rootless Podman on Raspberry Pi.

set -euo pipefail

# Delegate cgroup controllers to user sessions (required by rootless Podman)
mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF >/etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=yes
EOF

# Enable memory cgroup controller (disabled by default on Raspberry Pi)
sed -i 's/cgroup_disable=memory //; s/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt

# Allow memory overcommit (required by Redis/Valkey)
echo 'vm.overcommit_memory = 1' >/etc/sysctl.d/99-valkey.conf

echo "Done. Reboot for changes to take effect."

#!/usr/bin/env python3
"""
Build fs.tar.gz from the assets directory tree.

Produces a tarball that can be extracted at / on the target server,
with correct paths, ownership, and permissions baked in.

Mapping:
  assets/fs/*       -> / (uid=0, gid=0)       root-owned system config
  assets/podman/*   -> /home/podman/.config/containers/systemd/ (uid=2000, gid=2000)
  assets/systemd/*  -> /home/podman/.config/systemd/user/       (uid=2000, gid=2000)

Permissions:
  .sh files -> 0755
  all other -> 0644
  directories -> 0755
"""

import os
import sys
import tarfile

ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets")
OUTPUT = os.path.join(ASSETS_DIR, "fs.tar.gz")

ROOT_UID = 0
ROOT_GID = 0
PODMAN_UID = 2000
PODMAN_GID = 2000

# (source_dir_relative_to_assets, target_prefix_in_tar, uid, gid)
MAPPINGS = [
    ("fs", "", ROOT_UID, ROOT_GID),
    ("podman", "home/podman/.config/containers/systemd", PODMAN_UID, PODMAN_GID),
    ("systemd", "home/podman/.config/systemd/user", PODMAN_UID, PODMAN_GID),
]


def add_directory(tar, arcname, uid, gid):
    """Add a directory entry to the tarball."""
    info = tarfile.TarInfo(name=arcname)
    info.type = tarfile.DIRTYPE
    info.mode = 0o755
    info.uid = uid
    info.gid = gid
    info.uname = "root" if uid == 0 else "podman"
    info.gname = "root" if gid == 0 else "podman"
    tar.addfile(info)


def main():
    created_dirs = set()

    with tarfile.open(OUTPUT, "w:gz") as tar:
        for source_rel, prefix, uid, gid in MAPPINGS:
            source_dir = os.path.join(ASSETS_DIR, source_rel)
            if not os.path.isdir(source_dir):
                print(
                    f"Warning: {source_dir} does not exist, skipping", file=sys.stderr
                )
                continue

            for root, dirs, files in os.walk(source_dir):
                dirs.sort()
                for filename in sorted(files):
                    filepath = os.path.join(root, filename)
                    relpath = os.path.relpath(filepath, source_dir)

                    if prefix:
                        arcname = os.path.join(prefix, relpath)
                    else:
                        arcname = relpath

                    # Normalize path separators
                    arcname = arcname.replace(os.sep, "/")

                    # Ensure parent directories exist in the archive
                    parts = arcname.split("/")
                    for i in range(1, len(parts)):
                        parent = "/".join(parts[:i])
                        if parent not in created_dirs:
                            add_directory(tar, parent, uid, gid)
                            created_dirs.add(parent)

                    # Add the file
                    info = tar.gettarinfo(filepath, arcname=arcname)
                    info.uid = uid
                    info.gid = gid
                    info.uname = "root" if uid == 0 else "podman"
                    info.gname = "root" if gid == 0 else "podman"
                    info.mode = 0o755 if filename.endswith(".sh") else 0o644

                    with open(filepath, "rb") as f:
                        tar.addfile(info, f)

    print(f"Created {OUTPUT}")
    # List contents for verification
    with tarfile.open(OUTPUT, "r:gz") as tar:
        print(f"  {len(tar.getmembers())} entries")


if __name__ == "__main__":
    main()

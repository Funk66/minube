#!/usr/bin/env python3
"""Sync the minube GitHub repository onto the local host.

Run it directly from GitHub on a machine that should receive the config:

    python3 <(curl -sSL https://raw.githubusercontent.com/Funk66/minube/master/scripts/sync.py)

or from inside a local clone of the repository:

    python3 scripts/sync.py

What it does
------------
* Downloads the latest tarball of the ``Funk66/minube`` repository from GitHub.
* Compares the repository files that map onto host paths with the local ones:

                          repo path              host path
                          ---------------       ---------------------
                          home/config/...       $HOME/.config/...
                          home/local/...        $HOME/.local/...
                          assets/fs/...         /...
                          assets/systemd/...   /etc/systemd/system/...

* Writes host files that are missing or drifted, replacing them with the
  latest version coming from the repository.

* When systemd / podman-quadlet unit files were modified it asks the user
  about the detected drift, and - after confirmation - reloads the user
  manager (``systemctl --user daemon-reload``) and restarts the affected
  services, reporting failures afterwards.

* Checks that host directories referenced by container ``Volume=`` mounts
  actually exist.

Only the Python standard library is used, so the script also runs on hosts
that do not have third party packages (e.g. ``python-rich``) installed.

The script cleans up its temporary working directory automatically and does
not leave any files behind.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
from dataclasses import dataclass
from pathlib import Path

GITHUB_REPO = "Funk66/minube"
GITHUB_API_BASE = f"https://api.github.com/repos/{GITHUB_REPO}"
FETCH_TIMEOUT = 120.0
SERVICE_RESTART_DELAY = 3.0
JOURNAL_TAIL_LINES = 60

# (repository relative directory, host target directory)
SOURCE_ROOTS: list[tuple[str, str]] = [
    ("home/config", "~/.config"),
    ("home/local", "~/.local"),
    ("assets/fs", "/"),
    ("assets/systemd", "/etc/systemd/system"),
]


# --------------------------------------------------------------------------
# output helpers (pure standard library, ANSI colors, no third party deps)
# --------------------------------------------------------------------------

_USE_COLOR = sys.stdout.isatty()


def _paint(code: str, text: str) -> str:
    if not _USE_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"


def bold(text: str) -> str:
    return _paint("1", text)


def dim(text: str) -> str:
    return _paint("2", text)


def ok(text: str) -> str:
    return _paint("0;32", text)


def err(text: str) -> str:
    return _paint("0;31", text)


def warn(text: str) -> str:
    return _paint("0;33", text)


def info(text: str) -> str:
    return _paint("0;36", text)


def print_line(text: str = "") -> None:
    print(text, flush=True)


def banner() -> None:
    print_line(bold("=" * 72))
    print_line(bold(f"  minube sync  ·  {GITHUB_REPO}  ·  github.com/Funk66/minube"))
    print_line(bold("=" * 72))


# --------------------------------------------------------------------------
# data model
# --------------------------------------------------------------------------


@dataclass
class Change:
    host: Path
    repo_rel: str
    status: str  # "added" | "modified"
    src: Path  # absolute path of the file inside the repository checkout


# --------------------------------------------------------------------------
# repository download
# --------------------------------------------------------------------------


def _download(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "minube-sync"})
    with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as resp:
        return resp.read()


def fetch_repo_root(tmpdir: Path) -> Path:
    """Download the latest tarball of the GitHub repository and extract it."""
    branch = None
    try:
        branch = json.loads(_download(f"{GITHUB_API_BASE}/{GITHUB_REPO}").decode("utf-8")).get("default_branch")
    except Exception:
        branch = None

    candidates: list[str] = []
    if branch:
        candidates.append(branch)
    candidates.extend(["master", "main"])

    data: bytes | None = None
    for cand in dict.fromkeys(candidates):
        try:
            data = _download(f"{GITHUB_API_BASE}/{GITHUB_REPO}/tarball/{cand}")
            break
        except Exception:
            data = None

    if data is None:
        raise RuntimeError("could not download the repository tarball from GitHub")

    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    try:
        try:
            tf.extractall(path=str(tmpdir), filter="data")
        except TypeError:
            tf.extractall(path=str(tmpdir))
    finally:
        tf.close()

    entries = sorted(tmpdir.iterdir(), key=lambda p: p.name)
    top = entries[0] if len(entries) == 1 else tmpdir
    root = top if top.is_dir() else tmpdir
    return root


# --------------------------------------------------------------------------
# sync logic
# --------------------------------------------------------------------------


def sync_sources(repo_root: Path, changed: list[Change], apply: bool) -> None:
    for src_name, target_raw in SOURCE_ROOTS:
        target_root = Path(os.path.expanduser(target_raw))
        base = repo_root / src_name
        if not base.is_dir():
            continue

        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for fn in sorted(filenames):
                src = Path(dirpath) / fn
                rel = src.relative_to(base).as_posix()
                dst = target_root.joinpath(*rel.split("/"))

                identical = False
                if dst.is_file():
                    try:
                        identical = dst.read_bytes() == src.read_bytes()
                    except OSError:
                        identical = False

                if identical:
                    continue

                status = "modified" if dst.exists() else "added"
                if not apply:
                    changed.append(Change(dst, rel, status, src))
                    continue

                tmp = dst.parent / f".{dst.name}.sync-{os.getpid()}"
                try:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    with open(tmp, "wb") as fh:
                        fh.write(src.read_bytes())
                        fh.flush()
                        os.fsync(fh.fileno())
                    os.chmod(tmp, stat.S_IMODE(src.stat().st_mode))
                    os.replace(tmp, dst)
                except OSError as exc:
                    print_line(err(f"  ! failed to write {dst}: {exc}"))
                finally:
                    if tmp.exists():
                        try:
                            tmp.unlink()
                        except OSError:
                            pass

                changed.append(Change(dst, rel, status, src))


# --------------------------------------------------------------------------
# systemd / quadlet helpers
# --------------------------------------------------------------------------


def run_systemctl(args: list[str], timeout: float = 90.0) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=timeout)
    except Exception as exc:
        failed = subprocess.CompletedProcess(["systemctl", "--user", *args], returncode=1)
        failed.stdout = ""
        failed.stderr = f"{type(exc).__name__}: {exc}"
        return failed


def journal_tail(unit: str, lines: int = JOURNAL_TAIL_LINES) -> str:
    try:
        res = subprocess.run(
            ["journalctl", "--user", "-u", unit, "--no-pager", "-n", str(lines)],
            capture_output=True,
            text=True,
            timeout=30.0,
        )
        return (res.stdout or "").strip()
    except Exception:
        return ""


def unit_names_for(changed: list[Change]) -> list[str]:
    units: set[str] = set()
    for ch in changed:
        name = ch.repo_rel.rsplit("/", 1)[-1]
        if name.endswith(".container"):
            units.add(name[: -len(".container")] + ".service")
        elif name.endswith(".service") or name.endswith(".timer"):
            units.add(name)
    return sorted(units)


def volume_sources(text: str) -> list[str]:
    sources: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        key, sep, value = line.partition("=")
        if not sep:
            continue
        if key.strip().lower() not in ("volume", "mount"):
            continue
        parts = [p.strip() for p in value.split(":")]
        src = parts[0].strip()
        if not src:
            continue
        sources.append(src)
    return sources


def resolve_host_path(path: str, home: Path, uid: int, state_dir: Path) -> str:
    p = path.strip()
    if p.startswith("~"):
        p = os.path.expanduser(p)

    def repl(m: re.Match) -> str:
        tok = m.group(0)
        if tok in ("%h", "%H"):
            return str(home)
        if tok in ("%U", "%u"):
            return str(uid)
        if tok in ("%S", "%s"):
            return str(state_dir)
        return tok

    p = re.sub(r"%[A-Za-z]", repl, p)
    return os.path.normpath(p)


def check_container_volumes(repo_root: Path, home: Path, uid: int, state_dir: Path) -> list[tuple[str, str, str]]:
    """Check that host directories referenced by container Volume= mounts exist."""
    issues: list[tuple[str, str, str]] = []
    containers: list[tuple[str, Path]] = []

    for src_name, _target_raw in SOURCE_ROOTS:
        base = repo_root / src_name
        if not base.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames.sort()
            for fn in sorted(filenames):
                f = Path(dirpath) / fn
                if not fn.endswith(".container"):
                    continue
                unit = fn[: -len(".container")] + ".service"
                containers.append((unit, f))

    for unit, f in containers:
        if not f.is_file():
            continue
        try:
            text = f.read_text(errors="replace")
        except OSError:
            continue
        for src in volume_sources(text):
            resolved = resolve_host_path(src, home, uid, state_dir)
            if not os.path.exists(resolved):
                issues.append((unit, src, resolved))
    return issues


def reload_and_restart(units: list[str]) -> list[tuple[str, bool]]:
    results: list[tuple[str, bool]] = []

    res = run_systemctl(["daemon-reload"])
    if res.returncode != 0:
        print_line(err(f"  ! systemctl --user daemon-reload failed: {(res.stderr or res.stdout or '').strip()}"))

    for unit in units:
        res = run_systemctl(["restart", unit])
        if res.returncode != 0:
            print_line(err(f"  ! restarting {unit} failed: {(res.stderr or res.stdout or '').strip()}"))
            results.append((unit, False))
            continue

        time.sleep(SERVICE_RESTART_DELAY)

        st = run_systemctl(["is-active", unit])
        active = (st.stdout or "").strip() == "active" and st.returncode == 0
        results.append((unit, active))

        if not active:
            tail = journal_tail(unit)
            print_line(err(f"  ! service {unit} is not running after restart"))
            for line in tail.splitlines()[-15:]:
                print_line(dim(f"      | {line}"))

    return results


def confirm(prompt: str) -> bool:
    while True:
        try:
            answer = input(f"{warn('?')} {prompt} [y/N]: ").strip().lower()
        except EOFError:
            return False
        if answer in ("", "n", "no", "false", "0"):
            return False
        if answer in ("y", "yes", "true", "1"):
            return True


def find_repo_root() -> Path | None:
    """Return the local checkout of the repository, if one is in use."""
    env_dir = os.environ.get("MINUBE_REPO_DIR")
    if env_dir:
        candidate = Path(env_dir).resolve()
        if candidate.is_dir():
            return candidate
        return None

    try:
        here = Path(__file__).resolve()
    except OSError:
        return None

    for candidate in (here.parent.parent, here.parent, here):
        if (candidate / ".git").exists() or (candidate / "home").exists() or (candidate / "assets").exists():
            return candidate
    return None


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="sync.py",
        description="Sync the minube GitHub repository onto the local host.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="compare host paths with the repository and report, but do not write files or restart services",
    )
    args = parser.parse_args(argv)

    home = Path.home()
    if not home.is_dir():
        print_line(err(f"HOME directory does not exist: {home}"))
        return 1

    state_dir = Path(os.environ.get("XDG_STATE_HOME") or str(home / ".local" / "state"))
    uid = os.getuid() if hasattr(os, "getuid") else -1

    banner()
    print_line(info("Scanning repository source roots:"))
    for src_name, target_raw in SOURCE_ROOTS:
        print_line(f"  - {src_name:<22} -> {os.path.expanduser(target_raw)}")

    changed: list[Change] = []
    repo_root = find_repo_root()
    if repo_root is None:
        with tempfile.TemporaryDirectory(prefix="minube-sync-") as td:
            repo_root = fetch_repo_root(Path(td))
    sync_sources(repo_root, changed, apply=not args.dry_run)

    added = [c for c in changed if c.status == "added"]
    modified = [c for c in changed if c.status == "modified"]

    if changed:
        print_line("")
        print_line(bold(f"Changes detected: {len(modified)} modified, {len(added)} added"))
        if modified:
            print_line(dim("  modified:"))
            for c in modified:
                print_line(f"  ~ {c.host}   (repo: {c.repo_rel})")
        if added:
            print_line(dim("  added:"))
            for c in added:
                print_line(f"  + {c.host}   (repo: {c.repo_rel})")
    else:
        print_line(ok("No drift detected - everything under the managed host paths is in sync."))

    units = unit_names_for(changed)

    issues = check_container_volumes(repo_root, home, uid, state_dir)
    if issues:
        print_line("")
        print_line(bold("Container volume checks (host directories referenced by Volume= mounts):"))
        for unit, src, resolved in issues:
            print_line(err(f"  X {unit}: host directory does not exist: {resolved}   (from Volume={src})"))

    if units and not args.dry_run:
        print_line("")
        prompt = "systemd/quadlet drift detected - reload the systemd user manager and restart the affected services?"
        if confirm(prompt):
            results = reload_and_restart(units)
            for unit, running in results:
                if running:
                    print_line(ok(f"  ✓ service {unit} restarted and is running"))
                else:
                    print_line(err(f"  X service {unit} failed to start / is not running"))
        elif changed:
            print_line(dim("  Drift acknowledged but not applied - no services were restarted."))

    print_line("")
    print_line(bold("=" * 72))
    if args.dry_run:
        print_line(warn("Dry-run mode: no files were written and no services were restarted."))
    print_line(ok("minube sync finished"))
    print_line(bold("=" * 72))

    return 0


if __name__ == "__main__":
    try:
        _exit_code = main()
    except Exception as exc:  # keep failures easy to read for the user
        print_line(err(f"sync aborted: {type(exc).__name__}: {exc}"))
        _exit_code = 1
    raise SystemExit(_exit_code)

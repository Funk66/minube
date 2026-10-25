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

  Only the repository directories living under the ``home/`` prefix are
  managed - the sync never touches host paths outside the user's home
  directory.

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
import difflib
import io
import json
import logging
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
TARBALL_BASE = f"{GITHUB_API_BASE}/tarball"
FETCH_TIMEOUT = 120.0
SERVICE_RESTART_DELAY = 3.0
JOURNAL_TAIL_LINES = 60

# (repository relative directory, host target directory)
# Only repository directories under the repo's ``home/`` prefix are synced,
# and they always map onto paths inside the user's home directory.
SOURCE_ROOTS: list[tuple[str, str]] = [
    ("home/config", "~/.config"),
    ("home/local", "~/.local"),
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


LOG_FORMAT = "%(levelname)s: %(message)s"


class _LevelRangeFilter(logging.Filter):
    """Allow only records whose level is within ``[min_level, max_level]``."""

    def __init__(self, min_level: int, max_level: int) -> None:
        super().__init__()
        self.min_level = min_level
        self.max_level = max_level

    def filter(self, record: logging.LogRecord) -> bool:
        return self.min_level <= record.levelno <= self.max_level


class ColorFormatter(logging.Formatter):
    """Colorize the level name, mirroring the plain-stdlib color helpers.

    Colors are only used when the stream is attached to an interactive
    terminal, so redirected or piped output stays plain text.
    """

    LEVEL_COLORS = {
        "DEBUG": "2",
        "INFO": "0;36",
        "WARNING": "0;33",
        "ERROR": "0;31",
        "CRITICAL": "1;31",
    }

    def __init__(self) -> None:
        super().__init__(fmt=LOG_FORMAT)

    def format(self, record: logging.LogRecord) -> str:
        levelname = record.levelname
        color = self.LEVEL_COLORS.get(levelname)
        if color and _USE_COLOR:
            levelname = f"\033[{color}m{levelname}\033[0m"
        original = record.levelname
        record.levelname = levelname
        try:
            return super().format(record)
        finally:
            record.levelname = original


def _setup_logging(level: int = logging.INFO) -> logging.Logger:
    """Wire the console handlers of the ``minube.sync`` logger.

    Debug and informational records are written to stdout, while warnings
    and failures are written to stderr - mirroring the usual unix
    convention.  The verbosity can be changed through the ``--log-level``
    command line option.
    """
    log = logging.getLogger("minube.sync")
    log.setLevel(level)
    log.propagate = False

    formatter = ColorFormatter()
    out = logging.StreamHandler(sys.stdout)
    out.setLevel(logging.DEBUG)
    out.addFilter(_LevelRangeFilter(logging.DEBUG, logging.INFO))
    out.setFormatter(formatter)
    log.addHandler(out)

    err_handler = logging.StreamHandler(sys.stderr)
    err_handler.setLevel(logging.WARNING)
    err_handler.addFilter(_LevelRangeFilter(logging.WARNING, logging.CRITICAL))
    err_handler.setFormatter(formatter)
    log.addHandler(err_handler)

    return log


logger = logging.getLogger("minube.sync")


def banner() -> None:
    logger.info(bold("=" * 72))
    logger.info(bold(f"  minube sync  ·  {GITHUB_REPO}  ·  github.com/Funk66/minube"))
    logger.info(bold("=" * 72))


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


def _download(url: str) -> tuple[bytes, str | None]:
    """Download a URL, returning the payload together with the GitHub cache status."""
    req = urllib.request.Request(url, headers={"User-Agent": "minube-sync"})
    with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as resp:
        cache_status = (resp.headers.get("X-GitHub-Cache") or "").strip() or None
        data = resp.read()
    return data, cache_status


def fetch_repo_root(tmpdir: Path) -> Path:
    """Download the latest tarball of the GitHub repository and extract it."""
    branch = None
    try:
        branch = json.loads(_download(GITHUB_API_BASE)[0].decode("utf-8")).get("default_branch")
    except (OSError, ValueError):
        branch = None

    candidates: list[str] = []
    if branch:
        candidates.append(branch)
    candidates.extend(["master", "main"])

    data: bytes | None = None
    cache_status: str | None = None
    for cand in dict.fromkeys(candidates):
        try:
            data, cache_status = _download(f"{TARBALL_BASE}/{cand}")
            break
        except (OSError, ValueError):
            data = None

    if data is None:
        raise RuntimeError("could not download the repository tarball from GitHub")

    logger.info("Downloaded repository tarball from GitHub (branch candidate: %s)", cand)
    if cache_status:
        logger.debug("GitHub reported the tarball cache status as: %s", cache_status)
        if cache_status.upper() == "HIT":
            logger.info("The downloaded repository is being served from the GitHub cache")

    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf:
        try:
            tf.extractall(path=str(tmpdir), filter="data")
        except TypeError:
            tf.extractall(path=str(tmpdir))

    entries = sorted(tmpdir.iterdir(), key=lambda p: p.name)
    top = entries[0] if len(entries) == 1 else tmpdir
    root = top if top.is_dir() else tmpdir
    return root


# --------------------------------------------------------------------------
# sync logic
# --------------------------------------------------------------------------


def _write_file(dst: Path, src: Path) -> None:
    """Atomically replace the host file with the repository content."""
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
        logger.error(f"  ! failed to write {dst}: {exc}")
    finally:
        if tmp.exists():
            try:
                tmp.unlink()
            except OSError:
                pass


def _print_diff(src: Path, dst: Path) -> None:
    """Print a unified diff of the host file (``dst``) against the repository one (``src``)."""
    src_bytes = src.read_bytes()
    dst_bytes = dst.read_bytes() if dst.is_file() else b""
    src_lines = src_bytes.decode("utf-8", errors="replace").splitlines()
    dst_lines = dst_bytes.decode("utf-8", errors="replace").splitlines()
    diff = list(difflib.unified_diff(dst_lines, src_lines, fromfile=str(dst), tofile=str(src), lineterm=""))

    def paint(line: str) -> str:
        if line.startswith("@@") or line.startswith("---") or line.startswith("+++"):
            return bold(line) if _USE_COLOR else line
        if line.startswith("+"):
            return ok(line) if _USE_COLOR else line
        if line.startswith("-"):
            return err(line) if _USE_COLOR else line
        return line

    for line in diff:
        print(paint(line))


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
                    logger.debug("Host file %s is already in sync with the repository", dst)
                    continue

                status = "modified" if dst.exists() else "added"

                # Show the drift between the host file and the repository copy.
                _print_diff(src, dst)

                if not apply:
                    changed.append(Change(dst, rel, status, src))
                    continue

                if status == "added":
                    # Files that are missing on the host are created anew
                    # by copying the repository content in full.
                    _write_file(dst, src)
                    changed.append(Change(dst, rel, status, src))
                    continue

                # For modified files the user decides file by file whether to sync.
                if not confirm(f"Sync {dst} from the repository?"):
                    logger.info(f"Skipped {dst} - sync declined by user")
                    continue

                _write_file(dst, src)
                changed.append(Change(dst, rel, status, src))


# --------------------------------------------------------------------------
# systemd / quadlet helpers
# --------------------------------------------------------------------------


def run_systemctl(args: list[str], timeout: float = 90.0) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            ["systemctl", "--user", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        failed = subprocess.CompletedProcess(["systemctl", "--user", *args], returncode=1)
        failed.stdout = ""
        failed.stderr = f"{type(exc).__name__}: {exc}"
        return failed


def journal_tail(unit: str, lines: int = JOURNAL_TAIL_LINES) -> str:
    try:
        res = subprocess.run(
            ["journalctl", "--user", "-u", unit, "--no-pager", "-n", str(lines)],
            check=False,
            capture_output=True,
            text=True,
            timeout=30.0,
        )
        return (res.stdout or "").strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def unit_names_for(changed: list[Change]) -> list[str]:
    units: set[str] = set()
    for ch in changed:
        name = ch.repo_rel.rsplit("/", 1)[-1]
        if name.endswith(".container"):
            units.add(name[: -len(".container")] + ".service")
        elif name.endswith((".service", ".timer")):
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
        if tok == "%E":
            # ``%E`` is the configuration directory root: ``/etc`` for the system
            # manager, ``$XDG_CONFIG_HOME`` (``~/.config``) for the user manager.
            return os.path.expanduser(str(os.environ.get("XDG_CONFIG_HOME") or "~/.config"))
        if tok in ("%U", "%u"):
            return str(uid)
        if tok in ("%S", "%s"):
            return str(state_dir)
        return tok

    p = re.sub(r"%[A-Za-z]", repl, p)
    return os.path.normpath(p)


def _is_host_mount_source(src: str) -> bool:
    """Return whether ``src`` refers to a host filesystem path that should be checked.

    Bare source names - e.g. ``academy-cache`` or ``immich`` - are podman *named*
    volumes, not host directories, so they must not be treated as missing paths.
    Paths written with systemd specifiers (``%h``, ``%E``, ``%S``, ...) are host paths,
    while runtime paths (``%t/...``) and unknown specifiers are not host config dirs.
    """
    s = src.strip()
    if not s:
        return False
    if s.startswith("/") or s.startswith("~"):
        return True
    if s.startswith("%"):
        tok = re.match(r"%[A-Za-z]", s).group(0)
        return tok in ("%h", "%E", "%S", "%C", "%D", "%L")
    return False


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
            if not _is_host_mount_source(src):
                # Named podman volumes (``name:/container/path``) are not host directories.
                continue
            resolved = resolve_host_path(src, home, uid, state_dir)
            if not os.path.exists(resolved):
                issues.append((unit, src, resolved))
    return issues


def reload_and_restart(units: list[str]) -> list[tuple[str, bool]]:
    results: list[tuple[str, bool]] = []

    res = run_systemctl(["daemon-reload"])
    if res.returncode != 0:
        logger.error(f"  ! systemctl --user daemon-reload failed: {(res.stderr or res.stdout or '').strip()}")

    for unit in units:
        res = run_systemctl(["restart", unit])
        if res.returncode != 0:
            logger.error(f"  ! restarting {unit} failed: {(res.stderr or res.stdout or '').strip()}")
            results.append((unit, False))
            continue

        time.sleep(SERVICE_RESTART_DELAY)

        st = run_systemctl(["is-active", unit])
        active = (st.stdout or "").strip() == "active" and st.returncode == 0
        results.append((unit, active))

        if not active:
            tail = journal_tail(unit)
            logger.error(f"  ! service {unit} is not running after restart")
            for line in tail.splitlines()[-15:]:
                logger.debug(f"      | {line}")

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
    parser.add_argument(
        "--log-level",
        default="info",
        choices=("debug", "info", "warning", "error", "critical"),
        help="log verbosity (default: info)",
    )
    args = parser.parse_args(argv)

    _setup_logging(logging.getLevelName(args.log_level.upper()))

    home = Path.home()
    if not home.is_dir():
        logger.error(f"HOME directory does not exist: {home}")
        return 1

    state_dir = Path(os.environ.get("XDG_STATE_HOME") or str(home / ".local" / "state"))
    uid = os.getuid() if hasattr(os, "getuid") else -1

    banner()
    logger.info(info("Scanning repository source roots:"))
    for src_name, target_raw in SOURCE_ROOTS:
        logger.info(f"  - {src_name:<22} -> {os.path.expanduser(target_raw)}")

    changed: list[Change] = []
    repo_root = find_repo_root()
    issues: list[tuple[str, str, str]] = []
    if repo_root is None:
        with tempfile.TemporaryDirectory(prefix="minube-sync-") as td:
            repo_root = fetch_repo_root(Path(td))
            # keep the temporary directory alive: the extracted checkout lives inside it
            sync_sources(repo_root, changed, apply=not args.dry_run)
            issues = check_container_volumes(repo_root, home, uid, state_dir)
    else:
        sync_sources(repo_root, changed, apply=not args.dry_run)
        issues = check_container_volumes(repo_root, home, uid, state_dir)

    added = [c for c in changed if c.status == "added"]
    modified = [c for c in changed if c.status == "modified"]

    if changed:
        logger.info("")
        logger.info(bold(f"Changes detected: {len(modified)} modified, {len(added)} added"))
        if modified:
            logger.info(dim("  modified:"))
            for c in modified:
                logger.info(f"  ~ {c.host}   (repo: {c.repo_rel})")
        if added:
            logger.info(dim("  added:"))
            for c in added:
                logger.info(f"  + {c.host}   (repo: {c.repo_rel})")
    else:
        logger.info(ok("No drift detected - everything under the managed host paths is in sync."))

    units = unit_names_for(changed)

    if issues:
        logger.info("")
        logger.info(bold("Container volume checks (host directories referenced by Volume= mounts):"))
        for unit, src, resolved in issues:
            logger.error(f"  X {unit}: host directory does not exist: {resolved}   (from Volume={src})")

    if units and not args.dry_run:
        logger.info("")
        prompt = "systemd/quadlet drift detected - reload the systemd user manager and restart the affected services?"
        logger.info(bold(prompt))
        if confirm(prompt):
            results = reload_and_restart(units)
            for unit, running in results:
                if running:
                    logger.info(ok(f"  ✓ service {unit} restarted and is running"))
                else:
                    logger.error(f"  X service {unit} failed to start / is not running")
        elif changed:
            logger.warning("Drift acknowledged but not applied - no services were restarted.")

    logger.info("")
    logger.info(bold("=" * 72))
    if args.dry_run:
        logger.warning("Dry-run mode: no files were written and no services were restarted.")
    logger.info(ok("minube sync finished"))
    logger.info(bold("=" * 72))

    return 0


if __name__ == "__main__":
    try:
        _exit_code = main()
    except Exception as exc:  # noqa: BLE001 - keep failures easy to read for the user
        logger.critical(f"sync aborted: {type(exc).__name__}: {exc}")
        _exit_code = 1
    raise SystemExit(_exit_code)

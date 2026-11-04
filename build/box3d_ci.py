#!/usr/bin/env python3
"""Verified source-archive cache only. Default query is read-only; no build reuse."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

CACHE_VERSION = 1
REPO = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO / "box3d/dependency.json"
DEFAULT_CACHE = REPO / ".box3d-source-archives"


class CacheError(RuntimeError):
    def __init__(self, code, message):
        self.code = code
        super().__init__(message)


def _sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def identity(manifest=DEFAULT_MANIFEST):
    """The unpatched Git archive identity; patches/builds never enter this cache."""
    try:
        data = json.loads(Path(manifest).read_text())
        pin = data["dependencies"]["box3d"]
        if type(data["schema_version"]) is not int or data["schema_version"] != 1:
            raise ValueError("unsupported dependency schema")
        for key, size in [("commit", 40), ("tree", 40), ("git_archive_sha256", 64)]:
            if not isinstance(pin[key], str) or re.fullmatch("[0-9a-f]{" + str(size) + "}", pin[key]) is None:
                raise ValueError("invalid " + key)
        if not isinstance(pin["url"], str) or not pin["url"]:
            raise ValueError("invalid source URL")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise CacheError("INVALID_MANIFEST", str(exc)) from exc
    return {"cache_version": CACHE_VERSION, "dependency": "box3d", "url": pin["url"],
            "commit": pin["commit"], "tree": pin["tree"], "sha256": pin["git_archive_sha256"],
            "key": "box3d-source-v1-" + pin["git_archive_sha256"]}


def _selected(manifest, key):
    value = identity(manifest)
    if key is not None and key != value["key"]:
        raise CacheError("WRONG_KEY", "requested key does not match the current pinned archive")
    return value


def _present(path):
    return path.exists() or path.is_symlink()


def _entry(cache, value):
    return Path(cache).resolve() / "sha256" / value["sha256"]


def _hit(cache, value):
    entry = _entry(cache, value)
    if not _present(entry):
        return None
    if entry.is_symlink() or not entry.is_dir():
        raise CacheError("CORRUPT", "cache entry must be an ordinary immutable directory")
    if {p.name for p in entry.iterdir()} != {"box3d.tar", "identity.json"}:
        raise CacheError("CORRUPT", "cache entry is incomplete or contains non-archive outputs")
    archive, receipt = entry / "box3d.tar", entry / "identity.json"
    if any(p.is_symlink() or not p.is_file() for p in [archive, receipt]):
        raise CacheError("CORRUPT", "cache archive/identity must be ordinary files")
    try:
        recorded = json.loads(receipt.read_text())
    except (ValueError, OSError) as exc:
        raise CacheError("CORRUPT", "cache identity is unreadable") from exc
    if not isinstance(recorded, dict) or type(recorded.get("cache_version")) is not int or recorded.get("cache_version") != CACHE_VERSION:
        raise CacheError("CORRUPT", "unsupported or malformed cache identity")
    if recorded.get("key") != value["key"]:
        raise CacheError("WRONG_KEY", "cached identity key differs from its content-addressed path")
    if recorded != value:
        raise CacheError("WRONG_PIN", "cached URL/commit/tree/archive identity differs from the selected pin")
    if _sha(archive) != value["sha256"]:
        raise CacheError("CORRUPT", "cached archive checksum differs; existing bytes left untouched")
    return archive


def query(cache=DEFAULT_CACHE, manifest=DEFAULT_MANIFEST, key=None):
    """Never creates directories, locks, receipts, downloads or other files."""
    value = _selected(manifest, key)
    archive = _hit(cache, value)
    return {"result": "HIT" if archive is not None else "MISS", "key": value["key"],
            "sha256": value["sha256"], "archive": str(archive) if archive is not None else None}


def _copy_verified(source, destination, expected):
    h = hashlib.sha256()
    with Path(source).open("rb") as incoming, Path(destination).open("xb") as outgoing:
        for block in iter(lambda: incoming.read(1024 * 1024), b""):
            outgoing.write(block)
            h.update(block)
        outgoing.flush()
        os.fsync(outgoing.fileno())
    if h.hexdigest() != expected:
        raise CacheError("ARCHIVE_MISMATCH", "source changed or copied bytes differ from the selected archive SHA")


def store(cache, manifest, archive, key=None):
    """Copy verified source bytes once. Cooperating stores serialize per key."""
    value = _selected(manifest, key)
    archive = Path(archive)
    if archive.is_symlink() or not archive.is_file() or _sha(archive) != value["sha256"]:
        raise CacheError("ARCHIVE_MISMATCH", "store requires the actual pinned ordinary archive file")
    existing = _hit(cache, value)
    if existing is not None:
        return query(cache, manifest, key)
    root = Path(cache).resolve()
    parent = root / "sha256"
    parent.mkdir(parents=True, exist_ok=True)
    locks = root / ".locks"
    locks.mkdir(exist_ok=True)
    lock = locks / value["sha256"]
    try:
        lock.mkdir()
    except FileExistsError as exc:
        raise CacheError("BUSY", "another explicit store owns this archive key; no implicit retry") from exc
    try:
        existing = _hit(cache, value)
        if existing is not None:
            return query(cache, manifest, key)
        with tempfile.TemporaryDirectory(prefix=".archive-", dir=root) as temporary:
            staged = Path(temporary)
            _copy_verified(archive, staged / "box3d.tar", value["sha256"])
            receipt = staged / "identity.json"
            with receipt.open("x") as out:
                out.write(json.dumps(value, sort_keys=True, indent=2) + "\n")
                out.flush()
                os.fsync(out.fileno())
            (staged / "box3d.tar").chmod(0o444)
            receipt.chmod(0o444)
            entry = _entry(cache, value)
            # The key lock protects helper writers; external mutation while a
            # cache command runs is unsupported. Recheck before publication.
            if _present(entry):
                _hit(cache, value)  # rejects corrupt/partial data, never repairs
                return query(cache, manifest, key)
            os.rename(staged, entry)
        result = query(cache, manifest, key)
        result["result"] = "STORED"
        return result
    finally:
        lock.rmdir()


def restore(cache, manifest, native_cache, key=None):
    """Restore only box3d.tar. Every Native job still configures/builds/tests."""
    value = _selected(manifest, key)
    archive = _hit(cache, value)
    if archive is None:
        return {"result": "MISS", "key": value["key"], "sha256": value["sha256"], "archive": None}
    target_dir = Path(native_cache)
    target = target_dir / "box3d.tar"
    if _present(target):
        if target.is_symlink() or not target.is_file() or _sha(target) != value["sha256"]:
            raise CacheError("DESTINATION_CONFLICT", "existing Native archive differs; it was not overwritten")
        return {"result": "HIT", "key": value["key"], "sha256": value["sha256"], "archive": str(target)}
    target_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".archive-restore-", dir=target_dir) as temporary:
        staged = Path(temporary) / "box3d.tar"
        _copy_verified(archive, staged, value["sha256"])
        try:
            os.link(staged, target)  # atomic no-replace publication
        except FileExistsError as exc:
            raise CacheError("DESTINATION_CONFLICT", "destination appeared concurrently; no overwrite") from exc
    return {"result": "RESTORED", "key": value["key"], "sha256": value["sha256"], "archive": str(target)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=["identity", "query", "store", "restore"], default="query")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--key")
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--native-cache", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.action == "identity":
            result = {"result": "IDENTITY", **_selected(args.manifest, args.key)}
        elif args.action == "query":
            result = query(args.cache, args.manifest, args.key)
        elif args.action == "store":
            if args.archive is None:
                parser.error("store requires --archive")
            result = store(args.cache, args.manifest, args.archive, args.key)
        else:
            if args.native_cache is None:
                parser.error("restore requires --native-cache")
            result = restore(args.cache, args.manifest, args.native_cache, args.key)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (CacheError, OSError) as exc:
        print(json.dumps({"result": "REJECTED", "error": getattr(exc, "code", "IO"), "message": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

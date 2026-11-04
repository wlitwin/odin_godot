#!/usr/bin/env python3
"""Bounded offline copies and a pinned existing Trace inspector; no Trace parser."""
import argparse
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time

MAX_FILES = 32  # includes manifest, trace and the two inspector output files
MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_TOTAL_BYTES = 64 * 1024 * 1024
MAX_TRACE_BYTES = 9 * 1024 * 1024
MAX_MANIFEST_BYTES = 256 * 1024
MAX_INSPECTOR_BYTES = 64 * 1024 * 1024
MAX_INSPECTOR_OUTPUT_BYTES = 64 * 1024
INSPECTOR_TIMEOUT = 30
KINDS = ("log", "build", "source", "report", "other")
LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")


class BundleError(Exception):
    def __init__(self, code, message, details=None):
        super().__init__(message)
        self.code, self.details = code, details


def reject(code, message):
    raise BundleError(code, message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def checked_sha(value):
    if not isinstance(value, str) or not SHA.fullmatch(value):
        reject("INVALID_SHA256", "SHA256 must be exactly64 lowercase hex characters")
    return value


def path_arg(value):
    p = Path(value)
    if not p.is_absolute() or ".." in p.parts:
        reject("INVALID_PATH", "paths must be explicit absolute paths without traversal")
    # Canonicalize explicit parent aliases, including macOS /tmp. The selected
    # leaf itself must never be a symlink, including dangling output symlinks.
    p = p.parent.resolve(strict=True) / p.name
    if p.is_symlink():
        reject("SYMLINK", "symlink input/output is forbidden: " + str(p))
    return p


def fingerprint(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def read_regular(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode):
            reject("NOT_REGULAR", "expected regular file: " + str(path))
        if before.st_size > limit:
            reject("FILE_LIMIT", "file exceeds its declared bound: " + str(path))
        data = stream.read(limit + 1)
        after = os.fstat(stream.fileno())
        current = path.lstat()
        if len(data) > limit:
            reject("FILE_LIMIT", "file grew past bound: " + str(path))
        if (fingerprint(before) != fingerprint(after)
                or fingerprint(before) != fingerprint(current)
                or len(data) != before.st_size):
            reject("CHANGED", "file changed while reading: " + str(path))
        return data, fingerprint(before)


def parse_attachment(text):
    try:
        identity, value = text.split("=", 1)
        kind, label = identity.split(":", 1)
    except ValueError:
        reject("INVALID_ATTACHMENT", "expected KIND:LABEL=ABSOLUTE_PATH")
    if kind not in KINDS or not LABEL.fullmatch(label):
        reject("INVALID_ATTACHMENT", "invalid attachment kind or safe label")
    return kind, label, path_arg(value)


def pin_tool(path, expected):
    checked_sha(expected)
    data, stamp = read_regular(path, MAX_INSPECTOR_BYTES)
    if sha(data) != expected:
        reject("INSPECTOR_SHA256", "explicit inspector SHA256 does not match")
    if not os.access(path, os.X_OK):
        reject("INSPECTOR_EXECUTABLE", "inspector is not executable")
    return stamp


def run_inspector(path, expected, trace, cwd):
    before = pin_tool(path, expected)
    argv = [str(path), str(trace)]
    process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, cwd=cwd,
                               env={"LANG": "C", "LC_ALL": "C"}, start_new_session=True)
    output = {"stdout": bytearray(), "stderr": bytearray()}
    deadline = time.monotonic() + INSPECTOR_TIMEOUT
    try:
        with selectors.DefaultSelector() as poll:
            poll.register(process.stdout, selectors.EVENT_READ, "stdout")
            poll.register(process.stderr, selectors.EVENT_READ, "stderr")
            while poll.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    reject("INSPECTOR_TIMEOUT", "inspector exceeded bounded wall timeout")
                for key, _ in poll.select(min(remaining, .1)):
                    chunk = os.read(key.fd, 8192)
                    if not chunk:
                        poll.unregister(key.fileobj)
                        key.fileobj.close()
                        continue
                    target = output[key.data]
                    if len(target) + len(chunk) > MAX_INSPECTOR_OUTPUT_BYTES:
                        reject("INSPECTOR_OUTPUT_LIMIT", "inspector output exceeded bound")
                    target.extend(chunk)
            actual_exit = process.wait(timeout=max(.001, deadline - time.monotonic()))
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        for stream in (process.stdout, process.stderr):
            if not stream.closed:
                stream.close()
    if pin_tool(path, expected) != before:
        reject("CHANGED", "inspector identity changed during execution")
    stdout, stderr = bytes(output["stdout"]), bytes(output["stderr"])
    if actual_exit != 0 or not any(line.startswith(b"BOX3D_TRACE_INSPECT_OK ") for line in stdout.splitlines()):
        raise BundleError("INSPECTOR_REJECTED", "pinned inspector did not certify the Trace roundtrip",
                          {"actual_exit": actual_exit, "stdout": stdout.decode("utf-8", "replace"),
                           "stderr": stderr.decode("utf-8", "replace")})
    return {"path": str(path), "sha256": expected, "argv": argv, "actual_exit": actual_exit}, stdout, stderr


def publish_noreplace(stage, destination):
    """Atomic directory publication, exclusive even if another writer races us."""
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "darwin":
        function = libc.renamex_np
        function.argtypes = (ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint)
        function.restype = ctypes.c_int
        result = function(os.fsencode(stage), os.fsencode(destination), 4)  # RENAME_EXCL
    elif sys.platform.startswith("linux") and hasattr(libc, "renameat2"):
        function = libc.renameat2
        function.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
        function.restype = ctypes.c_int
        result = function(-100, os.fsencode(stage), -100, os.fsencode(destination), 1)  # NOREPLACE
    else:
        reject("ATOMIC_PUBLISH_UNSUPPORTED", "no exclusive atomic directory rename on this platform")
    if result != 0:
        error = ctypes.get_errno()
        if error in (errno.EEXIST, errno.ENOTEMPTY):
            reject("DESTINATION_EXISTS", "refusing to replace existing destination")
        raise OSError(error, os.strerror(error), str(destination))


def write_new(path, data):
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())


def unique_json(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            reject("DUPLICATE", "duplicate JSON key: " + key)
        result[key] = value
    return result


def verify(bundle, manifest_sha256=None):
    bundle = path_arg(bundle)
    if not bundle.is_dir():
        reject("NOT_DIRECTORY", "bundle must be a directory")
    raw, _ = read_regular(bundle / "manifest.json", MAX_MANIFEST_BYTES)
    manifest_hash = sha(raw)
    if manifest_sha256 is not None and checked_sha(manifest_sha256) != manifest_hash:
        reject("MANIFEST_SHA256", "bundle manifest differs from explicit pin")
    manifest = json.loads(raw, object_pairs_hook=unique_json)
    if (not isinstance(manifest, dict) or type(manifest.get("schema")) is not int or manifest["schema"] != 1
            or manifest.get("framework") not in ("kit", "replay")
            or manifest.get("run_verdict") != "NOT_INFERRED"):
        reject("MANIFEST_SCHEMA", "unsupported bundle schema/framework/verdict")
    entries = manifest.get("files")
    if not isinstance(entries, list) or not 3 <= len(entries) <= MAX_FILES - 1:
        reject("FILE_COUNT", "invalid bounded payload count")
    original = manifest.get("collect_inspector", {})
    checked_sha(original.get("sha256"))
    if type(original.get("actual_exit")) is not int or original["actual_exit"] != 0:
        reject("MANIFEST_SCHEMA", "missing original successful tool record")
    expected = {"manifest.json"}
    identities = set()
    total = len(raw)
    for entry in entries:
        if not isinstance(entry, dict):
            reject("MANIFEST_SCHEMA", "file entries must be objects")
        relative, kind, label = entry.get("path"), entry.get("kind"), entry.get("label")
        if not isinstance(relative, str) or "\\" in relative:
            reject("INVALID_PATH", "invalid member path")
        path = PurePosixPath(relative)
        if path.is_absolute() or ".." in path.parts or path.as_posix() != relative:
            reject("INVALID_PATH", "noncanonical or traversing member path")
        if relative in expected or (kind, label) in identities:
            reject("DUPLICATE", "duplicate member identity/path")
        if not isinstance(label, str) or not LABEL.fullmatch(label):
            reject("MANIFEST_SCHEMA", "invalid member label")
        if kind in KINDS:
            valid = relative == "attachments/" + kind + "-" + label
        else:
            valid = (kind, label, relative) in (("trace", "trace", "trace.bin"),
                      ("inspection", "stdout", "inspector.stdout"), ("inspection", "stderr", "inspector.stderr"))
        if not valid:
            reject("INVALID_PATH", "unexpected member path/kind")
        size = entry.get("size")
        if type(size) is not int or not 0 <= size <= MAX_FILE_BYTES:
            reject("FILE_LIMIT", "invalid member byte count")
        if kind == "trace" and size > MAX_TRACE_BYTES:
            reject("FILE_LIMIT", "Trace exceeds existing inspector limit")
        if kind == "inspection" and size > MAX_INSPECTOR_OUTPUT_BYTES:
            reject("FILE_LIMIT", "inspection output exceeds bound")
        expected.add(relative); identities.add((kind, label)); total += size
        if total > MAX_TOTAL_BYTES:
            reject("TOTAL_LIMIT", "bundle exceeds aggregate byte bound")
        checked_sha(entry.get("sha256"))
    if not {("trace", "trace"), ("inspection", "stdout"), ("inspection", "stderr")} <= identities:
        reject("MANIFEST_SCHEMA", "missing Trace or inspector output")
    actual = set()
    for directory, dirs, names in os.walk(bundle, followlinks=False):
        parent = Path(directory)
        for name in dirs:
            candidate = parent / name
            if candidate.is_symlink() or candidate != bundle / "attachments":
                reject("SYMLINK", "unexpected or symlink bundle directory")
        for name in names:
            candidate = parent / name
            if candidate.is_symlink():
                reject("SYMLINK", "symlink bundle member")
            actual.add(candidate.relative_to(bundle).as_posix())
            if len(actual) > MAX_FILES:
                reject("FILE_COUNT", "bundle contains too many files")
    if actual != expected:
        reject("MEMBERS", "missing or unlisted bundle files")
    for entry in entries:
        data, _ = read_regular(bundle / entry["path"], MAX_FILE_BYTES)
        if len(data) != entry["size"] or sha(data) != entry["sha256"]:
            reject("CORRUPT", "member bytes/hash differ: " + entry["path"])
    return {"result": "BUNDLE_VALID", "run_verdict": "NOT_INFERRED", "bundle": str(bundle),
            "manifest_sha256": manifest_hash, "files": len(actual), "bytes": total, "manifest": manifest}


def collect(framework, trace, inspector, inspector_sha256, out, attachments=()):
    if framework not in ("kit", "replay"):
        reject("FRAMEWORK", "framework must be kit or replay")
    trace, inspector, out = path_arg(trace), path_arg(inspector), path_arg(out)
    if out.exists():
        reject("DESTINATION_EXISTS", "destination must be new")
    specs = [("trace", "trace", trace)] + [parse_attachment(x) for x in attachments]
    if len(specs) + 3 > MAX_FILES:
        reject("FILE_COUNT", "too many explicitly selected attachments")
    labels, inodes, sources = set(), set(), []
    stage = Path(tempfile.mkdtemp(prefix="." + out.name + ".staging-", dir=out.parent))
    try:
        (stage / "attachments").mkdir()
        entries, total = [], 0
        for kind, label, source in specs:
            if (kind, label) in labels:
                reject("DUPLICATE", "duplicate attachment label")
            labels.add((kind, label))
            if source == out or out in source.parents:
                reject("INVALID_PATH", "source cannot be within the new destination")
            data, stamp = read_regular(source, min(MAX_FILE_BYTES, MAX_TRACE_BYTES) if kind == "trace" else MAX_FILE_BYTES)
            if stamp[:2] in inodes:
                reject("DUPLICATE", "same source selected more than once")
            inodes.add(stamp[:2]); total += len(data)
            if total > MAX_TOTAL_BYTES:
                reject("TOTAL_LIMIT", "selected copies exceed aggregate bound")
            relative = "trace.bin" if kind == "trace" else "attachments/" + kind + "-" + label
            write_new(stage / relative, data)
            entries.append({"path": relative, "kind": kind, "label": label, "size": len(data),
                            "sha256": sha(data), "source": str(source)})
            sources.append((source, stamp, sha(data)))
        original, stdout, stderr = run_inspector(inspector, inspector_sha256, stage / "trace.bin", stage)
        for label, data in (("stdout", stdout), ("stderr", stderr)):
            relative = "inspector." + label; write_new(stage / relative, data)
            entries.append({"path": relative, "kind": "inspection", "label": label,
                            "size": len(data), "sha256": sha(data), "source": "explicit inspector " + label})
        manifest = {"schema": 1, "framework": framework, "run_verdict": "NOT_INFERRED",
                    "collect_inspector": original, "files": entries}
        raw = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
        if len(raw) > MAX_MANIFEST_BYTES:
            reject("MANIFEST_LIMIT", "manifest exceeds bound")
        write_new(stage / "manifest.json", raw)
        checked = verify(stage, sha(raw))
        for source, stamp, expected in sources:
            data, current = read_regular(source, MAX_FILE_BYTES)
            if current != stamp or sha(data) != expected:
                reject("CHANGED", "original source changed before publication")
        publish_noreplace(stage, out)
        return {"result": "BUNDLE_COLLECTED", "run_verdict": "NOT_INFERRED", "bundle": str(out),
                "manifest_sha256": sha(raw), "files": checked["files"], "bytes": checked["bytes"],
                "collect_inspector": original}
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def inspect(bundle, inspector, inspector_sha256, manifest_sha256=None):
    checked = verify(bundle, manifest_sha256)
    manifest = checked["manifest"]
    trace_entry = next(x for x in manifest["files"] if x["kind"] == "trace")
    data, _ = read_regular(Path(checked["bundle"]) / "trace.bin", MAX_TRACE_BYTES)
    if sha(data) != trace_entry["sha256"]:
        reject("CHANGED", "verified Trace changed before inspection")
    with tempfile.TemporaryDirectory(prefix="box3d-inspect-") as work:
        work = Path(work); copy = work / "trace.bin"; write_new(copy, data)
        current, stdout, stderr = run_inspector(path_arg(inspector), inspector_sha256, copy, work)
        after, _ = read_regular(copy, MAX_TRACE_BYTES)
        if sha(after) != trace_entry["sha256"]:
            reject("CHANGED", "inspector changed its input copy")
    verify(bundle, checked["manifest_sha256"])
    # Architecture-compatible local tool may legitimately differ from collection.
    # Both explicit pins are reported; neither establishes gameplay compatibility.
    return {"result": "TRACE_INSPECTED", "run_verdict": "NOT_INFERRED", "bundle": checked["bundle"],
            "manifest_sha256": checked["manifest_sha256"], "collect_inspector": manifest["collect_inspector"],
            "local_inspector": current, "stdout": stdout.decode("utf-8", "replace"),
            "stderr": stderr.decode("utf-8", "replace")}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest="action", required=True)
    create = actions.add_parser("collect")
    create.add_argument("--framework", required=True, choices=("kit", "replay"))
    create.add_argument("--trace", required=True)
    create.add_argument("--out", required=True)
    create.add_argument("--attachment", action="append", default=[])
    check = actions.add_parser("verify")
    show = actions.add_parser("inspect")
    for sub in (check, show):
        sub.add_argument("--bundle", required=True)
        sub.add_argument("--manifest-sha256")
    for sub in (create, show):
        sub.add_argument("--inspector", required=True)
        sub.add_argument("--inspector-sha256", required=True)
    args = parser.parse_args(argv)
    try:
        if args.action == "collect":
            result = collect(args.framework, args.trace, args.inspector, args.inspector_sha256, args.out, args.attachment)
        elif args.action == "verify":
            result = verify(args.bundle, args.manifest_sha256)
            result.pop("manifest")
        else:
            result = inspect(args.bundle, args.inspector, args.inspector_sha256, args.manifest_sha256)
    except (BundleError, OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        result = {"result": "REJECTED", "run_verdict": "NOT_INFERRED",
                  "error": getattr(error, "code", type(error).__name__), "message": str(error)}
        if getattr(error, "details", None) is not None:
            result["details"] = error.details
        print(json.dumps(result, sort_keys=True))
        return 2
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())

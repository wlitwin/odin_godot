#!/usr/bin/env python3
"""Focused synthetic archive-cache controls. No Native/compiler/VM/network use."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("box3d_archive_cache", ROOT / "build/box3d_ci.py")
cache_api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache_api)


class ArchiveCacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="box3d-cache-pure-")
        self.root = Path(self.temporary.name)
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode="w") as archive:
            content = b"/* synthetic source fixture; not a Native result */\n"
            member = tarfile.TarInfo("src/example.c")
            member.size = len(content)
            member.mtime = 0
            archive.addfile(member, io.BytesIO(content))
        self.payload = data.getvalue()
        self.archive = self.root / "input.tar"
        self.archive.write_bytes(self.payload)
        self.pin = {"url": "https://example.invalid/synthetic-box3d.git", "commit": "1" * 40,
                    "tree": "2" * 40, "git_archive_sha256": hashlib.sha256(self.payload).hexdigest()}
        self.manifest = self.root / "dependency.json"
        self.write_manifest(self.pin)
        self.cache = self.root / "cache"
        self.native = self.root / "native-cache"

    def tearDown(self):
        self.temporary.cleanup()

    def write_manifest(self, pin, schema=1):
        self.manifest.write_text(json.dumps({"schema_version": schema, "dependencies": {"box3d": pin}}))

    def entry(self):
        return self.cache / "sha256" / self.pin["git_archive_sha256"]

    def reject(self, code, call):
        with self.assertRaises(cache_api.CacheError) as error:
            call()
        self.assertEqual(error.exception.code, code)

    def store(self):
        return cache_api.store(self.cache, self.manifest, self.archive)

    def test_identity_and_default_query_are_read_only_miss(self):
        identity = cache_api.identity(self.manifest)
        self.assertEqual(identity["key"], "box3d-source-v1-" + self.pin["git_archive_sha256"])
        before = sorted(self.root.iterdir())
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            status = cache_api.main(["--manifest", str(self.manifest), "--cache", str(self.cache)])
        self.assertEqual(status, 0)
        self.assertEqual(json.loads(stdout.getvalue())["result"], "MISS")
        self.assertEqual(sorted(self.root.iterdir()), before)
        self.assertFalse(self.cache.exists())

    def test_cold_warm_restore_identity_and_source_lifetime(self):
        result = self.store()
        self.assertEqual(result["result"], "STORED")
        entry = self.entry()
        before = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in entry.iterdir()}
        self.assertEqual(self.store()["result"], "HIT")
        self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in entry.iterdir()})
        self.archive.unlink()
        self.assertEqual(cache_api.query(self.cache, self.manifest)["result"], "HIT")
        self.assertEqual(cache_api.restore(self.cache, self.manifest, self.native)["result"], "RESTORED")
        self.assertEqual((self.native / "box3d.tar").read_bytes(), self.payload)
        self.assertEqual(cache_api.restore(self.cache, self.manifest, self.native)["result"], "HIT")
        (self.native / "box3d.tar").write_bytes(b"destination independently modified")
        self.assertEqual((entry / "box3d.tar").read_bytes(), self.payload)
        self.assertEqual(cache_api.query(self.cache, self.manifest)["result"], "HIT")

    def test_wrong_archive_and_wrong_key_reject_without_publication(self):
        self.archive.write_bytes(b"not the pinned archive; no DSO/build-output cache")
        self.reject("ARCHIVE_MISMATCH", self.store)
        self.assertFalse(self.cache.exists())
        self.reject("WRONG_KEY", lambda: cache_api.query(self.cache, self.manifest, "box3d-source-v1-" + "0" * 64))
        self.assertFalse(self.cache.exists())

    def test_same_content_wrong_pin_or_recorded_key_never_remaps(self):
        self.store()
        receipt = self.entry() / "identity.json"
        original = receipt.read_bytes()
        changed = dict(self.pin, commit="3" * 40)
        self.write_manifest(changed)
        self.reject("WRONG_PIN", lambda: cache_api.restore(self.cache, self.manifest, self.native))
        self.assertFalse(self.native.exists())
        self.assertEqual(receipt.read_bytes(), original)
        self.write_manifest(self.pin)
        receipt.chmod(0o644)
        wrong = json.loads(original)
        wrong["key"] = "box3d-source-v1-" + "0" * 64
        receipt.write_text(json.dumps(wrong))
        self.reject("WRONG_KEY", lambda: cache_api.query(self.cache, self.manifest))

    def test_corrupt_archive_is_rejected_and_never_overwritten(self):
        self.store()
        stored = self.entry() / "box3d.tar"
        stored.chmod(0o644)
        stored.write_bytes(b"corrupt cached bytes")
        before = stored.read_bytes()
        self.reject("CORRUPT", lambda: cache_api.query(self.cache, self.manifest))
        self.reject("CORRUPT", self.store)
        self.reject("CORRUPT", lambda: cache_api.restore(self.cache, self.manifest, self.native))
        self.assertEqual(stored.read_bytes(), before)
        self.assertFalse(self.native.exists())

    def test_partial_malformed_or_symlink_entry_is_not_repaired(self):
        entry = self.entry()
        entry.mkdir(parents=True)
        self.reject("CORRUPT", self.store)
        self.assertEqual(list(entry.iterdir()), [])
        entry.rmdir()
        self.store()
        receipt = entry / "identity.json"
        receipt.chmod(0o644)
        receipt.write_text("{broken-json")
        self.reject("CORRUPT", self.store)
        self.assertEqual(receipt.read_text(), "{broken-json")
        shutil.rmtree(entry)
        entry.symlink_to(self.root / "absent", target_is_directory=True)
        self.reject("CORRUPT", lambda: cache_api.query(self.cache, self.manifest))
        self.assertTrue(entry.is_symlink())

    def test_restore_miss_is_read_only_and_destination_conflict_preserved(self):
        self.assertEqual(cache_api.restore(self.cache, self.manifest, self.native)["result"], "MISS")
        self.assertFalse(self.native.exists())
        self.store()
        self.native.mkdir()
        target = self.native / "box3d.tar"
        target.write_bytes(b"wrong existing Native archive")
        self.reject("DESTINATION_CONFLICT", lambda: cache_api.restore(self.cache, self.manifest, self.native))
        self.assertEqual(target.read_bytes(), b"wrong existing Native archive")

    def test_cli_mutations_and_invalid_identity_are_explicit(self):
        for argv, expected in [(["store", "--archive", str(self.archive)], "STORED"),
                               (["restore", "--native-cache", str(self.native)], "RESTORED")]:
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                result = cache_api.main(argv + ["--cache", str(self.cache), "--manifest", str(self.manifest)])
            self.assertEqual(result, 0)
            self.assertEqual(json.loads(output.getvalue())["result"], expected)
        for pin, version in [(dict(self.pin, git_archive_sha256="x" * 64), 1),
                             (dict(self.pin, commit="1"), 1), (self.pin, True), (self.pin, 2)]:
            self.write_manifest(pin, version)
            self.reject("INVALID_MANIFEST", lambda: cache_api.identity(self.manifest))


if __name__ == "__main__":
    unittest.main()

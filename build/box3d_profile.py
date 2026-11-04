#!/usr/bin/env python3
"""Prepare the optional shared Box3D SDK backend in a controlled runtime folder.

The native input is a coherent build-driver output. Standalone archive users do
not call this helper. An existing managed backend is reused without rewriting a
library that an editor may have mapped; changing its build requires an explicit
replacement while the embedding process is stopped.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile


class ProfileError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ProfileError(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inspect_consumer(path, target):
    # SDK consumers import the shared backend. Defining these raw C symbols in
    # an Odin module means an engine copy was embedded, even if ELF interposition
    # happened to route one tested call to the shared image.
    native = target == current_target()
    nm = shutil.which("nm") if native else shutil.which("llvm-nm")
    require(nm is not None, "no target-capable nm is available to verify the SDK shared-library boundary")
    flags = ["-gU"] if target == "macos" and native else ["-g", "--defined-only"]
    result = subprocess.run([nm, *flags, str(path)], capture_output=True, text=True, check=True)
    embedded = [line.split()[-1] for line in result.stdout.splitlines()
                if line.split() and line.split()[-1].lstrip("_").startswith("ogb3_")]
    require(not embedded, "SDK module embeds native Box3D symbols instead of importing the shared backend: " + ", ".join(embedded[:5]))


def prepare_import(project):
    """Declare extensions before first headless startup, without creating docs.

    Godot #111645/#111048 can run a deferred extension-documentation callback
    after editor teardown when an extension is first found during the scan.
    Loading declared extensions at startup avoids that late-discovery path.
    Existing cache entries are preserved; hidden and .gdignore trees are skipped.
    This is explicit SDK bootstrap, not an upstream engine fix.
    """
    project = project.resolve()
    require((project / "project.godot").is_file(), "import preparation needs a Godot project")
    found = []
    for directory, names, files in os.walk(project, followlinks=False):
        current = Path(directory)
        if current != project and ".gdignore" in files:
            names[:] = []
            continue
        names[:] = sorted(name for name in names if not name.startswith("."))
        for name in sorted(files):
            if name.endswith(".gdextension"):
                resource = "res://" + (current / name).relative_to(project).as_posix()
                require("\n" not in resource and "\r" not in resource, "newline in extension resource path")
                found.append(resource)
    require(found, "no extension manifests found for SDK startup preparation")
    cache = project / ".godot"
    cache.mkdir(exist_ok=True)
    path = cache / "extension_list.cfg"
    old = path.read_text().splitlines() if path.exists() else []
    entries = sorted(set(line for line in old + found if line))
    data = "\n".join(entries) + "\n"
    if path.exists() and path.read_text() == data:
        return
    descriptor, temporary = tempfile.mkstemp(prefix=".extension-list-", dir=cache)
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(data)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class Domain(ctypes.Structure):
    _fields_ = [("cookie", ctypes.c_uint64)] + [
        (name, ctypes.c_uint32) for name in
        ("size", "version", "abi_version", "logical_version", "resource_version",
         "recovery_version", "pointer_bits", "endian")
    ] + [("build", ctypes.c_ubyte * 32), ("target", ctypes.c_ubyte * 32)]


def current_target():
    return {"Darwin": "macos", "Linux": "linux", "Windows": "windows"}.get(platform.system())


def query_domain(path):
    library = ctypes.CDLL(str(path))
    get = library.ogb3_domain_contract_get
    get.argtypes = [ctypes.POINTER(Domain)]
    get.restype = ctypes.c_int32
    domain = Domain()
    require(get(ctypes.byref(domain)) == 0, "native domain query failed")
    require(ctypes.sizeof(Domain) == 104 and domain.size == 104,
            "native domain contract layout differs from the SDK")
    require(domain.cookie != 0 and (domain.version, domain.abi_version,
            domain.logical_version, domain.resource_version, domain.recovery_version) == (1, 1, 4, 2, 1),
            "native domain/API/logical/resource/recovery versions differ from the SDK")
    require(domain.pointer_bits == ctypes.sizeof(ctypes.c_void_p) * 8 and domain.endian == 1,
            "native pointer width or byte order differs from the SDK process")
    # The cookie is process-local. Never persist it as build or network identity.
    return {"build": bytes(domain.build).hex(), "target": bytes(domain.target).hex(),
            "versions": [1, 1, 4, 2, 1], "pointer_bits": domain.pointer_bits, "endian": domain.endian}


def native_test_evidence(source, manifest):
    if manifest.get("ctest") == "passed":
        return {"runner": "ctest"}
    require(manifest.get("ctest") == "not_run" and
            manifest.get("test_supervision") == "direct_registered_commands_v1",
            "native input has no passing coherent test result")
    reference = manifest.get("direct_test_report", {})
    report_path = Path(reference.get("path", ""))
    if not report_path.is_absolute():
        report_path = source.parent / report_path
    require(report_path.is_file() and sha(report_path) == reference.get("sha256"),
            "direct Native test report is missing or changed")
    report = json.loads(report_path.read_text())
    required = {"domain_static", "domain_shared", "domain_modules", "motion", "authoring",
                "recovery", "recovery_reference", "recovery_fields", "recovery_lifecycle",
                "api_static", "api_shared", "lifecycle", "upgrade_state_fields"}
    tests = report.get("tests", [])
    require(report.get("result") == "DIRECT_REGISTERED_TEST_COMMANDS_PASS" and
            report.get("actual_ctest_run_pass") is False and
            report.get("source_fence_unchanged") is True and
            report.get("binary_fence_unchanged") is True and
            report.get("actual_passed_commands") == len(required) and len(tests) == len(required) and
            {t.get("name") for t in tests} == required == set(manifest.get("test_names", [])) and
            all(t.get("actual_exit") == 0 for t in tests),
            "direct Native registered test coverage or result is incomplete")
    require(Path(report["build_dir"]).resolve() == source.parent.resolve(),
            "direct Native tests belong to a different build")
    binaries = report.get("binary_sha256_before", {})
    require(binaries and binaries == report.get("binary_sha256_after") and
            binaries.get(source.name) == sha(source),
            "direct Native tests do not bind this shared library")
    for name, digest in binaries.items():
        path = (source.parent / name).resolve()
        require(path.is_relative_to(source.parent.resolve()) and path.is_file() and sha(path) == digest,
                "direct Native test binary changed: " + name)
    inputs = report.get("native_source_inputs", {})
    input_path = Path(inputs.get("path", ""))
    require(input_path.is_file() and sha(input_path) == inputs.get("sha256") and
            json.loads(input_path.read_text()) == manifest["native_sources"],
            "direct Native tests and build manifest use different source inputs")
    registration = report.get("registration", {})
    registered_path = Path(registration.get("path", ""))
    require(registration.get("exit") == 0 and registered_path.is_file() and
            sha(registered_path) == registration.get("sha256"),
            "direct Native test registration is missing or changed")
    registered = json.loads(registered_path.read_text())["tests"]
    require(len(registered) == len(required) and len({t["name"] for t in registered}) == len(required),
            "direct Native test registration is incomplete")
    for actual, selected in zip(tests, registered):
        properties = {p["name"]: p["value"] for p in selected.get("properties", [])}
        require(actual["name"] == selected["name"] and actual["argv"] == selected["command"] and
                actual["properties"] == properties and
                actual["cwd"] == properties.get("WORKING_DIRECTORY", report["build_dir"]),
                "direct Native command differs from its registered test")
        log = Path(actual["log"])
        require(log.is_file() and sha(log) == actual.get("log_sha256"),
                "direct Native test log is missing or changed")
    return {"runner": "direct_registered_commands_v1", "actual_ctest_run_pass": False,
            "report": str(report_path), "sha256": reference["sha256"]}


def native_input(source, repo, target):
    require(source.is_file(), f"shared native input is missing: {source}")
    suffix = {"macos": ".dylib", "linux": ".so", "windows": ".dll"}[target]
    require(source.suffix == suffix, f"{target} profile requires a shared {suffix} input")
    manifest_path = source.parent / "build-manifest.json"
    identity_path = source.parent / "native-domain-identity.txt"
    require(manifest_path.is_file() and identity_path.is_file(),
            "native input needs adjacent build-manifest.json and native-domain-identity.txt")
    manifest = json.loads(manifest_path.read_text())
    test_evidence = native_test_evidence(source, manifest)
    for name, expected in manifest["native_sources"].items():
        path = repo / name
        require(path.is_file() and sha(path) == expected, f"native source differs from its build manifest: {name}")
    archives = [source.parent / "libogb3.a", source.parent / "ogb3.lib"]
    archive = next((p for p in archives if p.is_file()), None)
    require(archive is not None and sha(archive) == manifest["archive_sha256"],
            "native archive differs from the coherent input build")
    lines = identity_path.read_text().splitlines()
    require(len(lines) == 3 and lines[0].startswith("build=") and lines[1].startswith("target="),
            "invalid native domain identity record")
    build, target_hash = lines[0][6:], lines[1][7:]
    require(len(build) == 64 and len(target_hash) == 64 and
            hashlib.sha256(lines[2].encode()).hexdigest() == target_hash,
            "native target identity record checksum differs")
    require(all(c in "0123456789abcdef" for c in build + target_hash), "invalid native identity digest")
    fields = lines[2].split(";")
    expected_system = {"macos": "Darwin", "linux": "Linux", "windows": "Windows"}[target]
    require(len(fields) > 6 and fields[0] == "ogb3-native-target-v1" and fields[4] == expected_system,
            "native input target does not match the requested SDK target")
    info = {"build": build, "target": target_hash,
            "versions": [1, 1, 4, 2, 1], "pointer_bits": int(fields[6]) * 8, "endian": 1}
    native_query = target == current_target() and fields[5].lower() in {
        platform.machine().lower(), "amd64" if platform.machine().lower() == "x86_64" else platform.machine().lower()
    }
    if native_query:
        require(query_domain(source) == info, "actual shared native metadata differs from the recorded build")
    return {"source_library": str(source), "source_library_sha256": sha(source),
            "native_manifest": str(manifest_path), "native_manifest_sha256": sha(manifest_path),
            "native_archive_sha256": manifest["archive_sha256"], "native_sources": manifest["native_sources"],
            "identity_record_sha256": sha(identity_path), "domain": info,
            "target": target, "configuration": manifest["configuration"], "test_evidence": test_evidence,
            "shared_metadata_executed": native_query}


def web_input(source, repo):
    """Verify the explicit static AOT input; runtime admission remains in Core."""
    source, repo = source.resolve(strict=True), repo.resolve(strict=True)
    require(source.name == 'libogb3.a', 'web profile requires the selected wasm32 archive')
    manifest_path = source.parent / 'build-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    target = manifest['target_contract']
    require(manifest['result'] == 'ARCHIVE_BUILT_TESTS_NOT_RUN' and
            manifest['variant'] in ['WebSIMD', 'WebScalar'] and
            manifest['testing_enabled'] is False and manifest['observation_enabled'] is False,
            'web profile needs a production archive from build_box3d_web.py')
    require(target['kind'] == 'emscripten-wasm32' and target['pointer_bits'] == 32 and
            target['endian'] == 'little', 'web archive target is not the admitted wasm32 ABI')
    flags = target['flags']
    require(all(f in flags for f in ['-fPIC', '-pthread', '-UNDEBUG', '-DBOX3D_VALIDATE',
            '-DB3_ENABLE_ASSERT', '-fno-fast-math', '-ffp-contract=off']) and
            not any(f in flags for f in ['-ffast-math', '-Ofast', '-ffp-contract=fast']),
            'web archive weakens FP/assertion/shared-memory policy')
    require(sha(source) == manifest['archive_sha256'], 'web archive hash changed')
    dependency = json.loads((repo / 'box3d/dependency.json').read_text())
    require(dependency == manifest['dependency_manifest'], 'web dependency pin/patch set differs')
    inputs = manifest['source_inputs']
    require(inputs, 'web build has no source inventory')
    for name, digest in inputs.items():
        if not name.startswith('engine/'):
            path = (repo / name).resolve()
            require(path.is_relative_to(repo) and path.is_file() and sha(path) == digest,
                    'web archive source differs: ' + name)
    expected_target = hashlib.sha256(json.dumps(target, sort_keys=True).encode()).hexdigest()
    expected_build = hashlib.sha256(json.dumps(dict(target=expected_target, source=inputs,
        dependency=dependency), sort_keys=True).encode()).hexdigest()
    require(manifest['target'] == expected_target and manifest['build'] == expected_build,
            'web content-derived build/target identity differs')
    # Content-keyed output is CACHE/build/VARIANT/BUILD/libogb3.a. Verify engine
    # inputs against the exact pinned tar and declared patch outputs, as well as
    # the local source graph above. No mutable extracted tree is trusted here.
    archive = source.parents[3] / 'box3d.tar'
    require(archive.is_file() and sha(archive) == dependency['dependencies']['box3d']['git_archive_sha256'],
            'web profile needs its unchanged verified source archive')
    overrides = {}
    for patch in dependency.get('engine_patches', []):
        require(sha(repo / patch['path']) == patch['sha256'], 'web engine patch changed')
        overrides.update(patch['output_files'])
    with tarfile.open(archive) as tar:
        for name, digest in inputs.items():
            if name.startswith('engine/'):
                member = name[7:]
                expected = overrides.get(member)
                if expected is None:
                    expected = hashlib.sha256(tar.extractfile(member).read()).hexdigest()
                require(expected == digest, 'web engine source differs from pin: ' + member)
    return dict(result='VERIFIED_LINK_INPUT_RUNTIME_PENDING', target='web-wasm32',
                source_archive=str(source), source_archive_sha256=sha(source),
                native_manifest=str(manifest_path), native_manifest_sha256=sha(manifest_path),
                build=expected_build, backend_target=expected_target, variant=manifest['variant'],
                versions=[1, 1, 4, 2, 1], pointer_bits=32, endian=1,
                link_flags=manifest['link_flags'],
                scope='Verified one-AOT static link input; no service/runtime/test verdict inferred')


class RuntimeLock:
    def __init__(self, directory):
        self.file = (directory / ".box3d-runtime.lock").open("a+b")

    def __enter__(self):
        if os.name == "nt":
            import msvcrt
            self.file.seek(0)
            self.file.write(b"0")
            self.file.flush()
            msvcrt.locking(self.file.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(self.file, fcntl.LOCK_EX)
        return self

    def __exit__(self, *_):
        self.file.close()


def prepare(source, directory, repo, target, replace=False):
    source, directory, repo = source.resolve(), directory.resolve(), repo.resolve()
    require(all("\n" not in str(p) and "\r" not in str(p) for p in (source, directory, repo)),
            "newlines are unsupported in native profile paths")
    info = native_input(source, repo, target)
    directory.mkdir(parents=True, exist_ok=True)
    leaf = {"macos": "libogb3.dylib", "linux": "libogb3.so", "windows": "ogb3.dll"}[target]
    destination = directory / leaf
    record_path = directory / "box3d-runtime.json"
    require(source != destination, "native build input must be outside the deployment directory")
    with RuntimeLock(directory):
        require(not destination.is_symlink() and not record_path.is_symlink(),
                "managed native deployment cannot replace a symlink")
        if destination.exists() or record_path.exists():
            require(destination.is_file() and record_path.is_file(),
                    "native runtime folder contains an unmanaged or incomplete backend")
            old = json.loads(record_path.read_text())
            require(old.get("schema_version") == 1 and sha(destination) == old.get("deployed_library_sha256"),
                    "managed native runtime changed outside the SDK build")
            if old["domain"] == info["domain"] and old["target"] == target:
                # Keep the exact already-deployed image, including its signature.
                # A project may have moved since the record was written.
                return {**old, "deployed_library": str(destination)}
            require(replace, "native backend build changed; stop Godot and rebuild with BOX3D_REPLACE_RUNTIME=1")
        with tempfile.TemporaryDirectory(prefix=".box3d-deploy-", dir=directory) as temporary:
            staged = Path(temporary) / leaf
            shutil.copyfile(source, staged)
            staged.chmod(0o755)
            if target == "macos":
                require(current_target() == "macos", "macOS shared-library deployment needs install_name_tool/codesign")
                subprocess.run(["install_name_tool", "-id", "@rpath/libogb3.dylib", str(staged)], check=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                subprocess.run(["codesign", "--force", "--sign", "-", str(staged)], check=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            record = {"schema_version": 1, **info, "deployed_library": str(destination),
                      "deployed_library_sha256": sha(staged),
                      "loader_identity": "@rpath/libogb3.dylib" if target == "macos" else leaf}
            staged_record = Path(temporary) / "box3d-runtime.json"
            staged_record.write_text(json.dumps(record, indent=2) + "\n")
            os.replace(staged, destination)
            os.replace(staged_record, record_path)
            return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", type=Path)
    parser.add_argument("--web-archive", type=Path)
    parser.add_argument("--runtime-dir", type=Path)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--target", choices=["macos", "linux", "windows"])
    parser.add_argument("--state", type=Path)
    parser.add_argument("--inspect-consumer", type=Path)
    parser.add_argument("--prepare-import", type=Path)
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    if args.prepare_import:
        prepare_import(args.prepare_import)
        return
    if args.web_archive:
        require(args.repo is not None and args.state is not None,
                'web profile needs --repo and --state')
        args.state.write_text(json.dumps(web_input(args.web_archive, args.repo), indent=2) + '\n')
        return
    require(args.target is not None, "a native profile needs --target")
    if args.inspect_consumer:
        inspect_consumer(args.inspect_consumer, args.target)
        return
    require(all(x is not None for x in (args.native, args.runtime_dir, args.repo, args.state)),
            "preparing a profile needs --native, --runtime-dir, --repo and --state")
    record = prepare(args.native, args.runtime_dir, args.repo, args.target, args.replace)
    args.state.write_text(json.dumps(record, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (ProfileError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Box3D SDK profile: {error}", file=sys.stderr)
        raise SystemExit(1)

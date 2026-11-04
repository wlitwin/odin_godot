#!/usr/bin/env python3
"""Run the selected motion test packages against one explicitly supplied Native archive."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sources():
    roots = ["box3d", "kit/physics", "replay/physics", "tests/box3d_motion/pure",
             "tests/box3d_motion/native_odin", "tests/box3d_motion/frameworks",
             "tests/box3d_authoring"]
    return {str(p.relative_to(ROOT)): sha(p)
            for folder in roots for p in sorted((ROOT / folder).rglob("*"))
            if p.is_file() and p.suffix in {".odin", ".py", ".h", ".c"}
            and "__pycache__" not in p.parts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--native-library", type=Path, required=True)
    parser.add_argument("--odin", required=True)
    parser.add_argument("--suite", action="append",
                        choices=["pure", "native_odin", "frameworks"])
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    library = args.native_library.resolve(strict=True)
    native_before = sha(library)
    compiler_before = sha(args.odin)
    rows = []
    for suite in args.suite or ["pure", "native_odin", "frameworks"]:
        folder = output / suite
        folder.mkdir()
        package = ROOT / "tests/box3d_motion" / suite
        names = [name for path in sorted(package.glob("*.odin"))
                 for name in re.findall(r"@\(test\)\s*(\w+)\s*::", path.read_text())]
        if not names:
            raise RuntimeError("no actual test declarations in " + str(package))
        before = sources()
        (folder / "sources-before.json").write_text(json.dumps(before, sort_keys=True) + "\n")
        argv = [args.odin, "test", str(package), "-collection:godot=" + str(ROOT),
                "-define:ODIN_TEST_THREADS=1", "-define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true",
                "-define:BOX3D_LIBRARY=" + str(library),
                "-define:ODIN_TEST_JSON_REPORT=" + str(folder / "tests.json"),
                "-o:speed", "-debug", "-keep-executable", "-out:" + str(folder / "tests")]
        import platform
        if platform.system() == "Darwin":
            argv += ["-minimum-os-version:15.0", "-extra-linker-flags:-lc++"]
        argv += ["-custom-attribute:" + attribute for attribute in
                 ["gd_method", "gd_connect", "gd_rpc", "gd_command", "gd_tick",
                  "gd_input", "gd_step", "gd_event", "gd_sample", "gd_half", "gd_message"]]
        (folder / "command.json").write_text(json.dumps(argv, indent=2) + "\n")
        error = None
        exit_code = None
        try:
            with (folder / "test.log").open("x") as log:
                exit_code = subprocess.run(argv, cwd=folder, stdout=log,
                                           stderr=subprocess.STDOUT, timeout=300).returncode
        except Exception as exc:
            error = repr(exc)
        after = sources()
        (folder / "sources-after.json").write_text(json.dumps(after, sort_keys=True) + "\n")
        result_file = folder / "tests.json"
        results = json.loads(result_file.read_text()) if result_file.exists() else None
        row = dict(suite=suite, declarations=names, actual_exit=exit_code, error=error,
                   source_fence=before == after, native_archive_sha256=native_before,
                   native_fence=sha(library) == native_before,
                   compiler_sha256=compiler_before, compiler_fence=sha(args.odin) == compiler_before,
                   test_report=results, log_sha256=sha(folder / "test.log"),
                   source_scope="Selected backend, adapters and standalone motion/authoring tests; excludes the separate motion Godot fixture and is not exact compiler import tracing.",
                   scope="Standalone explicit Native linkage; SDK ownership and Godot authoring have separate cases.")
        row["passed"] = (exit_code == 0 and error is None and row["source_fence"]
                         and row["native_fence"] and row["compiler_fence"]
                         and results is not None and results.get("total") == len(names)
                         and results.get("success") == len(names))
        report = folder / "report.json"
        report.write_text(json.dumps(row, indent=2) + "\n")
        rows.append(dict(suite=suite, passed=row["passed"], actual_exit=exit_code,
                         tests=len(names), report=str(report), sha256=sha(report)))
        (output / "report.json").write_text(json.dumps(rows, indent=2) + "\n")
        print(json.dumps(rows[-1]), flush=True)
        if not row["passed"]:
            print((folder / "test.log").read_text()[-8000:], flush=True)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run the native Odin/Box3D rewind corpus and retain raw timing evidence."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile

from verify import parse


ROOT = Path(__file__).resolve().parents[2]
def run_logged(command, path, env=None):
    with path.open("w") as output:
        subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, env=env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", choices=("Debug", "Release", "both"), default="both")
    parser.add_argument("--bodies", type=int, nargs="+", default=[100, 500])
    parser.add_argument("--seeds", type=lambda value: int(value, 0), nargs="+", default=[1, 7, 1234, 0xC001D00D])
    parser.add_argument("--ticks", type=int, default=2400)
    parser.add_argument("--history", type=int, default=128)
    parser.add_argument("--rewind-max", type=int, default=30)
    parser.add_argument("--cache", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--skip-native-build", action="store_true")
    args = parser.parse_args()
    if not all(1 <= value <= 500 for value in args.bodies):
        parser.error("body counts must be between 1 and 500")
    if not all(0 < value <= 0xFFFFFFFF for value in args.seeds):
        parser.error("seeds must be nonzero u32 values")
    if not (1 <= args.rewind_max <= 30 and args.rewind_max + 2 <= args.history <= 1024):
        parser.error("require rewind 1..30 and rewind+2 <= history <= 1024")
    if args.ticks < max(64, 2 * args.rewind_max):
        parser.error("at least 64 ticks are required for rewind/branch coverage")
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix="box3d-bench-"))
    if out.exists() and any(out.iterdir()):
        parser.error(f"output directory must be fresh: {out}")
    out.mkdir(parents=True, exist_ok=True)
    cache = (args.cache or out / "native-cache").resolve()
    configurations = ["Debug", "Release"] if args.config == "both" else [args.config]
    metadata = {
        "platform": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor(),
        "logical_cpus": os.cpu_count(),
        "runtime": os.environ.get("BOX3D_BENCH_RUNTIME", "host"),
        "odin": subprocess.check_output([os.environ.get("ODIN", "odin"), "version"], text=True).strip(),
        "source_revision": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        "working_tree_changes": subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True).splitlines(),
        "dependencies": json.loads((ROOT / "box3d/dependency.json").read_text()),
        "quantiles": "nearest-rank; raw samples retained in per-case logs",
        "load_average_start": os.getloadavg() if hasattr(os, "getloadavg") else None,
    }
    if platform.system() == "Darwin":
        metadata["cpu_model"] = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
    elif Path("/proc/cpuinfo").exists():
        metadata["cpuinfo"] = Path("/proc/cpuinfo").read_text()
    results = []
    for configuration in configurations:
        print(f"Box3D benchmark: {configuration} build", flush=True)
        if not args.skip_native_build:
            run_logged(["bash", str(ROOT / "build/build_box3d.sh"), configuration, str(cache)], out / f"build-{configuration}.log")
        library = cache / "build" / configuration / "libogb3.a"
        if not library.is_file():
            raise RuntimeError(f"native archive missing: {library}")
        binary = out / f"box3d-bench-{configuration.lower()}"
        flags = ["-debug"] if configuration == "Debug" else ["-o:speed"]
        command = [os.environ.get("ODIN", "odin"), "build", str(ROOT / "tests/box3d_bench"),
                   f"-collection:godot={ROOT}", f"-define:BOX3D_LIBRARY={library}", *flags, f"-out:{binary}"]
        run_logged(command, out / f"odin-{configuration}.log")
        build = {
            "configuration": configuration,
            "odin_command": command,
            "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            "archive_sha256": hashlib.sha256(library.read_bytes()).hexdigest(),
        }
        manifest_path = library.parent / "build-manifest.json"
        if not manifest_path.is_file():
            raise RuntimeError("native build manifest is required, including for --skip-native-build")
        native_manifest = json.loads(manifest_path.read_text())
        if native_manifest["archive_sha256"] != build["archive_sha256"]:
            raise RuntimeError("native archive changed since its build manifest; rebuild before benchmarking")
        retained_manifest = out / f"native-manifest-{configuration}.json"
        retained_manifest.write_bytes(manifest_path.read_bytes())
        build["native_manifest"] = retained_manifest.name
        build["native_manifest_sha256"] = hashlib.sha256(retained_manifest.read_bytes()).hexdigest()
        for bodies in args.bodies:
            for seed in args.seeds:
                label = f"{configuration}-{bodies}-{seed}"
                print(f"Box3D benchmark: {label}", flush=True)
                case = out / label
                case.mkdir()
                log_path = case / "run.log"
                run_logged([str(binary), str(bodies), str(seed), str(args.ticks), str(args.history), str(args.rewind_max), str(case)], log_path)
                expected = dict(bodies=bodies, seed=seed, ticks=args.ticks, history=args.history, rewind_max=args.rewind_max)
                result = parse(log_path.read_text(), expected)
                result.update(build)
                result["log"] = str(log_path.relative_to(out))
                result["log_sha256"] = hashlib.sha256(log_path.read_bytes()).hexdigest()
                results.append(result)
                (case / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    metadata["load_average_end"] = os.getloadavg() if hasattr(os, "getloadavg") else None
    report = {"environment": metadata, "cases": results,
              "gate_a_corpus_size": args.bodies == [100, 500] and len(set(args.seeds)) >= 4 and args.ticks >= 2400
              and args.history >= 128 and args.rewind_max == 30 and configurations == ["Debug", "Release"],
              "gate_a_decision": "separate reviewed report required; this runner does not certify the backend"}
    (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"BOX3D_BENCH_OK cases={len(results)} report={out / 'summary.json'}")


if __name__ == "__main__":
    main()

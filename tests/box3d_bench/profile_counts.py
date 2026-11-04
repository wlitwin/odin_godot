#!/usr/bin/env python3
"""Measure workload counters on the benchmark's accepted reference trajectories.

This builds a counts-only entry point from the actual shared fixture source. It
uses the same archives and requires final solver/game digests to match every
completed benchmark case before reporting its body/contact/joint counts.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess


ROOT = Path(__file__).resolve().parents[2]
ENTRY = r'''
foreign import workload_counts COUNTS_LIBRARY
foreign workload_counts {
    ogb3_bench_world_counts :: proc(world: u32, counts: ^u32) -> b3.Status ---
}
main :: proc() {
    assert(len(os.args) == 5)
    bodies, seed, ticks, history := int(number(1)), u32(number(2)), int(number(3)), int(number(4))
    sim := create_simulation(bodies, seed, history); defer check(b3.world_destroy(&sim.world))
    peak: [6]u32
    for _ in 0..<ticks {
        advance(&sim)
        counts: [6]u32
        check(ogb3_bench_world_counts(u32(sim.world), raw_data(counts[:])))
        for count, index in counts {peak[index] = max(peak[index], count)}
    }
    final, status := b3.world_digests(sim.world); check(status)
    fmt.printf("BOX3D_WORKLOAD bodies=%d seed=%d ticks=%d body_peak=%d shape_peak=%d contact_peak=%d joint_peak=%d island_peak=%d moving_tree_height_peak=%d final_solver_digest=%d final_side_digest=%d\n",
        bodies, seed, ticks, peak[0], peak[1], peak[2], peak[3], peak[4], peak[5],
        final.complete_solver_digest, game_digest(&sim.game))
}
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compile_helper(record, source, output, log):
    command = record.get("arguments") or shlex.split(record["command"])
    kept = [command[0]]
    index = 1
    while index < len(command):
        argument = command[index]
        if argument in ("-c", "-o", "-MF", "-MT", "-MQ"):
            index += 2
        elif argument in ("-MD", "-MMD"):
            index += 1
        else:
            kept.append(argument)
            index += 1
    kept.extend(["-c", str(source), "-o", str(output)])
    subprocess.run(kept, cwd=record["directory"], check=True, stdout=log, stderr=subprocess.STDOUT)
    return kept


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    parser.add_argument("--cache", type=Path, required=True)
    args = parser.parse_args()
    summary_path = args.summary.resolve()
    summary = json.loads(summary_path.read_text())
    out = summary_path.parent / "workload-counts"
    out.mkdir()
    cases = []
    builds = {}
    fixture = ROOT / "tests/box3d_bench/main.odin"
    helper = ROOT / "tests/box3d_bench/world_counts.c"
    prefix = fixture.read_text().split("\nmain :: proc()", 1)[0]
    for configuration in dict.fromkeys(case["configuration"] for case in summary["cases"]):
        original = next(case for case in summary["cases"] if case["configuration"] == configuration)
        manifest = json.loads((summary_path.parent / original["native_manifest"]).read_text())
        library = args.cache.resolve() / "build" / configuration / "libogb3.a"
        if digest(library) != original["archive_sha256"]:
            raise RuntimeError("workload profiling requires the exact measured native archive")
        build = out / configuration
        build.mkdir()
        object_path = build / "counts.o"
        archive = build / "counts.a"
        # Reuse the actual recorded engine compiler/precision/ABI flags.
        record = next(command for command in manifest["commands"] if command["file"].endswith("/aabb.c"))
        with (build / "compile-helper.log").open("w") as log:
            command = compile_helper(record, helper, object_path, log)
        subprocess.run(["ar", "rcs", str(archive), str(object_path)], check=True)
        source = build / "fixture"
        source.mkdir()
        entry = ENTRY.replace("COUNTS_LIBRARY", json.dumps("system:" + str(archive)))
        (source / "main.odin").write_text(prefix + "\n" + entry)
        binary = build / "workload-counts"
        flags = ["-debug"] if configuration == "Debug" else ["-o:speed"]
        odin_command = [os.environ.get("ODIN", "odin"), "build", str(source),
                        f"-collection:godot={ROOT}", f"-define:BOX3D_LIBRARY={library}",
                        *flags, f"-out:{binary}"]
        with (build / "compile-odin.log").open("w") as log:
            subprocess.run(odin_command, check=True, stdout=log, stderr=subprocess.STDOUT)
        builds[configuration] = {
            "helper_command": command,
            "odin_command": odin_command,
            "helper_source_sha256": digest(helper),
            "fixture_source_sha256": digest(fixture),
            "generated_source_sha256": digest(source / "main.odin"),
            "binary_sha256": digest(binary),
            "archive_sha256": digest(library),
        }
        for case in summary["cases"]:
            if case["configuration"] != configuration:
                continue
            meta = case["metadata"]
            command = [str(binary), meta["bodies"], meta["seed"], meta["ticks"], meta["history"]]
            log = subprocess.check_output(command, text=True)
            label = f"{configuration}-{meta['bodies']}-{meta['seed']}"
            (out / f"{label}.log").write_text(log)
            lines = [line for line in log.splitlines() if line.startswith("BOX3D_WORKLOAD ")]
            if len(lines) != 1:
                raise RuntimeError("missing/duplicate workload record")
            values = {key: int(value) for key, value in
                      (token.split("=", 1) for token in lines[0].split()[1:])}
            for key in ("bodies", "seed", "ticks"):
                if values[key] != int(meta[key]):
                    raise RuntimeError(f"workload scenario mismatch: {key}")
            for key in ("final_solver_digest", "final_side_digest"):
                if values[key] != case["correctness"][key]:
                    raise RuntimeError(f"workload reference trajectory disagrees: {label} {key}")
            cases.append({"configuration": configuration, **values})
    report = {
        "scope": "accepted reference trajectory; excludes speculative branch-oracle peaks",
        "summary_sha256": digest(summary_path),
        "builds": builds,
        "cases": cases,
    }
    (out / "counts.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"BOX3D_WORKLOAD_OK cases={len(cases)} report={out / 'counts.json'}")


if __name__ == "__main__":
    main()

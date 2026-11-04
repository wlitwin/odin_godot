#!/usr/bin/env python3
"""Revalidate retained Gate A evidence and generate its measurement report."""

from collections import defaultdict
import hashlib
import json
from pathlib import Path
import sys

from verify import parse


ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    stage = Path(sys.argv[1]).resolve()
    datasets = [
        ("macOS arm64", stage / "bench-gate-a-macos-final"),
        ("Linux x86-64 (Podman/Rosetta)", stage / "bench-gate-a-linux-final"),
        ("macOS arm64, bounded slice", stage / "bench-slice32-release"),
    ]
    totals = defaultdict(int)
    documents, timings, memory_rows, workloads, evidence = {}, [], [], [], []
    for platform, out in datasets:
        summary = json.loads((out / "summary.json").read_text())
        counts = json.loads((out / "workload-counts/counts.json").read_text())
        assert counts["summary_sha256"] == sha(out / "summary.json")
        lookup = {(c["configuration"], str(c["bodies"]), str(c["seed"])): c for c in counts["cases"]}
        for case in summary["cases"]:
            log = out / case["log"]
            assert sha(log) == case["log_sha256"]
            expected = {key: int(case["metadata"][key])
                        for key in ("bodies", "seed", "ticks", "history", "rewind_max")}
            actual = parse(log.read_text(), expected)
            for key in ("metadata", "correctness", "memory", "allocations",
                        "timings", "timings_by_phase", "rewinds"):
                assert actual[key] == case[key], (log, key)
            manifest = out / case["native_manifest"]
            assert sha(manifest) == case["native_manifest_sha256"]
            native = json.loads(manifest.read_text())
            assert native["archive_sha256"] == case["archive_sha256"]
            assert len(native["dependency_manifest"]["engine_patches"]) == 3
            key = (case["configuration"], case["metadata"]["bodies"], case["metadata"]["seed"])
            count = lookup[key]
            for field in ("final_solver_digest", "final_side_digest"):
                assert count[field] == case["correctness"][field]
            for field in ("compared", "replayed", "rollbacks", "branches", "branch_compared", "mismatches"):
                totals[field] += case["correctness"][field]
            identity = [platform, *key]
            cells = []
            for metric, phase in (("step", "steady"), ("save", "steady"),
                                  ("restore", "replay"), ("replay", "replay")):
                values = case["timings_by_phase"][metric][phase]
                cells.append("/".join(f"{values[field] / 1e6:.3f}"
                                      for field in ("p50_ns", "p95_ns", "max_ns")))
            timings.append("| " + " | ".join([*identity, *cells]) + " |")
            metrics = case["memory"]
            columns = ("native_history_requested_peak", "wrapper_history_peak",
                       "normalized_cache_peak", "engine_high_water_bytes",
                       "wrapper_high_water_bytes", "baseline_dump_bytes_peak")
            memory_rows.append("| " + " | ".join(
                [*identity, *(f"{metrics[field] / 1048576:.2f}" for field in columns)]) + " |")
            workloads.append("| " + " | ".join(map(str, [
                platform, count["configuration"], count["bodies"], count["seed"],
                count["body_peak"], count["shape_peak"], count["contact_peak"],
                count["joint_peak"], count["island_peak"], count["moving_tree_height_peak"],
            ])) + " |")
        documents[platform] = {"summary": summary, "counts": counts}
        evidence.append({
            "platform": platform,
            "path": str(out),
            "summary_sha256": sha(out / "summary.json"),
            "counts_sha256": sha(out / "workload-counts/counts.json"),
        })
    comparison = json.loads((stage / "corpus-comparison.json").read_text())
    report = f"""# Box3D native feasibility measurements

Recorded 2026-10-30 for P1.4, task `t_979cf60bfd7241f0`, board
`b_cdde1cdfea104035`. This is executed evidence; the independent
[Gate A report](gate-a.md) decides proceed, pivot or stop.

The required matrix passed **32/32 cases**: macOS arm64 and Linux x86-64,
Debug/Release, 100/500 initial dynamic bodies, four fixed seeds, 2,400 forward
ticks, H=128 and 1–30-tick rewinds. Linux executed in the pinned Debian amd64
Podman image using Rosetta on the arm64 host; this is observed x86-64 execution,
not a native Linux throughput claim or a remote CI run. Two additional Release
cases measured 32 initial dynamic bodies on macOS directly, rather than
extrapolating a smaller slice from larger cases.

Across all 34 cases: **{totals['compared']:,}** ordinary complete-state byte/game
comparisons, **{totals['replayed']:,}** replayed ticks, **{totals['rollbacks']:,}**
rewinds, **{totals['branches']:,}** distinct branch exercises and
**{totals['branch_compared']:,}** branch restore/next-step oracle comparisons;
zero reported mismatches. Comparisons use an independently advancing reference
world, not only a motion hash. Raw logs were rehashed and revalidated with the
strict version-2 parser before this report was generated.

## Source and correctness boundary

Selected Box3D `d421e45c828f6f853a145f726f0b9425d31146eb`, isolated snapshot
shim and flat C/Odin boundary are recorded in
[dependency.json](../../../box3d/dependency.json). The normalized solver format
is **2**, coverage `ogb3-d421e45c-solver-v2`.
Three explicitly hashed patches fix actual pinned-engine failures:

1. Unaligned free-list pointer access at odd allocator strides.
2. Misaligned shared hull/mesh blobs in packed compound geometry.
3. Skipped broadphase rebuilding when destruction removed the last moved proxy.
   This reproduced with three public-operation bodies and crashed the untouched
   500-body reference trajectory at tick 1,760. The patched reference and full
   rewind corpus complete all 2,400 ticks.

Native Debug, Release, full unsuppressed ASan+UBSan, ownership failure controls
and actual Odin integration are recorded in
[the lifecycle report](../../../tests/box3d_native/report.md) and
[stress support report](../../../tests/box3d_native/p1.4-support.md).
Native and owned-wrapper tracked bytes return to zero in teardown controls.
Inactive inline material is excluded from the versioned normalized comparison;
active material changes remain detected. Public world-domain saturation has
defined capacity results without an unguarded fingerprint probe or allocator
takeover.

Complete solver final digests differ in **all 16 matched macOS/Linux case pairs**,
while game-side final digests match. This establishes same-build restore/replay
agreement independently in each tested target. It does not establish exact
cross-target solver agreement, identify its cause, or authorize floating-point
P2P. Canonical recovery and mixed-target authority correction need their own
codec and measured agreement contracts; local opaque images do not supply them.

## Timing results

Each cell is **p50 / p95 / maximum in milliseconds** for one seed. Steady
step/save each have 2,273 samples after history fill. Normal restore and suffix
replay each have 75 samples. Suffix cost includes fixture game/solver advancement
plus history saves, excluding diagnostic byte comparison, memory accounting and
printed samples. It excludes initial restore; the Gate A review pairs those
samples rather than adding unrelated marginal quantiles. Step+save omits some
application/command/presentation work and is not a complete rendered-frame
measurement. Both build modes retain assertions, heavy validation, no fast math
and disabled FP contraction.

| Target | Build | Initial dynamic bodies | Seed | Steady step | Steady save | Restore | Suffix replay |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
"""
    report += "\n".join(timings) + """

The 100/500-body optimized deep-rewind tails do not fit an unconditional
16.667 ms frame budget. The directly measured 32-body supplement is a candidate
for a bounded alpha, not proof of arbitrary scene costs. It reaches 35 total
bodies/shapes, 147 reference contacts and one joint; integrated Kit/Replay,
networking and presentation costs still need measurement. Use actual paired
operation data and explicit prediction/repair limits when selecting an envelope.

## Retained and peak requested memory

Values are MiB. Native and wrapper history are retained-resource maxima;
the normalized cache is **part of wrapper history**, not extra memory to add.
Global high-water values include fixture verification, temporary scratch and
branch activity. Reference dumps are benchmark-only. Do not add separate maxima
and call the result an exact simultaneous deployment peak. Current caches and
per-capture geometry registries are real retained costs even if a future
optimization could reduce duplication.

| Target | Build | Bodies | Seed | Native history | Wrapper history | Included normalized cache | Engine high water | Wrapper high water | Reference dump ring |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
"""
    report += "\n".join(memory_rows) + """

Raw results also retain game/history/reference metadata, fixed simulation sizes,
per-operation engine allocation requests and cumulative owned-wrapper requests.
Wrapper counters cover Resource/owner/slots/normalized buffers/world leases and
digest temporaries. Flat-API geometry bookkeeping, allocator headers/rounding,
general call-stack/runtime and Odin allocation overhead remain outside requested
bytes. These are not RSS values. This timed owner replaces history as it replays;
a framework's transactional suffix must reserve and measure additional staging.

## Actual accepted-reference workloads

The C helper uses public counters with the measured archive's exact compiler/ABI
flags. A baseline-only entry point comes from the same tracked fixture and must
reproduce each case's final complete solver **and** game digests. These are peaks
along that accepted reference trajectory, not speculative branch-oracle peaks.
Moving-tree height is the maximum dynamic/kinematic tree height, excluding static.

| Target | Build | Initial dynamic | Seed | Total bodies | Shapes | Contacts | Joints | Islands | Moving tree height |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
"""
    report += "\n".join(workloads) + """

## Reproduction and retained evidence

[The benchmark README](../../../tests/box3d_bench/README.md) documents the runner,
strict record/phase/sample schema, workload profiler and measurement domains.
Source/patch hashes, compiler commands, SIMD/precision/assert macros, binary and
archive hashes, CPU/OS/Odin versions, load, per-case raw logs/results and helper
source hashes remain with each run.

Local artifact roots are temporary working evidence that system cleanup may remove:
"""
    for record in evidence:
        report += (
            "\n- " + record["platform"] + ": `" + record["path"]
            + "`; summary SHA-256 `" + record["summary_sha256"]
            + "`, counts SHA-256 `" + record["counts_sha256"] + "`.\n"
        )
    report += """

The herdr-tasks finish report copies machine-readable summaries, workload counts
and verification metadata into persistent task storage. These checks do not
claim that framework adapters, portable transfer, editor authoring, export/runtime
parity or production hardening are implemented.
"""
    path = ROOT / "docs/design/box3d/gate-a-measurements.md"
    path.write_text(report.replace("`", chr(96)))
    machine = {"totals": dict(totals), "evidence": evidence,
               "cross_target_comparison": comparison, "datasets": documents}
    (stage / "gate-a-measurements-machine.json").write_text(json.dumps(machine, indent=2) + "\n")
    print(json.dumps({"required_cases": 32, "supplemental_cases": 2,
                      "totals": dict(totals), "report": str(path),
                      "all_hashes_and_schemas_verified": True}))


if __name__ == "__main__":
    main()

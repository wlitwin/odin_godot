"""Strict validation of the Box3D benchmark's structured stdout records.

The runner retains the raw log. This module cross-checks its declared corpus and
sample accounting; successful parsing is not independent proof of solver work.
"""

from collections import Counter
import re


PREFIX = "BOX3D_BENCH_"
U64_MAX = (1 << 64) - 1
I64_MAX = (1 << 63) - 1
DUMP_VERSION = 3
COVERAGE_ID = "ogb3-d421e45c-solver-v3"
# Historical v2 Gate A runs remain valid evidence for their recorded build.
# Formats are not interchangeable: v3 additionally covers pending end queues.
SUPPORTED_COVERAGE = {
    2: "ogb3-d421e45c-solver-v2",
    3: COVERAGE_ID,
}
METRICS = frozenset({"step", "save", "restore", "replay", "checked_rewind", "dump"})
PHASES = frozenset({"initial", "fill", "steady", "replay", "branch"})
EXPECTED_FIELDS = frozenset({"bodies", "seed", "ticks", "history", "rewind_max"})
SCHEMAS = {
    "META": EXPECTED_FIELDS | {"hz", "substeps", "dump_version", "coverage"},
    "SAMPLE": frozenset({"metric", "ns", "phase"}),
    "REWIND": frozenset({"tick", "depth", "branch"}),
    "CHECK": frozenset({
        "compared", "rollbacks", "replayed", "branches", "mismatches",
        "min_depth", "max_depth", "branch_compared", "final_solver_digest",
        "final_side_digest",
    }),
    "MEMORY": frozenset({
        "snapshot_used_peak", "snapshot_capacity_peak", "geometry_bytes_sum_peak",
        "baseline_dump_bytes_peak", "side_history_bytes", "engine_live_bytes",
        "engine_high_water_bytes", "native_history_requested_peak",
        "wrapper_history_peak", "normalized_cache_peak", "wrapper_live_bytes",
        "wrapper_high_water_bytes", "history_metadata_bytes",
        "reference_metadata_bytes", "fixed_simulation_bytes",
    }),
    "ALLOCATIONS": frozenset({
        "engine_total_calls", "engine_total_bytes", "save_calls", "restore_calls",
        "step_calls", "wrapper_total_calls", "wrapper_total_bytes",
    }),
    "DONE": frozenset({"ok"}),
}
SINGLE_RECORDS = frozenset({"META", "CHECK", "MEMORY", "ALLOCATIONS", "DONE"})


def _uint(value, label, maximum=U64_MAX):
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]*", value):
        raise ValueError(f"{label} must be an unsigned decimal integer")
    number = int(value)
    if number > maximum:
        raise ValueError(f"{label} exceeds {maximum}")
    return number


def _expected(values):
    if set(values) != EXPECTED_FIELDS:
        raise ValueError("expected must specify bodies, seed, ticks, history, rewind_max")
    if any(type(value) is not int for value in values.values()):
        raise ValueError("expected corpus values must be integers")
    if not 1 <= values["bodies"] <= 500 or not 1 <= values["seed"] <= 0xFFFFFFFF:
        raise ValueError("expected bodies/seed are outside the supported corpus")
    if not 64 <= values["ticks"] <= I64_MAX:
        raise ValueError("expected ticks must be at least 64 and fit native int64")
    if not 1 <= values["rewind_max"] <= 30:
        raise ValueError("expected rewind_max must be 1..30")
    if not values["rewind_max"] + 2 <= values["history"] <= 1024:
        raise ValueError("expected history must be rewind_max+2..1024")


def _row(line, line_number):
    tokens = line.split()
    kind = tokens[0][len(PREFIX):]
    if kind not in SCHEMAS:
        raise ValueError(f"line {line_number}: unknown record {kind!r}")
    row = {}
    for item in tokens[1:]:
        if item.count("=") != 1:
            raise ValueError(f"line {line_number}: malformed field {item!r}")
        key, value = item.split("=", 1)
        if key in row:
            raise ValueError(f"line {line_number}: duplicate {kind} field {key!r}")
        row[key] = value
    if set(row) != SCHEMAS[kind]:
        missing = sorted(SCHEMAS[kind] - row.keys())
        extra = sorted(row.keys() - SCHEMAS[kind])
        raise ValueError(f"line {line_number}: {kind} schema missing={missing} extra={extra}")
    return kind, row


def _quantiles(values):
    ordered = sorted(values)
    count = len(ordered)
    # Integer nearest rank: ceil(n*p/100), using a one-based rank.
    return {
        "samples": count,
        "p50_ns": ordered[(count * 50 + 99) // 100 - 1],
        "p95_ns": ordered[(count * 95 + 99) // 100 - 1],
        "max_ns": ordered[-1],
    }


def parse(log, expected):
    """Validate one finished run and return aggregate and per-phase statistics.

    ``timings_by_phase[metric][phase]`` contains only nonempty phase buckets.
    Metadata retains the emitted strings for compatibility with the runner;
    correctness, allocation, memory and rewind fields are validated integers.
    """
    _expected(expected)
    records = {}
    samples = {metric: [] for metric in METRICS}
    phased = {metric: {} for metric in METRICS}
    rewinds = []
    done = False
    for line_number, line in enumerate(log.splitlines(), 1):
        if not line.startswith(PREFIX):
            continue
        if done:
            raise ValueError(f"line {line_number}: benchmark record after DONE")
        kind, row = _row(line, line_number)
        if not records and kind != "META":
            raise ValueError("META must be the first benchmark record")
        if kind in SINGLE_RECORDS:
            if kind in records:
                raise ValueError(f"duplicate {kind} record")
            records[kind] = row
            done = kind == "DONE"
        elif kind == "REWIND":
            rewinds.append({key: _uint(value, f"REWIND.{key}") for key, value in row.items()})
        else:
            metric, phase = row["metric"], row["phase"]
            if metric not in METRICS or phase not in PHASES:
                raise ValueError(f"line {line_number}: unknown timing metric/phase")
            value = _uint(row["ns"], "SAMPLE.ns", I64_MAX)
            samples[metric].append(value)
            phased[metric].setdefault(phase, []).append(value)

    if set(records) != SINGLE_RECORDS:
        raise ValueError(f"missing records: {sorted(SINGLE_RECORDS - records.keys())}")
    if records["DONE"]["ok"] != "1":
        raise ValueError("corpus did not finish successfully")
    meta = records["META"]
    for key, wanted in {**expected, "hz": 60, "substeps": 4}.items():
        if _uint(meta[key], f"META.{key}") != wanted:
            raise ValueError(f"corpus metadata disagrees: {key}")
    dump_version = _uint(meta["dump_version"], "META.dump_version")
    if dump_version not in SUPPORTED_COVERAGE or meta["coverage"] != SUPPORTED_COVERAGE[dump_version]:
        raise ValueError("unsupported normalized solver coverage")

    check = {key: _uint(value, f"CHECK.{key}") for key, value in records["CHECK"].items()}
    count = expected["ticks"] // 32
    branches = (count + 3) // 4
    if len(rewinds) != count or check["rollbacks"] != count:
        raise ValueError("rewind record/count must equal floor(ticks/32)")
    for index, rewind in enumerate(rewinds):
        if rewind["tick"] != (index + 1) * 32:
            raise ValueError("rewind ticks must follow the 32-tick schedule")
        if not 1 <= rewind["depth"] <= min(expected["rewind_max"], rewind["tick"]):
            raise ValueError("rewind depth outside requested bounds")
        if rewind["branch"] != int(index % 4 == 0):
            raise ValueError("branch flag must be 0/1 on every fourth rewind, starting with the first")
    depths = [rewind["depth"] for rewind in rewinds]
    if min(depths) != 1 or max(depths) != expected["rewind_max"]:
        raise ValueError("rewind records did not cover both requested depth endpoints")
    if check["min_depth"] != min(depths) or check["max_depth"] != max(depths):
        raise ValueError("CHECK rewind endpoints disagree with REWIND records")
    replayed = sum(depths)
    if check["replayed"] != replayed:
        raise ValueError("replayed count must equal the sum of rewind depths")
    if check["branches"] != branches or check["branch_compared"] != 2 * branches:
        raise ValueError("branch oracle comparison counts are incomplete")
    compared = 1 + expected["ticks"] + replayed
    if check["mismatches"] != 0 or check["compared"] != compared:
        raise ValueError("comparison count must include tick zero, every forward tick and every replayed tick")

    fill = min(expected["ticks"], expected["history"] - 1)
    steady = expected["ticks"] - fill
    phase_counts = {
        "step": {"fill": fill, "steady": steady},
        "save": {"initial": 1, "fill": fill, "steady": steady, "replay": replayed},
        "dump": {"initial": 1, "fill": fill, "steady": steady, "replay": replayed},
        "restore": {"replay": count, "branch": 2 * branches},
        "replay": {"replay": count},
        "checked_rewind": {"branch": branches, "replay": count - branches},
    }
    for metric in sorted(METRICS):
        actual = Counter({phase: len(values) for phase, values in phased[metric].items()})
        wanted = Counter({phase: number for phase, number in phase_counts[metric].items() if number})
        if actual != wanted:
            raise ValueError(f"{metric} phase/sample counts disagree: actual={dict(actual)} expected={dict(wanted)}")

    memory = {key: _uint(value, f"MEMORY.{key}") for key, value in records["MEMORY"].items()}
    allocations = {key: _uint(value, f"ALLOCATIONS.{key}") for key, value in records["ALLOCATIONS"].items()}
    for owner in ("engine", "wrapper"):
        if memory[f"{owner}_live_bytes"] > memory[f"{owner}_high_water_bytes"]:
            raise ValueError(f"{owner} live bytes exceed high water")
        if memory[f"{owner}_high_water_bytes"] > allocations[f"{owner}_total_bytes"]:
            raise ValueError(f"{owner} high water exceeds cumulative allocation bytes")
        if (allocations[f"{owner}_total_calls"] == 0) != (allocations[f"{owner}_total_bytes"] == 0):
            raise ValueError(f"{owner} allocation calls/bytes disagree on zero allocation")
    if memory["snapshot_used_peak"] > memory["snapshot_capacity_peak"]:
        raise ValueError("snapshot used bytes exceed capacity")
    if memory["normalized_cache_peak"] > memory["wrapper_history_peak"]:
        raise ValueError("retained normalized bytes exceed their wrapper storage")
    if sum(allocations[key] for key in ("save_calls", "restore_calls", "step_calls")) > allocations["engine_total_calls"]:
        raise ValueError("per-operation allocation calls exceed engine total")

    return {
        "metadata": meta,
        "correctness": check,
        "memory": memory,
        "allocations": allocations,
        "timings": {metric: _quantiles(samples[metric]) for metric in sorted(METRICS)},
        "timings_by_phase": {
            metric: {phase: _quantiles(values) for phase, values in sorted(phased[metric].items())}
            for metric in sorted(METRICS)
        },
        "rewinds": rewinds,
    }

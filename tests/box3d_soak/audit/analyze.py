#!/usr/bin/env python3
"""Validate whole-call records and retain every raw sample; never runs a probe."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import sys

SHARED = Path(__file__).resolve().parents[1] / "shared"
sys.path.insert(0, str(SHARED))
import records as r

MAX_LINE = 1024 * 1024


def sha_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""): h.update(data)
    return h.hexdigest()


def check_provenance(meta, artifact_map, source_root):
    if artifact_map is None: return dict(verified=False, reason="artifact/source map not supplied")
    mapping = json.loads(Path(artifact_map).read_text())
    identity = meta["identity"]
    manifest_path = Path(mapping["source_manifest"])
    r.require(sha_file(manifest_path) == identity["source_manifest_sha256"], "source manifest SHA mismatch")
    manifest = json.loads(manifest_path.read_text())
    r.require(isinstance(manifest, dict), "source manifest must map paths to hashes")
    for name in ("core_binary", "script_binary", "native_binary"):
        expected = identity[name + "_sha256"]
        if expected is None: continue
        r.require(sha_file(Path(mapping[name])) == expected, name + " SHA mismatch")
    for source in meta["boundary"]["source_refs"]:
        r.require(manifest.get(source["path"]) == source["sha256"], "boundary source absent/different in manifest")
        r.require(sha_file(Path(source_root) / source["path"]) == source["sha256"], "current boundary source differs")
    required_records=("compiled_build_record","runtime_observations")
    if not all(key in mapping for key in required_records):
        return dict(verified=False, reason="binary/source hashes checked, but compiled-build/runtime observation records missing",
                    artifact_map=str(Path(artifact_map).resolve()), artifact_map_sha256=sha_file(artifact_map))
    build=json.loads(Path(mapping["compiled_build_record"]).read_text())
    r.require(build.get("exit_code")==0 and build.get("source_fence_unchanged") is True,"compiled build record failed/unfenced")
    r.require(build.get("source_manifest_sha256")==identity["source_manifest_sha256"],"compiled source manifest mismatch")
    for name in ("core_binary_sha256","script_binary_sha256","native_binary_sha256"):
        r.require(build.get(name)==identity[name],"compiled artifact differs: "+name)
    observed=json.loads(Path(mapping["runtime_observations"]).read_text())
    r.require(all(type(observed.get("execution",{}).get(k)) is type(v) and observed["execution"][k]==v for k,v in meta["execution"].items()),"runtime image/Core/ownership observation differs")
    for name in ("os","arch","configuration","godot","native_build_sha256","native_target_sha256"):
        r.require(observed.get("identity",{}).get(name)==identity[name],"runtime identity differs: "+name)
    r.require(observed.get("image_census_observed") is True,"native_images label is not an observed census")
    return dict(verified=True, artifact_map=str(Path(artifact_map).resolve()),
                artifact_map_sha256=sha_file(artifact_map), source_manifest=str(manifest_path.resolve()),
                compiled_build_record_sha256=sha_file(mapping["compiled_build_record"]),
                runtime_observations_sha256=sha_file(mapping["runtime_observations"]),
                scope="files/records bound; actual observation and timed-work semantics also require source audit")



def statistics(db, table, where="", parameters=()):
    count, smallest, largest = db.execute(f"SELECT count(*),min(ns),max(ns) FROM {table} {where}", parameters).fetchone()
    if not count: return dict(count=0, raw_ns=[], p50_ns=None, p95_ns=None, max_ns=None)
    def percentile(percent):
        offset = max(0, (count * percent + 99) // 100 - 1)
        return db.execute(f"SELECT ns FROM {table} {where} ORDER BY ns LIMIT 1 OFFSET ?", (*parameters, offset)).fetchone()[0]
    raw = [row[0] for row in db.execute(f"SELECT ns FROM {table} {where} ORDER BY rowid", parameters)] if count <= 2048 else None
    return dict(count=count, raw_ns=raw, raw_location="samples.jsonl and raw.sqlite (all rows)",
                min_ns=smallest, p50_ns=percentile(50), p95_ns=percentile(95), max_ns=largest,
                percentile_method="nearest rank; no sample/outlier removal")


def analyze(path, output, artifact_map=None, source_root=None, max_bytes=512 * 1024 * 1024):
    path, output = Path(path).resolve(), Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = dict(schema=1, analysis="whole-call-v1", result="FAIL", cpu_candidate_acceptance="INCOMPLETE",
                  gate_b_acceptance="NOT_ESTABLISHED_BY_ANALYZER", input=str(path), samples_retained=0,
                  timing_jobs_started=False, outliers_discarded=0, phase_sum_used_as_whole=False)
    db = sqlite3.connect(output / "raw.sqlite")
    db.execute("PRAGMA journal_mode=DELETE")
    db.execute("CREATE TABLE samples(seq INTEGER PRIMARY KEY, operation TEXT, ns INTEGER, raw TEXT, findings TEXT)")
    db.execute("CREATE TABLE phases(sample_seq INTEGER, name TEXT, clock_domain TEXT, ns INTEGER, raw TEXT)")
    meta = result = None
    counts = dict(normal=0, repair8=0)
    failure_count = 0
    try:
        r.require(path.stat().st_size <= max_bytes, "input exceeds declared byte budget; no truncation")
        report["input_sha256"] = sha_file(path)
        with path.open("rb") as stream, (output / "samples.jsonl").open("wb") as raw:
            line_no = 0
            while True:
                line = stream.readline(MAX_LINE + 1)
                if not line: break
                line_no += 1
                r.require(len(line) <= MAX_LINE, "record line bound exceeded")
                record = r.strict_json(line)
                event = record.get("event")
                r.require(result is None, "record follows terminal RESULT")
                if meta is None:
                    meta = r.validate_meta(record)
                    report["meta"] = meta
                    report["boundary_findings"] = r.boundary_findings(meta)
                    report["provenance"] = check_provenance(meta, artifact_map, source_root or Path.cwd())
                elif event == "GATE_B_SAMPLE":
                    seq = report["samples_retained"] + 1
                    raw.write(line if line.endswith(b"\n") else line + b"\n")
                    r.validate_sample(meta, record, seq)
                    findings = r.sample_findings(record, meta)
                    failure_count += bool(findings)
                    db.execute("INSERT INTO samples VALUES(?,?,?,?,?)", (seq, record["operation"], record["whole_ns"], line.decode(), json.dumps(findings)))
                    for phase in record["phases"]:
                        db.execute("INSERT INTO phases VALUES(?,?,?,?,?)", (seq, phase["name"], phase["clock_domain"], phase["duration_ns"], json.dumps(phase)))
                    report["samples_retained"] = seq
                    counts[record["operation"]] += 1
                elif event == "GATE_B_RESULT":
                    result = r.validate_result(meta, record, report["samples_retained"])
                    report["terminal"] = result
                else:
                    raise r.RecordError("unexpected/interleaved event " + str(event))
        r.require(meta is not None and result is not None, "META/RESULT missing")
        db.commit()
        report["operation_findings_count"] = failure_count
        report["result_findings"] = r.result_findings(result)
        report["sample_plan_matches"] = counts == meta["sample_plan"]
        report["counts"] = counts
        report["statistics"] = {}
        over = 0
        for op in counts:
            values = statistics(db, "samples", "WHERE operation=?", (op,))
            values["ceiling_ns"] = r.CEILING_NS
            values["over_ceiling_count"] = db.execute("SELECT count(*) FROM samples WHERE operation=? AND ns>?", (op, r.CEILING_NS)).fetchone()[0]
            values["ceiling_result"] = "NOT_MEASURED" if not values["count"] else ("FAIL" if values["over_ceiling_count"] else "PASS")
            over += values["over_ceiling_count"]
            report["statistics"][op] = values
        report["observed_whole_ceiling_result"] = "FAIL" if over else ("PASS" if report["samples_retained"] else "NOT_MEASURED")
        report["phase_statistics"] = []
        for name, domain in db.execute("SELECT DISTINCT name,clock_domain FROM phases ORDER BY name,clock_domain"):
            values = statistics(db, "phases", "WHERE name=? AND clock_domain=?", (name, domain))
            report["phase_statistics"].append(dict(name=name, clock_domain=domain, **values))
        correctness = not failure_count and not report["result_findings"] and report["sample_plan_matches"]
        if meta["timing_mode"] == "functional_only":
            r.require(report["samples_retained"] == 0, "functional-only timing fabricated")
            report["cpu_candidate_acceptance"] = "NOT_MEASURED"
            report["result"] = "FUNCTIONAL_PASS" if correctness and result["functional_operations"] > 0 else "INCOMPLETE"
        else:
            report["result"] = "RECORDS_VALID" if correctness else "FAIL"
            mode = meta["execution"]
            diagnostic = mode["core"] != "actual_godot_core" or mode["ownership"] != "sdk_meter" or meta["boundary"]["id"] != "core_public_ingress_v1"
            if diagnostic:
                cpu = "DIAGNOSTIC_ONLY"
            elif not correctness:
                cpu = "FAIL"
            elif report["boundary_findings"] or not report["provenance"]["verified"] or not all(counts.values()):
                cpu = "INCOMPLETE"
            elif over:
                cpu = "FAIL"
            else:
                cpu = "PASS"
            report["cpu_candidate_acceptance"] = cpu
    except Exception as error:
        report["error"] = repr(error)
    finally:
        db.commit(); db.close()
        report["raw_database"] = dict(path=str(output / "raw.sqlite"), sha256=sha_file(output / "raw.sqlite"))
        samples = output / "samples.jsonl"
        if samples.exists(): report["raw_samples"] = dict(path=str(samples), sha256=sha_file(samples), bytes=samples.stat().st_size)
        report["analyzer_sources"] = {str(p): sha_file(p) for p in (Path(__file__).resolve(), SHARED / "records.py")}
        (output / "report.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--artifact-map", type=Path)
    parser.add_argument("--source-root", type=Path, default=Path.cwd())
    parser.add_argument("--max-bytes", type=int, default=512 * 1024 * 1024)
    args = parser.parse_args()
    report = analyze(args.input, args.out, args.artifact_map, args.source_root, args.max_bytes)
    print(json.dumps({"result": report["result"], "cpu_candidate_acceptance": report["cpu_candidate_acceptance"], "report": str(args.out / "report.json")}))
    return 0 if report["result"] in ("RECORDS_VALID", "FUNCTIONAL_PASS") else 1


if __name__ == "__main__": raise SystemExit(main())

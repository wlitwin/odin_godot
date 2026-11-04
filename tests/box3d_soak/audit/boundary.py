#!/usr/bin/env python3
"""Read-only boundary/provenance check; does not launch or time a probe."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'shared'))
import records
from analyze import check_provenance


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('meta',type=Path);p.add_argument('--artifact-map',type=Path)
    p.add_argument('--source-root',type=Path,default=Path.cwd())
    a=p.parse_args();meta=records.validate_meta(records.strict_json(a.meta.read_bytes()))
    findings=records.boundary_findings(meta)
    proof=check_provenance(meta,a.artifact_map,a.source_root)
    print(json.dumps(dict(boundary_findings=findings,provenance=proof,
        cpu_acceptance='NOT_A_TIMING_RUN',gate_b_acceptance='NOT_ESTABLISHED')))
    return 0 if not findings and proof['verified'] else 1


if __name__=='__main__':raise SystemExit(main())

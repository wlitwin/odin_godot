#!/usr/bin/env python3
"""Negative controls over disposable copies of one real saved Native case."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('round_assessor_controls', HERE/'assess_pair.py')
assessment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assessment)
sha = assessment.shared.sha


def rebind(value, source, target):
    if isinstance(value, dict):
        return {key:rebind(item,source,target) for key,item in value.items()}
    if isinstance(value, list):
        return [rebind(item,source,target) for item in value]
    if isinstance(value,str) and value.startswith(str(source)):
        return str(target)+value[len(str(source)):]
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-case',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args = parser.parse_args()
    source = args.native_case.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
    assessment.native(source)
    before = {str(p.relative_to(source)):sha(p) for p in source.rglob('*') if p.is_file()}
    controls = []
    for mode in ['derived_score_disagrees','missing_actual_ack','rechecksummed_wrong_solver']:
        target = out/mode;shutil.copytree(source,target)
        report_path = target/'report.json';raw=rebind(json.loads(report_path.read_text()),source,target)
        if mode=='derived_score_disagrees':
            assessment.one(raw['actors'][0]['events'],'SAMPLE_GAME')['score']=2
        elif mode=='missing_actual_ack':
            actor=raw['actors'][0];log=Path(actor['log'])
            log.write_bytes(b''.join(line for line in log.read_bytes().splitlines(keepends=True) if not line.startswith(b'SAMPLE_TAIL ')))
            actor['events']=assessment.parse_native(log);actor['log_sha256']=sha(log)
        else:
            manifest_path=target/'host/final-frame.json';manifest=json.loads(manifest_path.read_text())
            part=target/'host'/manifest['parts']['Solver']['file'];data=bytearray(part.read_bytes());data[-1]^=1;part.write_bytes(data)
            manifest['parts']['Solver']['sha256']=sha(part);manifest_path.write_text(json.dumps(manifest)+'\n')
        report_path.write_text(json.dumps(raw,indent=2)+'\n')
        try:
            assessment.native(target)
            controls.append(dict(name=mode,rejected=False))
        except Exception as error:
            controls.append(dict(name=mode,rejected=True,reason=repr(error)))
    unchanged=before=={str(p.relative_to(source)):sha(p) for p in source.rglob('*') if p.is_file()}
    report=dict(result='PASS' if unchanged and all(row['rejected'] for row in controls) else 'FAIL',controls=controls,original_case_unchanged=unchanged,
                scope='Synthetic corrupted copies of saved evidence only; no new gameplay execution or product-failure claim')
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report));return 0 if report['result']=='PASS' else 1


if __name__=='__main__':
    raise SystemExit(main())

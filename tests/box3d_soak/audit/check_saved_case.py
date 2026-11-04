#!/usr/bin/env python3
"""Exercise rolling storage on immutable saved short-case bytes; no runtime run."""
import argparse,hashlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'shared'))
from rolling import RollingConfig,RollingStore,ProcessScope,EvidenceHold
from dataclasses import asdict
from evidence import load_frame,strict_json


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--frame-policy',choices=('all_exports_required','all_follower_exports_required'),default='all_exports_required')
    p.add_argument('--decision-coverage',choices=('all_registered','after_admission_baseline'),default='all_registered');a=p.parse_args()
    case=a.case.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    source=case/'result.json';original_hash=sha(source);original=strict_json(source.read_text());assert original['result']=='PASS'
    processes=original['processes'];assert len(processes)==2
    roles=tuple(item['role'] for item in processes);manifest=original['source_inventory']['sha256']
    store=RollingStore(RollingConfig(directory=out/'store',authority_role=roles[0],follower_roles=roles[1:],allowed_sources={role:(manifest,) for role in roles},disk_budget_bytes=64*1024*1024,frame_policy=a.frame_policy,decision_coverage=a.decision_coverage))
    scopes={};frames={};logs={};phase_counts={}
    try:
        for proc in processes:
            role=proc['role'];scope=f"{role}-p{proc['pid']}-g1";scopes[role]=scope
            ready=proc['ready'];store.register_process(ProcessScope(role,scope,proc['pid'],manifest,int(ready['epoch']),int(ready['baseline'])))
            log=case/role/'godot.log';assert sha(log)==proc['log_sha256'];logs[role]=dict(path=str(log),sha256=sha(log));frames[role]=[];phase_counts[role]={}
            for text in log.read_text().splitlines():
                if text.startswith('{'):row=strict_json(text);kind=row['event'].upper()
                elif text.startswith('BOX3D_SLICE_'):
                    prefix,_,data=text.partition(' ')
                    if not data.startswith('{'):continue
                    row=strict_json(data);kind=prefix.removeprefix('BOX3D_SLICE_')
                else:continue
                if kind=='FRAME':
                    frame=load_frame(case/role,row);ref=store.register_frame(role,scope,frame).frames[0];frames[role].append(ref)
                elif kind=='FX':
                    phase=row.get('phase','commit');phase_counts[role][phase]=phase_counts[role].get(phase,0)+1
                    store.record_fx(role,scope,row)
                elif kind in ('APPLIED','ACTION','INPUT','ACCEPTED'):store.record_decision(role,scope,row)
                elif kind in ('RECOVERY','RECOVERED'):store.record_recovery(role,scope,row)
        # This saved integration fixture has at most8 real frame exports/role;
        # the long controller must interleave/store/compare/retire incrementally.
        for ref in frames[roles[1]]:
            result=store.compare_and_seal(ref);assert result.state=='matched'
            store.retire(ref)
        holds=[]
        for ref in frames[roles[0]]:
            try:store.retire(ref)
            except EvidenceHold as error:holds.append(dict(frame=asdict(ref),reason=str(error)))
        for proc in processes:
            role=proc['role'];result=proc['result'];assert proc['exit_code']==0 and result['ok'] is True
            cleanup=dict(ok=True,native_live_bytes=result['engine_live'],snapshot_live_bytes=result['wrapper_live'],host_application_live_bytes=result['meter_live'],
                         all_explicit_drops_ok=result.get('cleanup_errors',0)==0,core_shutdown_clean=not any(x in (case/role/'godot.log').read_text() for x in ('SHUTDOWN_LIVE','SHUTDOWN_NOT_EMPTY','ERROR:')))
            store.register_exit(role,scopes[role],exit_code=proc['exit_code'],last_epoch=int(proc['ready']['epoch']),last_confirmed=int(result['tick']),cleanup=cleanup)
        final=store.finalize()
        classification='PASS' if final['result']=='PASS' else ('HOLD_UNMATCHED_REQUIRED_FRAMES' if holds and all('unmatched required' in item for item in final['findings']) else 'FAIL')
        exported=store.export_receipts(out/'store/export')
        report=dict(result=classification,unmatched_retirement_holds=holds,phase_counts=phase_counts,scope='read-only storage integration on saved actualP4.3case; no new physics/soak/timer',source_case=str(source),source_sha256=sha(source),logs=logs,rolling=final,receipt_segments=exported,source_case_unchanged=sha(source)==original_hash)
    finally:store.close()
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(out/'report.json')


if __name__=='__main__':main()

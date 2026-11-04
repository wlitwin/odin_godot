#!/usr/bin/env python3
"""Read-only frontend integration on a saved actual scene case, never a new soak."""
from pathlib import Path
from types import SimpleNamespace
import argparse
import hashlib
import json

from run import Soak, Observation, EventArchive
from stream import decode_record
from evidence import EndpointEvidence, require, verify_pair, json_bytes
from rolling import RollingConfig, RollingStore


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case',type=Path,required=True,help='original actual pair result.json directory')
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    case=a.case.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    source=case/'result.json';source_hash=sha(source);original=json.loads(source.read_text())
    require(original['result']=='PASS','saved source case did not pass its original gate')
    processes=original['processes'];require([x['role'] for x in processes]==['host','client'],'saved case is not a pair')
    target=processes[0]['ready']['target'];require(processes[1]['ready']['target']==target,'saved target differs')
    r=Soak.__new__(Soak)
    r.args=SimpleNamespace(framework=original['framework'],bodies=original['initial_dynamic_bodies'],
                          end_tick=target,ticks=original['required_ticks'])
    r.source_sha=original['source_inventory']['sha256'];r.out=out;r.pending=[]
    r.all_go_at=None;r.replaying_saved=True;r.consume_export_files=False
    r.impairment=original['transport']['requested_impairment_environment']
    r.store=RollingStore(RollingConfig(directory=out/'rolling',authority_role='host',follower_roles=('client',),
        allowed_sources={role:(r.source_sha,) for role in ('host','client')},disk_budget_bytes=64*1024*1024,
        frame_policy='all_follower_exports_required',decision_coverage='after_admission_baseline'))
    r.archive=EventArchive(out/'observations.sqlite',32*1024*1024)
    r.observations={}
    readers={};checksums={};error=None;report={}
    try:
        for process in processes:
            role=process['role'];log=case/role/'godot.log';require(sha(log)==process['log_sha256'],'saved log changed')
            checksums[role]=sha(log)
            actor=SimpleNamespace(role=role,process=SimpleNamespace(pid=process['pid']),output=case/role)
            r.observations[role]=Observation(r,actor)
            readers[role]=log.open('rb')
        # This is a deterministic file-read interleaving, not a reconstructed
        # cross-process arrival timeline. Within-role source order is exact.
        while readers:
            for role in list(readers):
                raw=readers[role].readline(1024*1024+1)
                require(len(raw)<=1024*1024,'saved line too long')
                if not raw:
                    readers.pop(role).close();continue
                row=decode_record(raw)
                if row is not None:r.observations[role].receive(*row)
        require(not r.pending,'saved follower bytes remain unconsumed')
        for process in processes:
            role=process['role'];obs=r.observations[role]
            require(process['exit_code']==0 and obs.result==process['result'],'saved natural exit/RESULT binding differs')
            require(obs.last_frame==target and (role!='host' or obs.final_ack),'saved actual target/authority signature receipt absent')
            old=EndpointEvidence(r.args.framework,role,case/role);old.result=obs.result
            clean=old.teardown(process['exit_code'])
            require(not obs.before_admission,'saved early observations were not attributed')
            r.store.register_exit(role,obs.scope,exit_code=0,last_epoch=obs.ready['epoch'],last_confirmed=target,
                cleanup=dict(ok=True,native_live_bytes=clean['engine'],snapshot_live_bytes=clean['wrapper'],
                    host_application_live_bytes=clean['meter'],all_explicit_drops_ok=True,core_shutdown_clean=True))
        final=r.store.finalize();require(final['result']=='PASS',final['findings'])
        host,client=(r.audit_endpoint(role) for role in ('host','client'))
        compared={(int(e,16),int(t,16)) for e,t in r.store.db.execute('SELECT epoch,tick FROM matches WHERE role=?',('client',))}
        paired=verify_pair(host,client,original['required_ticks'],compared)
        report=dict(result='PASS',scope='read-only actual saved-case controller integration; NO new process/timer/soak',
            source_case=str(source),source_case_sha256=source_hash,logs=checksums,
            cross_process_timing='unavailable; round-robin file-read order only',rolling=final,pair=paired,
            original_files_unchanged=sha(source)==source_hash and all(sha(case/role/'godot.log')==v for role,v in checksums.items()),
            controller_files={str(Path(__file__).resolve()):sha(Path(__file__).resolve())},
            receipt_segments=r.store.export_receipts(out/'rolling/export'))
    except Exception as failure:
        error=repr(failure)
        report=dict(result='FAIL',error=error,scope='saved-case integration only',source_case_sha256=source_hash)
    finally:
        for reader in readers.values():reader.close()
        r.store.close();r.archive.db.close()
    (out/'report.json').write_bytes(json_bytes(report)+b'\n')
    print(json.dumps(dict(result=report['result'],report=str(out/'report.json'),error=error)))
    return 0 if report['result']=='PASS' else 1


if __name__=='__main__':raise SystemExit(main())

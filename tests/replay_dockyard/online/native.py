#!/usr/bin/env python3
"""Real Native menu enrollment and one Room-owned complete ENet pair."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('samples',ROOT/'tests/box3d_samples/run.py')
samples=importlib.util.module_from_spec(spec);spec.loader.exec_module(samples)

def available_port():
    with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
def need(ok,message):
    if not ok:raise RuntimeError(message)
def one(rows,tag):
    selected=[r for r in rows if r['event']==tag];need(len(selected)==1,'one '+tag+' required');return selected[0]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--export-record',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--godot',required=True)
    a=p.parse_args();record=json.loads(a.export_record.read_text());project=Path(record['project']);service=Path(record['service'])
    need(record['result']=='EXPORTED_BROWSER_PENDING','actual SDK preparation required')
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False,mode=0o700)
    actors=[];server=None;error=None;port=available_port();game_port=available_port();ticks=1200
    before=samples.project_files(project);driver=Path(__file__).with_name('native_menu.gd');driver_sha=samples.sha(driver)
    env=os.environ.copy();env.pop('BOX3D_SAMPLE_ROLE',None)
    env.update(ODIN_GODOT_ROOT=str(ROOT),ROOT=str(ROOT),BOX3D_SAMPLE_SCRIPTED='1',BOX3D_SAMPLE_TICKS=str(ticks),BOX3D_SAMPLE_PORT=str(game_port),
      DOCKYARD_ROOM_SERVICE=f'ws://127.0.0.1:{port}',DOCKYARD_ROOM_LOCAL='1',N1_PRIVATE=str(out),
      ODIN_SCRIPTS_DLL=str(project/'bin/libodinscripts.dylib'))
    argv=[a.godot,'--headless','--max-fps','120','--path',str(project),'--script',str(driver)]
    try:
        # Both projects were ordinarily imported by the preparation driver.
        for role in ['host','client']:
            folder=out/role;folder.mkdir(mode=0o700)
            role_env=env.copy();role_env.update(N1_ROLE=role,BOX3D_SAMPLE_OUTPUT=str(folder),DOCKYARD_ROOMS_DB=str(folder/'private-room.sqlite3'))
            actors.append(samples.Actor(role,argv,role_env,folder))
        deadline=time.monotonic()+90
        while not (out/'cohort.txt').exists():
            need(time.monotonic()<deadline and all(x.process.poll() is None for x in actors),'native menu cohort unavailable')
            time.sleep(.05)
        cohort=(out/'cohort.txt').read_text();need(len(cohort)==16 and all(c in '0123456789abcdef' for c in cohort),'actual native cohort')
        server_env=env.copy();server_env.update(REPLAY_ROOM_CONTENT='0x'+cohort,REPLAY_ROOM_PORT=str(port),REPLAY_ROOM_DB=str(out/'private-service.sqlite3'),REPLAY_ROOM_CREATE_DB='1',REPLAY_ROOM_LOCAL_DEVELOPMENT='1',REPLAY_ROOM_CHECKPOINT_MODEL='disabled',ODIN_SCRIPTS_DLL=str(service/'bin/libodinscripts.dylib'))
        with (out/'service.log').open('xb') as stream:
            server=subprocess.Popen([a.godot,'--headless','--max-fps','120','--path',str(service)],env=server_env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
            while b'REPLAY_ROOM_SERVICE_READY' not in (out/'service.log').read_bytes():
                need(server.poll() is None and time.monotonic()<deadline,'native service startup unavailable');time.sleep(.05)
            (out/'service.ready').write_text('ready\n')
            for actor in actors:
                actor.process.wait(timeout=max(.01,deadline-time.monotonic()));actor.thread.join(timeout=10)
                need(actor.process.returncode==0 and not actor.thread.is_alive() and actor.error is None,actor.role+': '+str(actor.error or actor.process.returncode))
        frames={}
        for actor in actors:
            result=one(actor.rows,'SAMPLE_RESULT');ready=one(actor.rows,'SAMPLE_READY');inputs=one(actor.rows,'SAMPLE_INPUTS')
            need(result['ok'] and result['final_tick']==ticks and result['confirmed']>=ticks and not result['errors'],'actual confirmed result')
            need(result['cleanup']['observed'] and all(result['cleanup'][k]==0 for k in ['native','wrapper','meter','owners']),'typed resource cleanup')
            need(ready['native_images']==1 and ready['backend_observed'],'one actual backend')
            need(len(inputs['nonzero_by_seat'])==2 and all(type(x) is int and x>0 for x in inputs['nonzero_by_seat']),'two actual authority input seats')
            need(any(r['event']=='SAMPLE_TAIL' and r['signature_match'] and r['tick']==ticks and r['stage']==('final_accepted' if actor.role=='host' else 'close_accepted') for r in actor.rows),'actual terminal acknowledgement')
            _,frames[actor.role],_=samples.final_view(actor.folder,ticks)
        need(all(frames['host'][k]==frames['client'][k] for k in samples.PARTS),'five complete byte parts')
    except Exception as e:error=repr(e)
    finally:
        for actor in actors:
            if actor.process.poll() is None:actor.kill_owned_group()
            actor.process.wait(timeout=10);actor.thread.join(timeout=10)
        if server is not None and server.poll() is None:server.terminate();server.wait(timeout=10)
    # Compare base prepared inputs. Only standard PID reload copies may vary.
    after=samples.project_files(project)
    base_fence=all(after.get(k)==v for k,v in before.items() if '.dylib.r' not in k)
    result='PASS' if error is None and base_fence and driver_sha==samples.sha(driver) else 'FAIL'
    report=dict(result=result,error=error,target=ticks,project_fence=base_fence,export_record_sha256=samples.sha(a.export_record),driver_sha256=driver_sha,
      actors=[dict(role=x.role,pid=x.process.pid,actual_exit=x.process.returncode,intake_drained=not x.thread.is_alive(),intake_error=x.error,log=str(x.folder/'godot.log'),log_sha256=samples.sha(x.folder/'godot.log'),events=x.rows) for x in actors],
      scope='Local Native Party/Room complete ENet menu flow, same native cohort; no Internet or browser inference')
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(result=result,error=error,report=str(out/'report.json'))))
    return 0 if result=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())

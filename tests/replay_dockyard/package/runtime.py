#!/usr/bin/env python3
"""Run a relocated frozen Native SDK pair; no compile or import is performed."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import socket
import time

ROOT=Path(__file__).resolve().parents[3]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
pack=module('dockyard_candidate',ROOT/'examples/replay_dockyard/package.py')
shared=module('dockyard_native_helpers',ROOT/'tests/box3d_samples/run.py')
def need(ok,message):
    if not ok:raise RuntimeError(message)
def one(actor,tag):
    rows=[x for x in actor.rows if x['event']==tag];need(len(rows)==1,'one '+tag+' required');return rows[0]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--godot',required=True);a=p.parse_args()
    source=a.package.resolve(strict=True);manifest=pack.verify(source);out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    moved=out/'relocated-candidate';shutil.copytree(source,moved);pack.verify(moved)
    project=moved/'native-macos-arm64';need(project.is_dir(),'frozen Native SDK required')
    with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
    argv=[a.godot,'--headless','--path',str(project),'--resolution','1280x720']
    actors=[];error=None;frames={};owned_copies=[]
    try:
        for role in ['host','client']:
            folder=out/role;folder.mkdir()
            env=os.environ.copy()
            for name in ['ODIN_GODOT_ROOT','ROOT','ODIN_SCRIPTS_DLL','BOX3D_NATIVE_LIBRARY','DOCKYARD_ROOM_SERVICE']:env.pop(name,None)
            env.update(BOX3D_SAMPLE_ROLE=role,BOX3D_SAMPLE_SCRIPTED='1',BOX3D_SAMPLE_TICKS='1200',BOX3D_SAMPLE_PORT=str(port),BOX3D_SAMPLE_OUTPUT=str(folder))
            actors.append(shared.Actor(role,argv,env,folder))
        deadline=time.monotonic()+100
        for actor in actors:
            actor.process.wait(timeout=max(.01,deadline-time.monotonic()));actor.thread.join(timeout=10)
            need(actor.process.returncode==0 and not actor.thread.is_alive() and actor.error is None,'actual Native process/EOF failed: '+str(actor.error))
            result=one(actor,'SAMPLE_RESULT');ready=one(actor,'SAMPLE_READY');inputs=one(actor,'SAMPLE_INPUTS')
            need(result['ok'] and result['final_tick']==1200 and result['confirmed']>=1200 and not result['errors'],'actual confirmed result')
            need(result['cleanup']['observed'] and all(result['cleanup'][k]==0 for k in ['native','wrapper','meter','owners']),'Native typed cleanup')
            need(ready['native_images']==1 and ready['backend_observed'],'one actual backend image')
            need(all(v>0 for v in inputs['nonzero_by_seat']),'two nonzero committed input seats')
            need(any(x['event']=='SAMPLE_TAIL' and x['signature_match'] and x['tick']==1200 and x['stage']==('final_accepted' if actor.role=='host' else 'close_accepted') for x in actor.rows),'actual terminal acknowledgement')
            _,frames[actor.role],_=shared.final_view(folder,1200)
        need(all(frames['host'][name]==frames['client'][name] for name in shared.PARTS),'all five byte parts')
    except Exception as e:error=repr(e)
    finally:
        for actor in actors:
            if actor.process.poll() is None:actor.kill_owned_group()
            actor.process.wait(timeout=10);actor.thread.join(timeout=10)
        # Hot-reload copies belong only to these recorded actor PIDs and must
        # equal their frozen source. Preserve anything else as a fence failure.
        pids={actor.process.pid for actor in actors}
        pattern=re.compile(r'(.+\.dylib)\.r[0-9]+\.p([0-9]+)\.dylib')
        for file in (project/'bin').glob('*.dylib'):
            match=pattern.fullmatch(file.name)
            if match and int(match[2]) in pids and (project/'bin'/match[1]).is_file() and pack.sha(file)==pack.sha(project/'bin'/match[1]):
                owned_copies.append({'file':str(file.relative_to(moved)),'pid':int(match[2]),'sha256':pack.sha(file)});file.unlink()
    fence=False
    try:pack.verify(source);pack.verify(moved);fence=True
    except Exception as e:error=error or repr(e)
    report={'result':'PASS' if error is None and fence else 'FAIL','error':error,'scope':'Relocated frozen macOS ARM64 Native SDK pair1200, no source-root env/compiler/import; no Intel/Linux/browser inference',
        'package_manifest_sha256':pack.sha(source/'manifest.json'),'argv':argv,'package_bytes_preserved':fence,'all_five_byte_equal':error is None,'owned_reload_copies_removed':owned_copies,
        'actors':[{'role':x.role,'pid':x.process.pid,'actual_exit':x.process.returncode,'intake_error':x.error,'events':x.rows,'log_sha256':pack.sha(x.folder/'godot.log')} for x in actors]}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'result':report['result'],'error':error,'report':str(out/'report.json')}));return 0 if report['result']=='PASS' else 1
if __name__=='__main__':raise SystemExit(main())

#!/usr/bin/env python3
"""One actual GUI host/headless follower; existing normal-input smoke only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from rejoin_probe import records, sha

parser=argparse.ArgumentParser()
parser.add_argument('--stage',type=Path,required=True)
parser.add_argument('--port',type=int,default=43134)
parser.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
args=parser.parse_args();repo=Path(__file__).resolve().parents[3]
args.stage.mkdir(parents=True,exist_ok=False);project=args.stage/'project'
shutil.copytree(repo/'examples/kit_box3d',project,ignore=shutil.ignore_patterns('.godot','*.dSYM','*.r*.dylib','.odin_crash.log'))
shutil.copy2(repo/'tests/box3d_slices/kit/gui_smoke.gd',project/'gui_smoke.gd')
report={'kind':'isolated actual Kit presentation consumer GUI smoke; not32/GateBacceptance',
        'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.dylib')},
        'sources':{p.name:sha(p) for p in (project/'scripts').glob('*.odin')},
        'gui_script_sha256':sha(project/'gui_smoke.gd'),'truth_injection':False}
processes={};streams={}
try:
    with (args.stage/'prepare.log').open('w') as out:
        subprocess.run([sys.executable,str(repo/'build/box3d_profile.py'),'--prepare-import',str(project)],stdout=out,stderr=subprocess.STDOUT,check=True)
        subprocess.run([args.godot,'--headless','--path',str(project),'--import'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=30)
    for role in ('host','client'):
        output=args.stage/role;output.mkdir()
        env=os.environ.copy();env.update(B3_ROLE=role,B3_PORT=str(args.port),B3_TOKEN='101' if role=='host' else '202',B3_ADDRESS='127.0.0.1',B3_SEED='1',B3_BODIES='4',B3_TICKS='0',B3_END_TICK='0',B3_OUTPUT=str(output),B3_SCRIPTED='0',B3_GUI_DONE=str(args.stage/'done.flag'),B3_EXIT_AT='0',B3_GENERATION='1',B3_EXPECT_OBSERVERS='0')
        cmd=[args.godot,'--max-fps','60','--path',str(project),'--script',str(project/'gui_smoke.gd')]
        if role=='client':cmd.insert(1,'--headless')
        streams[role]=(args.stage/(role+'.log')).open('w')
        processes[role]=subprocess.Popen(cmd,env=env,stdout=streams[role],stderr=subprocess.STDOUT)
        time.sleep(.4)
    deadline=time.monotonic()+25
    while time.monotonic()<deadline and any(p.poll() is None for p in processes.values()):time.sleep(.1)
    report['timed_out']=any(p.poll() is None for p in processes.values())
except Exception as error:report['setup_error']=repr(error)
finally:
    for role,p in processes.items():
        if p.poll() is None:p.terminate()
        try:p.wait(timeout=4)
        except subprocess.TimeoutExpired:p.kill();p.wait()
        streams[role].close()
    report['actors']={}
    for role,p in processes.items():
        path=args.stage/(role+'.log');rs=records(path)
        report['actors'][role]={'pid':p.pid,'exit':p.returncode,'log_sha256':sha(path),
          'smoke':[x for x in rs if x.get('event')=='GUI_SMOKE'],
          'cleanup':[x for x in rs if x.get('event')=='RESULT'],
          'godot_errors':[line for line in path.read_text().splitlines() if 'ERROR:' in line or 'SIGSEGV' in line or 'SIGABRT' in line]}
    report['result']='PASS' if len(report['actors'])==2 and all(a['exit']==0 and a['smoke'] and all(x.get('ok') for x in a['smoke']) and a['cleanup'] and all(x.get('ok') and all(x[k]==0 for k in ('engine_live','wrapper_live','meter_live','cleanup_errors')) for x in a['cleanup']) and not a['godot_errors'] for a in report['actors'].values()) else 'FAIL'
    image=args.stage/'host/gui.png'
    if image.exists():report['screenshot']={'path':str(image),'sha256':sha(image),'bytes':image.stat().st_size}
    (args.stage/'report.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
print(json.dumps({'result':report['result'],'report':str(args.stage/'report.json'),'setup_error':report.get('setup_error')}))
raise SystemExit(0 if report['result']=='PASS' else 1)

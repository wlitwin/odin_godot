#!/usr/bin/env python3
"""Thirty-second observation of the real32-body sample; never an acceptance gate."""
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
parser.add_argument('--port',type=int,default=43132)
parser.add_argument('--bodies',type=int,choices=(4,32),default=32)
parser.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
args=parser.parse_args()
repo=Path(__file__).resolve().parents[3]
args.stage.mkdir(parents=True,exist_ok=False)
project=args.stage/'project'
shutil.copytree(repo/'examples/kit_box3d',project,ignore=shutil.ignore_patterns('.godot','*.dSYM','*.r*.dylib','.odin_crash.log'))
report={'kind':'diagnostic-only; not acceptance','initial_dynamic_bodies':args.bodies,'observation_seconds':30,'truth_injection':False,
        'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.dylib')},
        'sources':{p.name:sha(p) for p in (project/'scripts').glob('*.odin')}}
processes={};streams={}
try:
    with (args.stage/'prepare.log').open('w') as out:
        subprocess.run([sys.executable,str(repo/'build/box3d_profile.py'),'--prepare-import',str(project)],stdout=out,stderr=subprocess.STDOUT,check=True)
        subprocess.run([args.godot,'--headless','--path',str(project),'--import'],stdout=out,stderr=subprocess.STDOUT,check=True,timeout=30)
    for role,token in [('host','101'),('client','202')]:
        output=args.stage/role;output.mkdir()
        env=os.environ.copy();env.update(B3_ROLE=role,B3_TOKEN=token,B3_PORT=str(args.port),B3_BODIES=str(args.bodies),B3_SEED='1',B3_TICKS='240',B3_END_TICK='240',B3_SCRIPTED='1',B3_OUTPUT=str(output),B3_LATENCY='0',B3_JITTER='0',B3_LOSS='0',B3_EXIT_AT='0',B3_GENERATION='1',B3_EXPECT_OBSERVERS='0')
        streams[role]=(args.stage/(role+'.log')).open('w')
        processes[role]=subprocess.Popen([args.godot,'--headless','--max-fps','60','--path',str(project)],env=env,stdout=streams[role],stderr=subprocess.STDOUT)
    started=time.monotonic()
    while time.monotonic()-started<30 and any(p.poll() is None for p in processes.values()):
        time.sleep(.1)
    report['actual_observation_seconds']=time.monotonic()-started
    report['timed_out']=any(p.poll() is None for p in processes.values())
except Exception as error:
    report['setup_error']=repr(error)
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
          'result':[x for x in rs if x.get('event')=='RESULT'],
          'last_pump':next((x for x in reversed(rs) if x.get('event')=='PUMP'),None),
          'last_flow':next((x for x in reversed(rs) if x.get('event')=='FLOW'),None),
          'last_envelope':next((x for x in reversed(rs) if x.get('event')=='ENVELOPE'),None),
          'recovery_requests':sum(x.get('event')=='RECOVERY_REQUESTED' for x in rs),
          'recovered':sum(x.get('event')=='RECOVERED' for x in rs),
          'cleanup_complete_claim':bool([x for x in rs if x.get('event')=='RESULT' and x.get('ok')])}
    (args.stage/'report.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
print(json.dumps({'report':str(args.stage/'report.json'),'timed_out':report.get('timed_out'),'setup_error':report.get('setup_error')}))
raise SystemExit(0 if not report.get('setup_error') else 1)

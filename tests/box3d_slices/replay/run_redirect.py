#!/usr/bin/env python3
"""Actual SDK fixture; existing Session/ENet/model, no alternate rollback loop."""
from pathlib import Path
import os,sys,shutil,subprocess,time,json
repo=Path(__file__).resolve().parents[3];stage=Path(sys.argv[1]).resolve();project=stage/'project';stage.mkdir(parents=True,exist_ok=True)
shutil.copytree(repo/'examples/replay_box3d',project,ignore=shutil.ignore_patterns('.godot','bin','*.gen.odin','*.uid'),dirs_exist_ok=True)
shutil.copyfile(repo/'tests/box3d_slices/replay/redirect/probe.odin.txt',project/'scripts/probe.odin')
shutil.copyfile(repo/'tests/box3d_slices/replay/redirect/driver.gd',project/'driver.gd')
# Fixture shares the production package; duplicate imports are file-scoped in Odin.
env=os.environ.copy();env['ODIN_GODOT_ROOT']=str(repo)
with (stage/'build.log').open('w') as log:r=subprocess.run(['bash',str(repo/'build/build_scripts.sh'),str(project)],env=env,stdout=log,stderr=subprocess.STDOUT)
if r.returncode:raise SystemExit(r.returncode)
# Import the fresh declaration before launch; standard helper handles Native path.
with (stage/'import.log').open('w') as log:subprocess.run([env['GODOT'],'--headless','--path',str(project),'--import'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=30,check=True)
env['ODIN_SCRIPTS_DLL']=str(project/'bin/libodinscripts.dylib');jobs=[]
for role,token in [('host',101),('client',202)]:
 case=env.copy();case.update(B3_FIXTURE_OUTPUT=str(stage),B3_ROLE=role,B3_TOKEN=str(token),B3_PORT='49660',B3_SCRIPTED='0',B3_TICKS='0')
 log=(stage/(role+'.log')).open('w');cmd=[env['GODOT'],'--headless','--max-fps','60','--path',str(project)]
 cmd+=['--script',str(project/'driver.gd')]
 p=subprocess.Popen(cmd,env=case,stdout=log,stderr=subprocess.STDOUT);jobs.append((role,p,log));time.sleep(.25)
role,p,log=jobs[1]
try:rc=p.wait(timeout=20)
except subprocess.TimeoutExpired:p.terminate();rc=p.wait(timeout=5)
log.close();jobs[0][1].terminate();jobs[0][1].wait(timeout=5);jobs[0][2].close()
print('redirect-client',rc,flush=True);raise SystemExit(rc)

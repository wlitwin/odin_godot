from pathlib import Path
import hashlib,json,os,subprocess,sys,re,shutil
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();ext=sys.argv[2];project=out/'project'
run=out/(sys.argv[3] if len(sys.argv)>3 else 'run');run.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
(run/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},indent=2)+'\n')
shutil.copy2(root/'tests/replay_scrubber/drive.gd',run/'driver.gd')
(run/'driver-sha256.txt').write_text(sha(run/'driver.gd')+'\n')
env=os.environ.copy();env['ODIN_SCRIPTS_DLL']=str(project/('bin/libodinscripts.'+ext));env['SCRUBBER_RESULT_DIR']=str(run)
for driver,label in [(project/'hello_test.gd','hello'),(project/'loot_test.gd','loot'),(run/'driver.gd','scrubber'),(run/'driver.gd','rendered')]:
 if label=='rendered':
  (run/'rendered').mkdir();env['SCRUBBER_RESULT_DIR']=str(run/'rendered');env['SCRUBBER_CAPTURE']=str(run/'inspection.png')
 env["REPLAY_RECORDING_PATH"]=str(Path(env["SCRUBBER_RESULT_DIR"])/"hello.rplrec")
 with (run/(label+'.log')).open('w') as log:
  child=subprocess.Popen([env['GODOT']]+([] if label=='rendered' else ['--headless'])+['--fixed-fps','60','--path',str(project),'--script',str(driver)],env=env,stdout=log,stderr=subprocess.STDOUT)
  try:code=child.wait(timeout=45)
  finally:
   if child.poll() is None:
    child.terminate()
    try:child.wait(timeout=5)
    except subprocess.TimeoutExpired:child.kill();child.wait()
 output=(run/(label+'.log')).read_text()
 assert code==0 and not re.search(r'SCRIPT ERROR|ERROR:|REPLAY_SCRUBBER_FAIL|instances were leaked|resources still in use',output),(label,code,output[-3000:])
 print(label,'PASS',flush=True)

for folder in (run,run/'rendered'):
 result=json.loads((folder/'result.json').read_text())
 for name in ('original','branch'):
  expected=next(row for row in result['observations'] if row['name']=='recorded_'+name)
  verified=subprocess.run([str(out/'verify_recording'),str(folder/(name+'.rplrec'))],text=True,capture_output=True)
  (folder/(name+'-verify.log')).write_text(verified.stdout+verified.stderr)
  assert verified.returncode==0 and 'REPLAY_RECORDING_OK' in verified.stdout,verified.stderr
  fields=dict(re.findall(r'(head|shots|x|epoch)=([0-9.]+)',verified.stdout))
  assert int(fields['head'])==expected['head'] and int(fields['shots'])==expected['shots'] and int(fields['epoch'])==expected['epoch'] and abs(float(fields['x'])-expected['x'])<.001,fields
print("REPLAY_SCRUBBER_RECORDING_OK")
print("REPLAY_SCRUBBER_OK")

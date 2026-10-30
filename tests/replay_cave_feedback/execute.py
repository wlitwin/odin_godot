from pathlib import Path
import hashlib,json,os,re,subprocess,socket,sys,time
root=Path(__file__).resolve().parents[2];build=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();mode=sys.argv[3];out.mkdir(parents=True,exist_ok=False);project=build/'project'
assert mode in ('visual','rendered','campaign','fault','colors','generation')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((build/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((build/'framework.json').read_text()).items():assert sha(root/n)==h,n
ext='dylib' if sys.platform=='darwin' else 'so'
(out/'inputs.json').write_text(json.dumps({'mode':mode,'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)}},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
roles=['host','client','observer'] if mode in ('campaign','fault') else ['host'];children=[];handles=[]
fault=mode=='fault'
(out/'environment.json').write_text(json.dumps({'receive_delay_ms':120,'jitter_ms':20 if fault else 0,'loss_permyriad':1000 if fault else 0,'duplicate_permyriad':1000 if fault else 0,'roles':roles,'hz':20,'frame_cap':60,'seed':1337},indent=2)+'\n')
try:
 for role in roles:
  env=os.environ|{'ODIN_GODOT_ROOT':str(root),'ODIN_SCRIPTS_DLL':str(project/('bin/libodinscripts.'+ext)),'REPLAY_CAVE_ROLE':role,'REPLAY_CAVE_PORT':str(port),'REPLAY_CAVE_TOKEN':'feedback-'+role,'REPLAY_CAVE_NAME':role,'REPLAY_CAVE_PERSIST':'0','REPLAY_CAVE_LATENCY':'120','REPLAY_CAVE_JITTER':'20' if fault else '0','REPLAY_CAVE_LOSS':'1000' if fault else '0','REPLAY_CAVE_DUPLICATE':'1000' if fault else '0','REPLAY_CAMPAIGN_DIR':str(out),'CAVE_FEEDBACK_CAPTURE':str(out/'burst.png') if mode=='rendered' else ''}
  h=(out/(role+'.log')).open('w');handles.append(h)
  script=str(root/'tests/replay_cave_impact/generation.gd') if mode=='generation' else str(root/'tests/replay_cave_feedback/colors.gd') if mode=='colors' else 'campaign_test.gd' if len(roles)>1 else 'feedback_test.gd'
  if os.environ.get('CAVE_FEEDBACK_DRIVER'):script=str(Path(os.environ['CAVE_FEEDBACK_DRIVER']).resolve())
  p=subprocess.Popen([env['GODOT']]+([] if mode=='rendered' else ['--headless'])+['--max-fps','60','--path',str(project),'--script',script],env=env,stdout=h,stderr=subprocess.STDOUT);children.append(p)
  time.sleep(.3)
 deadline=time.monotonic()+240
 while any(p.poll() is None for p in children):
  assert time.monotonic()<deadline,'timeout'
  for role,p in zip(roles,children):
   text=(out/(role+'.log')).read_text();assert not re.search(r'SCRIPT ERROR|ERROR:|CAVE_.*FAIL',text),text[-3500:]
   assert p.poll() in (None,0),(role,p.poll())
  time.sleep(.1)
 for role in roles:
  text=(out/(role+'.log')).read_text();assert not re.search(r'instances were leaked|resources still in use',text),text[-2000:]
  assert ('REPLAY_CAVE_CAMPAIGN_OK' if len(roles)>1 else 'REPLAY_CAVE_FEEDBACK_VISUAL_OK') in text,text[-2000:]
  if len(roles)>1:
   m=re.search(r'CAVE_FEEDBACK_CAMPAIGN died=(\d+) slain=(\d+) hits=(\d+) dweller_hits=(\d+) started=(\d+)',text);assert m,text[-2000:]
   counts=list(map(int,m.groups()));assert counts[0]>=2 and counts[1]>=12 and counts[2]>0 and counts[3]>=24
   if role in ('host','observer'):assert counts[:2]==[2,12],(role,counts)
 if len(roles)>1:subprocess.run([sys.executable,str(project/'campaign_verify.py'),str(out)],check=True)
 print('REPLAY_CAVE_FEEDBACK_CASE_OK',mode)
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for h in handles:h.close()
 (out/'exits.json').write_text(json.dumps([p.returncode for p in children])+'\n')

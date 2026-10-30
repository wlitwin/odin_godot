from pathlib import Path
import hashlib,json,os,re,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];build=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();fps=int(sys.argv[3]);out.mkdir(parents=True,exist_ok=False);project=build/'project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((build/'framework.json').read_text()).items():assert sha(root/n)==h,n
for n,h in json.loads((build/'prepared.json').read_text()).items():assert sha(project/n)==h,n
ext='dylib' if sys.platform=='darwin' else 'so';driver=root/'tests/replay_cave_rocks/drive.gd'
(out/'inputs.json').write_text(json.dumps({'fps':fps,'driver_sha256':sha(driver),'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)}},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
children=[];logs=[]
try:
 for role in ['host','client','observer']:
  env=os.environ|{'ODIN_GODOT_ROOT':str(root),'ODIN_SCRIPTS_DLL':str(project/('bin/libodinscripts.'+ext)),'REPLAY_CAVE_ROLE':role,'REPLAY_CAVE_PORT':str(port),'REPLAY_CAVE_TOKEN':'rock-'+role,'REPLAY_CAVE_PERSIST':'0','REPLAY_CAVE_LATENCY':'120','CAVE_ROCK_ROLE':role,'CAVE_ROCK_DIR':str(out)}
  h=(out/(role+'.log')).open('w');logs.append(h)
  p=subprocess.Popen([env['GODOT'],'--headless','--max-fps',str(fps),'--path',str(project),'--script',str(driver)],env=env,stdout=h,stderr=subprocess.STDOUT);children.append(p)
  time.sleep(.3)
 deadline=time.monotonic()+25
 while any(p.poll() is None for p in children):
  assert time.monotonic()<deadline,'timeout'
  for role,p in zip(['host','client','observer'],children):
   text=(out/(role+'.log')).read_text();assert not re.search(r'SCRIPT ERROR|ERROR:|CAVE_ROCK_FAIL',text),text
   assert p.poll() in (None,0),(role,p.poll())
  time.sleep(.05)
 report={}
 for role in ['host','client','observer']:
  text=(out/(role+'.log')).read_text();assert 'REPLAY_CAVE_ROCK_PROCESS_OK' in text and not re.search(r'instances were leaked|resources still in use',text),text
  data=json.loads((out/(role+'.json')).read_text());rows=data['rows'];assert data['pass'] and len(rows)>=12
  moving=0;opportunities=0;largest=0
  for row in rows:
   assert abs(row['y']-row['draw_y'])<.01 and abs(row['vy'])<.01
   assert -.01<=row['draw_x']-row['x']<=row['vx']+.01,row
   assert abs(row['center_x'])<.01 and abs(row['center_y'])<.01,row
  for a,b in zip(rows,rows[1:]):
   if b['tick']>a['tick'] and b['x']>=a['x']:assert b['draw_x']>=a['draw_x']-.01,(role,a,b)
   if a['tick']==b['tick'] and abs(a['x']-b['x'])<.001:
    opportunities+=1
    delta=b['draw_x']-a['draw_x'];assert delta>=-.01,(role,a,b)
    if delta>.01:moving+=1;largest=max(largest,delta)
  assert moving>=(2 if fps==30 else 6),(role,moving,len(rows))
  assert opportunities>0 and moving/opportunities>=.65,(role,moving,opportunities)
  report[role]={'samples':len(rows),'motion_between_ticks':moving,'same_tick_pairs':opportunities,'largest_between_tick_step':largest,'first_tick':rows[0]['tick'],'last_tick':rows[-1]['tick']}
 (out/'report.json').write_text(json.dumps({'pass':True,'fps':fps,'roles':report},indent=2)+'\n');print('REPLAY_CAVE_ROCK_MOTION_OK',fps,json.dumps(report))
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for h in logs:h.close()
 (out/'exits.json').write_text(json.dumps([p.returncode for p in children])+'\n')

from pathlib import Path
import hashlib,json,os,re,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];game=Path(sys.argv[1]).resolve()/'project';service=Path(sys.argv[2]).resolve()/'project';out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False);os.chmod(out,0o700);ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
restoring_role=os.environ.get('RS3_RESTORE_OWNER','host');assert restoring_role in ['host','striker'];restoring_seat=1 if restoring_role=='host' else 2
subprocess.run([sys.executable,str(root/'tests/replay_slopball3d_native_restore/prepare_bridge.py'),str(out/'bridge.gd')],check=True)
verifier=out/'verify-publication'
subprocess.run(['odin','build',str(root/'tests/replay_slopball3d_party_restore/verify'),'-collection:godot='+str(root),'-out:'+str(verifier)],check=True)
with (out/'certificate.log').open('w') as log:subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(out/'key.pem'),'-out',str(out/'cert.pem'),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],stdout=log,stderr=subprocess.STDOUT,check=True)
os.chmod(out/'key.pem',0o600)
def port(kind=socket.SOCK_STREAM):
 with socket.socket(socket.AF_INET,kind) as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
control=port();ports={role:port(socket.SOCK_DGRAM) for role in ('host','striker','wing','watch')};children=[];files=[];events=[];serial=0

def service_start(create):
 env=os.environ.copy();env.update(REPLAY_ROOM_CONTENT='0x52534c4f50334434',REPLAY_ROOM_CHECKPOINT_MODEL='slopball3d',REPLAY_ROOM_PORT=str(control),REPLAY_ROOM_DB=str(out/'service.sqlite3'),REPLAY_ROOM_CREATE_DB=str(create),REPLAY_ROOM_CERT=str(out/'cert.pem'),REPLAY_ROOM_KEY=str(out/'key.pem'),REPLAY_ROOM_LOCAL_DEVELOPMENT='0',ODIN_SCRIPTS_DLL=str(service/('bin/libodinscripts.'+ext)))
 log=(out/('service-'+str(create)+'.log')).open('w');files.append(log);p=subprocess.Popen([env['GODOT'],'--headless','--max-fps','120','--path',str(service)],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(p)
 end=time.monotonic()+15
 while 'REPLAY_ROOM_SERVICE_READY' not in (out/('service-'+str(create)+'.log')).read_text():assert p.poll() is None and time.monotonic()<end,'service startup';time.sleep(.05)
 assert 'tls=true' in (out/('service-'+str(create)+'.log')).read_text();return p

def launch(role,phase):
 label=phase+'-'+role;env=os.environ.copy();env.update(RS3_NATIVE_RESTORE_DIR=str(out),RS3_NATIVE_RESTORE_ROLE=label,RS3_ROOM_SERVICE='wss://localhost:'+str(control),RS3_ROOM_CA=str(out/'cert.pem'),RS3_ROOM_LOCAL='0',RS3_ROOMS_DB=str(out/(role+'-rooms.sqlite3')),RS3_PROFILE=str(out/(role+'-profile')),RS3_ROLE='',RS3_TOKEN='',RS3_NAME='',RS3_PERSIST='1',RS3_BOT='',RS3_GOALS='9',RS3_PLAYERS='3',RS3_PORT=str(ports[role]),RS3_LATENCY='120',RS3_COORD_PORT='0',RS3_PROBE='1',ODIN_SCRIPTS_DLL=str(game/('bin/libodinscripts.'+ext)))
 log=(out/(label+'.log')).open('w');files.append(log);p=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(game),'--script',str(out/'bridge.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(p)
 a={'label':label,'process':p};until(a,lambda s:s['profile_ready']==1 and s['recent']==1,'menu');return a

def status(a):
 text=(out/(a['label']+'.log')).read_text();assert not re.search(r'REPLAY_SLOPBALL3D_FAIL|SCRIPT ERROR|ERROR:',text),(a['label'],text[-2000:]);assert a['process'].poll() is None,a['label']+' exited'
 p=out/(a['label']+'-status.json');s=json.loads(p.read_text()) if p.exists() else None
 if s:assert s['failed']==0 and s['profile_failed']==0,(a['label'],s['notice'])
 return s

def safe(s):return {k:v for k,v in s.items() if k!='invite'}
def until(a,test,label,seconds=45):
 end=time.monotonic()+seconds;s=None
 while time.monotonic()<end:
  s=status(a)
  if s and test(s):events.append({'role':a['label'],'event':label,**safe(s)});return s
  time.sleep(.05)
 raise AssertionError((a['label'],label,safe(s) if s else None))

def send(a,kind,value=None):
 global serial
 serial+=1;seq=serial;p=out/(a['label']+'-request.json');tmp=Path(str(p)+'.tmp');tmp.write_text(json.dumps({'id':seq,'kind':kind,'value':value}));tmp.replace(p)
 end=time.monotonic()+10
 while time.monotonic()<end:
  s=status(a)
  if s and s['command']==seq:return s
  time.sleep(.02)
 raise AssertionError('command '+kind)

def common(peers):
 for _ in range(80):
  tick=status(peers[0])['tick']-30;answers=[send(a,'hash',tick) for a in peers]
  if all(s['hash']!='-1' for s in answers):
   assert all(s['hash']==answers[0]['hash'] for s in answers);return {'tick':tick,'hash':answers[0]['hash']}
  time.sleep(.08)
 raise AssertionError('no common retained world')

paths={'host':'UI/Lobby/Column/Buttons/Host','join':'UI/Lobby/Column/Buttons/Join','start':'UI/Lobby/Column/Start','rejoin':'UI/Lobby/Column/Party/Choices/Rejoin'}
try:
 server=service_start(1);host=launch('host','source');send(host,'name','Captain');send(host,'press',paths['host']);created=until(host,lambda s:s['ready'] and s['invited']==1 and s['profile_saved']==1,'created');invite=created['invite'];identity=created['profile_hash']
 striker=launch('striker','source');send(striker,'name','Striker');send(striker,'invite',invite);send(striker,'press',paths['join']);until(striker,lambda s:s['ready'] and s['seat']==2,'joined')
 striker_identity=status(striker)['profile_hash']
 wing=launch('wing','source');send(wing,'name','Wing');send(wing,'invite',invite);send(wing,'press',paths['join']);until(wing,lambda s:s['ready'] and s['seat']==3,'joined')
 watch=launch('watch','source');send(watch,'name','Watcher');send(watch,'watch',True);send(watch,'invite',invite);send(watch,'press',paths['join']);until(watch,lambda s:s['ready'] and s['observer']==1 and s['seat']==0 and s['backup']==0,'observer joined')
 peers=[host,striker,wing,watch]
 for a in peers:until(a,lambda s:s['players']==3 and s['named'] and s['separate']==1,'roster')
 send(host,'press',paths['start']);until(watch,lambda s:s['started']==1,'started');send(host,'bot','striker')
 until(host,lambda s:s['publication_moving']==1 and 4<s['live_pose'][0][0]<12,'scored moving match',60);assert send(host,'save')['result'];saved=until(host,lambda s:s['party_save_completed']==1 and s['party_save_epoch']==1,'published');saved_hash=send(host,'hash',saved['party_save_tick'])['hash'];assert saved_hash!='-1'
 for a in peers:send(a,'freeze')
 with (out/'source-verification.log').open('w') as log:subprocess.run([str(verifier),str(out/'service.sqlite3'),'source'],stdout=log,stderr=subprocess.STDOUT,check=True)
 source=(out/'source-verification.log').read_text();source_pose=json.loads(source.split('SLOPBALL3D_PUBLISHED_POSE ',1)[1].splitlines()[0]);assert 'tick='+str(saved['party_save_tick'])+' ' in source and 'hash='+saved_hash+' ' in source,source
 for a in peers:a['process'].kill()
 for a in peers:assert a['process'].wait()==-9,a['label']
 killed={a['label']:{'pid':a['process'].pid,'returncode':a['process'].returncode} for a in peers}
 server.kill();assert server.wait()==-9;killed['service']={'pid':server.pid,'returncode':server.returncode};(out/'killed.json').write_text(json.dumps(killed,indent=2)+'\n');server=service_start(0)
 watch=launch('watch','returned');send(watch,'watch',True);send(watch,'press',paths['rejoin']);until(watch,lambda s:s['member']==4 and s['incarnation']>1,'observer registered');assert status(watch)['authority']==0 and status(watch)['ball_solver']==0
 authority=launch(restoring_role,'returned');assert status(authority)['name']==('Captain' if restoring_role=='host' else 'Striker');send(authority,'press',paths['rejoin']);restored=until(authority,lambda s:s['ready'] and s['steady']==1 and s['epoch']==2 and s['party_restore_publication']==1 and s['seeded']==1,'restored',60)
 assert restored['seat']==restoring_seat and restored['member']==restoring_seat
 assert len(restored['seed'])==4 and len(source_pose)==4
 for group in [0,2,3]:assert len(restored['seed'][group])==3 and all(abs(a-b)<0.0001 for a,b in zip(restored['seed'][group],source_pose[group])),(restored['seed'],source_pose)
 assert len(restored['seed'][1])==4 and abs(sum(a*b for a,b in zip(restored['seed'][1],source_pose[1])))>0.99999,'quaternion'
 assert source_pose[2][0]**2+source_pose[2][2]**2>1 and sum(x*x for x in source_pose[3])>0.25 and sum(abs(x) for x in source_pose[1][:3])>0.05
 assert restored['profile_hash']==(identity if restoring_role=='host' else striker_identity),'connected native identity changed'
 assert restored['party_restore_tick']==saved['party_save_tick'] and restored['incarnation']>saved['incarnation'];assert send(authority,'hash',saved['party_save_tick'])['hash']==saved_hash;assert re.search(r'(?:Saved party|Party) restored',restored['recovery_notice'])
 until(watch,lambda s:s['ready'] and s['epoch']==2 and s['observer']==1 and s['seat']==0 and s['backup']==0,'observer follows')
 if restoring_role=='host':
  host=authority;striker=launch('striker','returned');send(striker,'press',paths['rejoin']);until(striker,lambda s:s['ready'] and s['epoch']==2 and s['seat']==2,'striker returns')
 else:
  striker=authority;host=launch('host','returned');send(host,'press',paths['rejoin']);until(host,lambda s:s['ready'] and s['epoch']==2 and s['seat']==1,'creator returns after successor restore');assert status(host)['profile_hash']==identity
 wing=launch('wing','returned');send(wing,'press',paths['rejoin']);until(wing,lambda s:s['ready'] and s['epoch']==2 and s['seat']==3,'wing returns')
 peers=[host,striker,wing,watch]
 for a in peers:until(a,lambda s:s['players']==3 and s['named'] and s['separate']==1,'returned roster')
 observer=status(watch);assert observer['ball_solver']==0 and observer['seat']==0 and observer['backup']==0
 old=status(authority);score_key='left' if restoring_seat==1 else 'right';send(authority,'bot','striker');until(authority,lambda s:s['kicks']>0 and s[score_key]>old[score_key],'continued kick and goal',60);send(authority,'bot','idle')
 until(authority,lambda s:s['body_epoch']==2 and s['body_sequence']>0,'new scoped observations')
 until(watch,lambda s:s['observer_named']==1,'observer name');send(watch,'chat','native saved party returned')
 for a in peers:until(a,lambda s:'Watcher (observer): native saved party returned' in s['chat'],'new chat')
 assert not send(wing,'save')['result'];assert send(authority,'save')['result'];published=until(authority,lambda s:s['party_save_completed']==1 and s['party_save_revision']==2 and s['party_save_epoch']==2,'republished');assert published['layout_clear']
 final=common([authority,striker if restoring_role=='host' else host,wing,watch]);assert final['tick']>restored['party_restore_tick']
 result={'pass':True,'restoring_role':restoring_role,'restoring_seat':restoring_seat,'creator_returned':True,'wss':True,'native_enet':True,'all_processes_killed':True,'service_restarted':True,'saved':{'tick':saved['party_save_tick'],'hash':saved_hash,'pose':source_pose},'restored':{'tick':restored['party_restore_tick'],'hash':saved_hash,'epoch':2,'incarnation':restored['incarnation'],'lost':restored['lost'],'seed':restored['seed']},'identity_retained':True,'returning_players':3,'observer':True,'continued_kick_and_goal':True,'publication_revision':2,'publication_tick':published['party_save_tick'],'final':final}
 with (out/'continued-verification.log').open('w') as log:subprocess.run([str(verifier),str(out/'service.sqlite3'),'continued',restoring_role],stdout=log,stderr=subprocess.STDOUT,check=True)
 for path in out.glob('service-*.log'):assert not re.search(r'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL',path.read_text()),path
 (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print('REPLAY_SLOPBALL3D_NATIVE_RESTORE_OK')
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for file in files:file.close()
 (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 (out/'builds.json').write_text(json.dumps({'game':{p.name:sha(p) for p in (game/'bin').glob('*.'+ext)},'service':{p.name:sha(p) for p in (service/'bin').glob('*.'+ext)},'driver':sha(out/'bridge.gd')},indent=2)+'\n')

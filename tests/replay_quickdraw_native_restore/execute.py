from pathlib import Path
import hashlib,json,os,re,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];game=Path(sys.argv[1]).resolve()/'project';service=Path(sys.argv[2]).resolve()/'project';out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False);os.chmod(out,0o700);ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
subprocess.run([sys.executable,str(root/'tests/replay_quickdraw_native_restore/prepare_bridge.py'),str(out/'bridge.gd')],check=True)
with (out/'certificate.log').open('w') as log:subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(out/'key.pem'),'-out',str(out/'cert.pem'),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],stdout=log,stderr=subprocess.STDOUT,check=True)
os.chmod(out/'key.pem',0o600)
def port():
 with socket.socket(socket.AF_INET,socket.SOCK_STREAM) as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
control=port();ports={role:port() for role in ('host','deputy','rider','watch')};children=[];files=[];events=[];serial=0

def service_start(create):
 env=os.environ.copy();env.update(REPLAY_ROOM_CONTENT='0x52515549434b4432',REPLAY_ROOM_CHECKPOINT_MODEL='quickdraw',REPLAY_ROOM_PORT=str(control),REPLAY_ROOM_DB=str(out/'service.sqlite3'),REPLAY_ROOM_CREATE_DB=str(create),REPLAY_ROOM_CERT=str(out/'cert.pem'),REPLAY_ROOM_KEY=str(out/'key.pem'),REPLAY_ROOM_LOCAL_DEVELOPMENT='0',ODIN_SCRIPTS_DLL=str(service/('bin/libodinscripts.'+ext)))
 log=(out/('service-'+str(create)+'.log')).open('w');files.append(log);p=subprocess.Popen([env['GODOT'],'--headless','--max-fps','120','--path',str(service)],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(p)
 end=time.monotonic()+15
 while 'REPLAY_ROOM_SERVICE_READY' not in (out/('service-'+str(create)+'.log')).read_text():assert p.poll() is None and time.monotonic()<end,'service startup';time.sleep(.05)
 assert 'tls=true' in (out/('service-'+str(create)+'.log')).read_text();return p

def launch(role,phase):
 label=phase+'-'+role;env=os.environ.copy();env.update(RQ_NATIVE_RESTORE_DIR=str(out),RQ_NATIVE_RESTORE_ROLE=label,RQ_ROOM_SERVICE='wss://localhost:'+str(control),RQ_ROOM_CA=str(out/'cert.pem'),RQ_ROOM_LOCAL='0',RQ_ROOMS_DB=str(out/(role+'-rooms.sqlite3')),RQ_PROFILE=str(out/(role+'-profile')),RQ_ROLE='',RQ_TOKEN='',RQ_NAME='',RQ_PERSIST='1',RQ_BOT='',RQ_GOLD='1',RQ_PORT=str(ports[role]),RQ_LATENCY='120',RQ_COORD_PORT='0',RQ_PROBE='1',ODIN_SCRIPTS_DLL=str(game/('bin/libodinscripts.'+ext)))
 log=(out/(label+'.log')).open('w');files.append(log);p=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(game),'--script',str(out/'bridge.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(p)
 a={'label':label,'process':p};until(a,lambda s:s['profile_ready']==1 and s['recent']==1,'menu');return a

def status(a):
 text=(out/(a['label']+'.log')).read_text();assert not re.search(r'REPLAY_QUICKDRAW_FAIL|SCRIPT ERROR|ERROR:',text),(a['label'],text[-2000:]);assert a['process'].poll() is None,a['label']+' exited'
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
 server=service_start(1);host=launch('host','source');send(host,'name','Marshal');send(host,'press',paths['host']);created=until(host,lambda s:s['ready'] and s['invited']==1 and s['profile_saved']==1,'created');invite=created['invite'];identity=created['profile_hash']
 deputy=launch('deputy','source');send(deputy,'name','Deputy');send(deputy,'invite',invite);send(deputy,'press',paths['join']);until(deputy,lambda s:s['ready'] and s['seat']==2,'joined')
 rider=launch('rider','source');send(rider,'name','Rider');send(rider,'invite',invite);send(rider,'press',paths['join']);until(rider,lambda s:s['ready'] and s['seat']==3,'joined')
 watch=launch('watch','source');send(watch,'name','Watcher');send(watch,'watch',True);send(watch,'invite',invite);send(watch,'press',paths['join']);until(watch,lambda s:s['ready'] and s['observer']==1 and s['seat']==0 and s['backup']==0,'observer joined')
 peers=[host,deputy,rider,watch]
 for a in peers:until(a,lambda s:s['players']==3 and s['named'] and s['separate']==1,'roster')
 send(host,'press',paths['start']);until(watch,lambda s:s['started']==1,'started');send(deputy,'drive',[0,1,0,0,1]);assert send(rider,'buy')['result'];send(rider,'drive',[0,0,5,2,-1])
 until(host,lambda s:s['hp2']==0 and s['bullets']>0 and s['boots3']==1,'combat');assert send(host,'save')['result'];saved=until(host,lambda s:s['party_save_completed']==1 and s['party_save_epoch']==1,'published');saved_hash=send(host,'hash',saved['party_save_tick'])['hash'];assert saved_hash!='-1'
 for a in peers:send(a,'freeze')
 for a in peers:a['process'].kill()
 for a in peers:a['process'].wait()
 server.kill();server.wait();server=service_start(0)
 watch=launch('watch','returned');send(watch,'watch',True);send(watch,'press',paths['rejoin']);until(watch,lambda s:s['member']==4 and s['incarnation']>1,'observer registered');assert status(watch)['authority']==0
 host=launch('host','returned');assert status(host)['name']=='Marshal';send(host,'press',paths['rejoin']);restored=until(host,lambda s:s['ready'] and s['steady']==1 and s['epoch']==2 and s['party_restore_publication']==1,'restored',60)
 assert restored['profile_hash']==identity,'connected native identity changed'
 assert restored['party_restore_tick']==saved['party_save_tick'] and restored['incarnation']>saved['incarnation'];assert send(host,'hash',saved['party_save_tick'])['hash']==saved_hash;assert 'Saved party restored' in restored['recovery_notice']
 until(watch,lambda s:s['ready'] and s['epoch']==2 and s['observer']==1 and s['seat']==0 and s['backup']==0,'observer follows')
 deputy=launch('deputy','returned');send(deputy,'press',paths['rejoin']);until(deputy,lambda s:s['ready'] and s['epoch']==2 and s['seat']==2,'deputy returns')
 rider=launch('rider','returned');send(rider,'press',paths['rejoin']);until(rider,lambda s:s['ready'] and s['epoch']==2 and s['seat']==3 and s['boots3']==1,'rider returns')
 peers=[host,deputy,rider,watch]
 for a in peers:until(a,lambda s:s['players']==3 and s['named'] and s['separate']==1,'returned roster')
 old=status(host);send(rider,'drive',[0,0,5,2,-1]);until(host,lambda s:s['hits']>old['hits'] and s['lobs']>old['lobs'] and s['life2']>old['life2'],'continued combat');send(rider,'drive',[0,0,0,0,0]);until(host,lambda s:s['bullets']==0,'drained')
 until(watch,lambda s:s['observer_named']==1,'observer name');send(watch,'chat','native saved party returned')
 for a in peers:until(a,lambda s:'Watcher (observer): native saved party returned' in s['chat'],'new chat')
 assert not send(rider,'save')['result'];assert send(host,'save')['result'];published=until(host,lambda s:s['party_save_completed']==1 and s['party_save_revision']==2 and s['party_save_epoch']==2,'republished');assert published['recovery_layout_clear']
 final=common(peers)
 result={'pass':True,'wss':True,'native_enet':True,'all_processes_killed':True,'service_restarted':True,'saved':{'tick':saved['party_save_tick'],'hash':saved_hash},'restored':{'tick':restored['party_restore_tick'],'hash':saved_hash,'epoch':2,'incarnation':restored['incarnation']},'identity_retained':True,'returning_players':3,'observer':True,'continued_combat':True,'publication_revision':2,'publication_tick':published['party_save_tick'],'final':final}
 (out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print('REPLAY_QUICKDRAW_NATIVE_RESTORE_OK')
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for file in files:file.close()
 (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 (out/'builds.json').write_text(json.dumps({'game':{p.name:sha(p) for p in (game/'bin').glob('*.'+ext)},'service':{p.name:sha(p) for p in (service/'bin').glob('*.'+ext)},'driver':sha(out/'bridge.gd')},indent=2)+'\n')

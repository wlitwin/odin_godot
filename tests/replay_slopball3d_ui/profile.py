from pathlib import Path
import hashlib,os,subprocess,sys,re,json
out=Path(sys.argv[1]).resolve();project=out/'project';folder=out/'profiles';folder.mkdir(exist_ok=False);prefix=folder/'identity';name=Path(str(prefix)+'.name');ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ.copy();env.update(RS3_ROLE='',RS3_TOKEN='',RS3_BOT='',RS3_NAME='',RS3_COORD_PORT='0',RS3_PERSIST='1',RS3_PROFILE=str(prefix),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();hashes={}
for mode in ('write','read','corrupt'):
 if mode=='corrupt':name.write_bytes(b'bad-name-profile');before=sha(name)
 env['RS3_PROFILE_TEST']=mode
 with (folder/(mode+'.log')).open('w') as log:
  child=subprocess.Popen([env['GODOT'],'--headless','--fixed-fps','60','--path',str(project),'--script',str(Path(__file__).with_name('profile.gd'))],env=env,stdout=log,stderr=subprocess.STDOUT)
  try:code=child.wait(timeout=20)
  finally:
   if child.poll() is None:
    child.terminate()
    try:child.wait(timeout=5)
    except subprocess.TimeoutExpired:child.kill();child.wait()
 text=(folder/(mode+'.log')).read_text();assert code==0 and 'RS3_PROFILE_OK '+mode in text and not re.search(r'RS3_PROFILE_FAIL|REPLAY_SLOPBALL3D_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use',text),(mode,text)
 hashes[mode]={'identity':sha(prefix),'name':sha(name)}
 if mode=='read':assert hashes['read']==hashes['write'],'profile changed across fresh process'
 if mode=='corrupt':assert sha(name)==before and sha(prefix)==hashes['write']['identity'],'corrupt data replaced'
(folder/'report.json').write_text(json.dumps({'pass':True,'hashes':hashes},indent=2)+'\n');print('REPLAY_SLOPBALL3D_PROFILE_OK')

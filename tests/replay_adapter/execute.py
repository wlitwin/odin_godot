from pathlib import Path
import os,subprocess,sys,json
work=Path(sys.argv[1]);project=work/'project';out=work/'adapter-checks';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json')}
for script,marker in [('preview','REPLAY_ADAPTER_PREVIEW_OK'),('lifecycle','REPLAY_ADAPTER_LIFECYCLE_OK')]:
 with (out/f'{script}.log').open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',f'adapter_{script}.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
 text=(out/f'{script}.log').read_text()
 assert marker in text and not any(x in text for x in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),(script,text)
 print(marker,flush=True)
(out/'result.json').write_text(json.dumps({'pass':True,'cases':['preview','lifecycle']},indent=2)+'\n')

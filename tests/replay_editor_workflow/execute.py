from pathlib import Path
import json,os,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2]
work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'workflow-checks';out.mkdir(exist_ok=False)
for name in ['preview','workbench']:shutil.copy2(root/f'tests/replay_editor_workflow/{name}.gd',project/f'workflow_{name}.gd')
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json')}
for name in ['preview','workbench']:
 with (out/f'{name}.log').open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',f'workflow_{name}.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
 text=(out/f'{name}.log').read_text();assert f'REPLAY_WORKFLOW_{name.upper()}_OK' in text
 assert not any(x in text for x in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),text
 print('WORKFLOW_'+name.upper()+'_OK',flush=True)
(out/'result.json').write_text(json.dumps({'pass':True,'preview':True,'workbench':True},indent=2)+'\n')

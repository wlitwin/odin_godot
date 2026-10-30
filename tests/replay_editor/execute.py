from pathlib import Path
import os,subprocess,sys,json
root=Path(__file__).resolve().parents[2];work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'editor-checks';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json')}
cases=[('editor_registry.gd','REPLAY_EDITOR_REGISTRY_OK'),('editor_enemy_preview.gd','REPLAY_EDITOR_ENEMY_PREVIEW_OK'),('editor_runner_preview.gd','REPLAY_EDITOR_RUNNER_PREVIEW_OK'),('editor_hud_preview.gd','REPLAY_EDITOR_HUD_PREVIEW_OK'),('editor_authoring.gd','REPLAY_EDITOR_AUTHORING_OK'),('hud_test.gd','REPLAY_COMBAT_HUD_OK')]
for script,marker in cases:
 path=out/(script+'.log')
 with path.open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',script],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=90)
 text=path.read_text();assert marker in text,(script,marker)
 assert not any(token in text for token in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),script
 print(marker,flush=True)
(out/'result.json').write_text(json.dumps({'pass':True,'cases':[x[0] for x in cases]},indent=2)+'\n')
print('REPLAY_EDITOR_SCENES_OK')

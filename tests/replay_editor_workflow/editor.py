from pathlib import Path
import json,os,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2]
project=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
addon=project/'addons/replay_editor_test';addon.mkdir(exist_ok=False)
shutil.copy2(root/'tests/replay_editor_workflow/editor_probe.gd',addon/'plugin.gd')
(addon/'plugin.cfg').write_text('[plugin]\nname="Replay Editor Test"\ndescription="Isolated editor acceptance"\nauthor="tests"\nversion="1"\nscript="plugin.gd"\n')
settings=project/'project.godot';original=settings.read_text()
settings.write_text(original.replace('"res://addons/replay_authoring/plugin.cfg")','"res://addons/replay_authoring/plugin.cfg", "res://addons/replay_editor_test/plugin.cfg")'))
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'ODIN_GODOT_ROOT':str(root)}
try:
 with (out/'editor.log').open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--path',str(project),'--editor'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=360)
 text=(out/'editor.log').read_text()
 assert 'REPLAY_WORKFLOW_EDITOR_OK' in text and 'SCRIPT ERROR' not in text,text[-10000:]
finally:
 settings.write_text(original)
 # Disable the test plugin while retaining its source/logs for review.
print('REPLAY_EDITOR_UI_ACCEPTANCE_OK')

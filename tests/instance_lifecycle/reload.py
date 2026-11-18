from pathlib import Path
import os,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
WORK=Path(tempfile.mkdtemp(prefix='odin-instance-reload-')).resolve();PROJECT=WORK/'project'
shutil.copytree(Path(__file__).with_name('reload'),PROJECT)
env={k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL','ODIN_GODOT_ROOT'] and not k.startswith('BOX3D_')}
plugin=PROJECT/'addons/acceptance';plugin.mkdir(parents=True)
(plugin/'plugin.cfg').write_text('[plugin]\nname="Lifecycle reload check"\nscript="plugin.gd"\n')
(plugin/'plugin.gd').write_text('@tool\nextends EditorPlugin\nfunc _enter_tree():\n if OS.get_environment("LIFECYCLE_RELOAD_CHECK")=="1": call_deferred("run")\nfunc run(): add_child(load("res://test.gd").new())\n')
with (PROJECT/'project.godot').open('a') as f:f.write('[editor_plugins]\nenabled=PackedStringArray("res://addons/acceptance/plugin.cfg")\n')
env['ODIN_GODOT_ROOT']=str(ROOT)
godot=env.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
# Keep editor settings isolated from the developer's normal installation.
engine=WORK/'engine';engine.mkdir();original=Path(godot).resolve()
if original.parent.name=='MacOS' and original.parent.parent.name=='Contents':
 bundle=original.parents[2]
 subprocess.run(['/bin/cp','-c','-R',str(bundle),str(engine/bundle.name)],check=True)
 godot=str(engine/bundle.name/'Contents/MacOS'/original.name)
else:
 shutil.copy2(original,engine/original.name);godot=str(engine/original.name)
(engine/'_sc_').touch()
print('Instance reload evidence:',WORK,flush=True)
for name,args,marker in [('build',['bash',ROOT/'build/build_scripts.sh',PROJECT],'Built:'),('import',[godot,'--headless','--editor','--path',PROJECT,'--quit-after','60'],None),('reload',[godot,'--headless','--editor','--path',PROJECT],'INSTANCE_RELOAD_OK')]:
 with (WORK/(name+'.log')).open('w') as log:r=subprocess.run([str(x) for x in args],cwd=ROOT,env=dict(env,LIFECYCLE_RELOAD_CHECK="1" if name=="reload" else "0"),stdout=log,stderr=subprocess.STDOUT,timeout=180)
 text=(WORK/(name+'.log')).read_text(errors='replace');clean=text
 if name=='reload' and 'EXPECTED_EDITED_ROOT_VETO_BEGIN' in text:
  begin,end='EXPECTED_EDITED_ROOT_VETO_BEGIN','EXPECTED_EDITED_ROOT_VETO_END'
  part=text.split(begin,1)[1].split(end,1)[0]
  if part.count('ERROR:')!=1 or 'not supported inside the editor' not in part.lower():raise RuntimeError('wrong native veto: '+part)
  clean=text.split(begin,1)[0]+text.split(end,1)[1]
 if r.returncode or (marker and marker not in text) or any(x in clean for x in ['SCRIPT ERROR','\nERROR:','leaked at exit','resources still in use','ODIN_SCRIPT_PANIC']):
  print(text[-6000:]);raise RuntimeError(name+' failed: '+str(WORK))
 if name=='reload':
  before=text.split('INSTANCE_SAME_LAYOUT_PRESERVED',1)[0]
  if 'RELOAD_FINAL_' in before:raise RuntimeError('body reload finalized retained state')
  if 'ODIN_RELOAD_OWNED_LAYOUT_PINNED' not in text or 'RELOAD_FINAL_2' not in text or 'RELOAD_FINAL_3' not in text:raise RuntimeError('missing owned layout evidence')
 print(name,'PASS',flush=True)
print('INSTANCE_RELOAD_OK',WORK)

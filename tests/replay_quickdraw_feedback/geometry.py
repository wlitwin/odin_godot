from pathlib import Path
import os,re,shutil,subprocess,sys,json
out=Path(sys.argv[1]).resolve();project=out/'project';reference=Path(sys.argv[2]).resolve();root=Path(__file__).resolve().parents[2]
assert not (project/'reference').exists()
shutil.copytree(reference,project/'reference')
ext='dylib' if sys.platform=='darwin' else 'so';env=os.environ.copy();env['ODIN_SCRIPTS_DLL']=str(project/('bin/libodinscripts.'+ext))
with (out/'geometry.log').open('w') as log:
 child=subprocess.Popen([env['GODOT'],'--headless','--path',str(project),'--script',str(root/'tests/replay_quickdraw_feedback/geometry.gd')],env=env,stdout=log,stderr=subprocess.STDOUT)
 try:code=child.wait(timeout=20)
 finally:
  if child.poll() is None:
   child.terminate()
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
text=(out/'geometry.log').read_text();assert code==0 and 'RQ_GEOMETRY_OK' in text and not re.search(r'SCRIPT ERROR|ERROR:|leaked|still in use',text),text
print(text)

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(tempfile.mkdtemp(prefix='odin-kit-ui-web-')).resolve()
PROJECT = WORK / 'project'
PROJECT.mkdir()
source = Path(__file__).parent
shutil.copytree(source / 'scripts', PROJECT / 'scripts')
shutil.copytree(ROOT / 'kit/ui/templates', PROJECT / 'templates')
for name in ['project.godot','odin_godot.gdextension','web.gd']:
    shutil.copy2(source / name, PROJECT / name)
settings = (PROJECT / 'project.godot').read_text().replace('config/name="Kit UI Bindings"','config/name="Kit UI Bindings Web"\nrun/main_scene="res://main.tscn"')
(PROJECT / 'project.godot').write_text(settings)
(PROJECT / 'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://web.gd" id="1"]\n[node name="Test" type="Node"]\nscript=ExtResource("1")\n')
presets=(ROOT / 'tests/box3d_web/integration/project/export_presets.cfg').read_text().replace('variant/thread_support=true','variant/thread_support=false')
(PROJECT / 'export_presets.cfg').write_text(presets)
env = {k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL','ODIN_GODOT_ROOT','SCRIPT_BUILD_FLAGS'] and not k.startswith('BOX3D_')}
godot = env.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
print('Kit UI Web evidence:',WORK,flush=True)

def run(name,args):
    log = WORK / (name+'.log')
    with log.open('w') as stream:
        result=subprocess.run([str(x) for x in args],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
    text=log.read_text(errors='replace')
    if result.returncode or any(x in text for x in ['SCRIPT ERROR','\nERROR:','ODIN_SCRIPT_PANIC','leaked at exit','resources still in use']):
        print(text[-6000:]);raise RuntimeError(f'{name} failed: {log}')
    print(name,'PASS',flush=True)

run('build',['bash',ROOT/'build/build_scripts.sh',PROJECT])
run('import',[godot,'--headless','--editor','--path',PROJECT,'--quit-after','80'])
export=WORK/'export';export.mkdir()
run('export',[godot,'--headless','--path',PROJECT,'--export-release','Web',export/'index.html'])
# Observe public onExit and select Dummy audio for this UI-only fixture.
# Real audio startup/shutdown belongs to the separate game journey checks.
html=export/'index.html';text=html.read_text();assert text.count('engine.startGame({')==1
html.write_text(text.replace('engine.startGame({',"engine.startGame({\n'args': ['--audio-driver', 'Dummy'],\n'onExit': function(code) { window.__kit_ui_exit = code; },"))
class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        super().end_headers()
    def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(export)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    run('browser',['node',source/'drive.mjs','http://127.0.0.1:'+str(server.server_port)+'/index.html',WORK])
finally:
    server.shutdown();server.server_close()
assert json.loads((WORK/'report.json').read_text())['result']=='PASS'
print('KIT_UI_WEB_OK',WORK)

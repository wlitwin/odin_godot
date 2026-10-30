"""Exercise genuine previously compiled two-channel peers against the new adapter."""
import argparse,hashlib,json,os,signal,socket,subprocess,sys,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main(a):
 out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False);old=Path(a.legacy).resolve();build=json.loads((old/'browser-build.json').read_text())
 for rel,digest in build['binaries'].items():assert hashlib.sha256((old/rel).read_bytes()).hexdigest()==digest,rel
 with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
 log=(out/'http.log').open('w');server=subprocess.Popen(['bash',str(ROOT/'tests/web/serve.sh'),str(old/'replay/project/out'),str(port)],stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 try:
  url=f'http://127.0.0.1:{port}/index.html';deadline=time.monotonic()+15
  while True:
   try:
    with urllib.request.urlopen(url,timeout=1) as r:assert r.status==200
    break
   except OSError:assert server.poll() is None and time.monotonic()<deadline;time.sleep(.1)
  env={**os.environ,'GODOT':a.godot,'REPLAY_LOADED_LEGACY_MEMBER':str(a.member),'REPLAY_LOADED_LEGACY_URL':url,'REPLAY_LOADED_MODE':'planned','REPLAY_LOADED_RAW_TURN':'0','REPLAY_ICE_CONFIG':'','REPLAY_RELIABLE_HOLD':'0','REPLAY_RELIABLE_HOLD_AT_KILL':'0','REPLAY_RENDER_TRACE':'1'}
  (out/'legacy-provenance.json').write_text(json.dumps({'member':a.member,'legacy_build':str(old),'legacy_binaries':build,'mode':'planned','fault_layer':'messages'},indent=2)+'\n')
  game=subprocess.Popen(['bash',str(ROOT/'tests/replay_loaded_migration/execute.sh'),str(Path(a.current).resolve()),str(out/'game')],env=env,start_new_session=True)
  try:
   code=game.wait(timeout=300);assert code==0,code
  finally:
   if game.poll() is None:
    os.killpg(game.pid,signal.SIGTERM)
    try:game.wait(timeout=10)
    except subprocess.TimeoutExpired:os.killpg(game.pid,signal.SIGKILL);game.wait()
  subprocess.run([sys.executable,str(ROOT/'tests/replay_loaded_migration/control_report.py'),str(out/'game/browser'),'legacy'],check=True)
 finally:
  if server.poll() is None:os.killpg(server.pid,signal.SIGTERM);server.wait(timeout=10)
  log.close()
 print('REPLAY_LEGACY_CONTROL_COMPATIBLE',a.member)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--current',required=True);p.add_argument('--legacy',required=True);p.add_argument('--out',required=True);p.add_argument('--member',type=int,choices=[1,2],required=True);p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot');main(p.parse_args())

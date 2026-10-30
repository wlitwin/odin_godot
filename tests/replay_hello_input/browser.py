from pathlib import Path
import hashlib,json,os,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];build=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False);project=build/'project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'inputs.json').write_text(json.dumps({'export':{p.name:sha(p) for p in (project/'out').iterdir() if p.is_file()},'driver':sha(root/'tests/replay_hello_input/browser.mjs')},indent=2)+'\n')
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
with (out/'http.log').open('w') as log:
 server=subprocess.Popen(['bash',str(root/'tests/web/serve.sh'),str(project/'out'),str(port)],stdout=log,stderr=subprocess.STDOUT)
 try:
  time.sleep(.5)
  with (out/'driver.log').open('w') as driver:subprocess.run(['node',str(root/'tests/replay_hello_input/browser.mjs'),f'http://127.0.0.1:{port}/index.html',str(out/'browser')],stdout=driver,stderr=subprocess.STDOUT,check=True,timeout=60)
  assert json.loads((out/'browser/result.json').read_text())['pass'];print('REPLAY_HELLO_PAUSE_BROWSER_OK')
 finally:
  server.terminate()
  try:server.wait(timeout=5)
  except subprocess.TimeoutExpired:server.kill();server.wait()

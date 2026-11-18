"""Read current saved fixtures, then prove exact installation and continued play."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess
p=argparse.ArgumentParser()
p.add_argument('--project',type=Path,required=True);p.add_argument('--work',type=Path,required=True)
p.add_argument('--info',type=Path,required=True);p.add_argument('--godot',required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[2];work=a.work.resolve();project=a.project.resolve()
fixture=root/'tests/replay_scrapyard/fixtures/current';manifest=json.loads((fixture/'manifest.json').read_text())
library=Path(os.environ['ODIN_SCRIPTS_DLL']).resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();binary=sha(library)
receipts=[]
for row in manifest:
 source=root/row['target']
 if source.suffix!='.replay':continue
 assert sha(source)==row['target_sha256']
 name=source.stem;directory=work/('resume-'+name);directory.mkdir()
 result=subprocess.run([str(a.info),str(source),'protocol-upgrade-owner'],capture_output=True,text=True,check=True,timeout=30)
 expected=json.loads(result.stdout);(directory/'saved.json').write_text(json.dumps(expected)+'\n')
 env={k:v for k,v in os.environ.items() if not k.startswith(('RSY_','REPLAY_AUTO_'))}
 env.update(RSY_ROLE='solo',RSY_TOKEN='protocol-upgrade-owner',RSY_PERSIST='0',RSY_SAVE=str(source),RSY_RESULT_DIR=str(directory),RSY_RUN='0',RSY_ENCOUNTER='migration',RSY_SPRAY=str(directory/'absent.png'),RSY_RESUME='1')
 with (directory/'game.log').open('w') as log:
  run=subprocess.run([a.godot,'--headless','--path',str(project),'--script','save_test.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=55)
 text=(directory/'game.log').read_text()
 assert run.returncode==0 and 'RSY_SAVE_RESUME_OK' in text,text[-4000:]
 assert not re.search(r'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|REPLAY_SCRAPYARD_FAIL',text),text[-4000:]
 assert f"RSY_RUN_RESTORED tick={expected['tick']} epoch=2 hash={expected['hash']}" in text
 assert f"RSY_RUN_ASSETS_RESTORED count={expected['assets']} bytes={expected['asset_bytes']}" in text
 assert sha(source)==row['target_sha256']
 receipts.append(dict(name=name,**expected));print('CURRENT_FIXTURE_RESUMED',name,flush=True)
assert len(receipts)==8 and sha(library)==binary
(work/'receipts.json').write_text(json.dumps(dict(binary_sha256=binary,resumed=receipts),indent=2)+'\n')
print('REPLAY_SCRAPYARD_SAVED_FIXTURES_OK')

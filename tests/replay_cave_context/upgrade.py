from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2];tool=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
source=root/'tests/replay_cave_owner/fixtures/owner1/pending.checkpoint';before=hashlib.sha256(source.read_bytes()).hexdigest()
def run(label,source,target,success):
 previous=target.read_bytes() if target.exists() else None
 p=subprocess.run([str(tool),str(source),str(target)],capture_output=True,text=True,timeout=30)
 (out/f'{label}.log').write_text(p.stdout+p.stderr);assert (p.returncode==0)==success,p.stdout+p.stderr
 if not success:
  assert target.read_bytes()==previous if previous is not None else not target.exists()
 return p
target=out/'converted.checkpoint';run('converted',source,target,True)
run('existing',source,target,False)
run('already-current',target,out/'current.checkpoint',False)
bad=out/'corrupt.checkpoint';data=bytearray(source.read_bytes());data[-1]^=1;bad.write_bytes(data)
run('corrupt',bad,out/'bad-output.checkpoint',False)
assert hashlib.sha256(source.read_bytes()).hexdigest()==before
assert not list(out.glob('.replay-upgrade-*'))
(out/'result.json').write_text(json.dumps({'pass':True,'source_sha256':before,'converted_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'existing_and_corrupt_preserved':True},indent=2)+'\n')
print('REPLAY_CAVE_OWNER_UPGRADE_CLI_OK')

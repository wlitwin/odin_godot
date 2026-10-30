from pathlib import Path
import subprocess,json,hashlib,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();run=out/'upgraded';run.mkdir(exist_ok=False)
base=root/'docs/replay/results/network-recording-2026-09-14'
files=[base/'native/run/host.rplrec',base/'native/run/client.rplrec',base/'browser/run/downloads/scrapyard.rplrec'];results=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for index,source in enumerate(files):
 before=sha(source);target=run/f'{index}.rplrec'
 rejected=subprocess.run([str(out/'verify_recording'),str(source),'--content48'],capture_output=True,text=True,timeout=30);assert rejected.returncode==2,rejected.stdout+rejected.stderr
 converted=subprocess.run([str(out/'upgrade_recording'),str(source),str(target)],capture_output=True,text=True,timeout=30);(run/f'{index}-convert.log').write_text(converted.stdout+converted.stderr);assert converted.returncode==0,converted.stderr
 verified=subprocess.run([str(out/'verify_recording'),str(target),'--content48'],capture_output=True,text=True,timeout=30);(run/f'{index}-verify.log').write_text(verified.stdout+verified.stderr);assert verified.returncode==0,verified.stdout+verified.stderr
 after=sha(target);refused=subprocess.run([str(out/'upgrade_recording'),str(source),str(target)],capture_output=True,text=True,timeout=30);assert refused.returncode==1 and sha(target)==after
 assert sha(source)==before
 results.append({'source':str(source.relative_to(root)),'source_sha256':before,'converted_sha256':after,'verifier':verified.stdout.strip(),'source_preserved':True,'existing_destination_preserved':True});print(verified.stdout.strip(),flush=True)
(run/'result.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_NETWORK_RECORDING_UPGRADE_OK')

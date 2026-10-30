from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2];work=Path(sys.argv[1]).resolve();out=work/'browser'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((work/'web/prepared.json').read_text()).items():assert sha(work/'web/project'/name)==digest,name
for name,digest in json.loads((work/'game/framework.json').read_text()).items():assert sha(root/name)==digest,name
subprocess.run([sys.executable,str(root/'tests/replay_claimball_party_restore/execute.py'),str(work/'web'),str(work/'service'),str(out)],check=True)
text=(out/'browser/return-host.log').read_text()
for marker in ['RESTORE_REQUEST_DELAYED ms=2400','RESTORE_OLD_GRANT_PARKED epoch=2 head=0 ready=false','RESTORE_RENEWED_INSTALL epoch=2']:
 assert text.count(marker)==1,marker
summary=json.loads((out/'browser/summary.json').read_text());assert summary['pass'] and summary['restored']['epoch']==2
print('REPLAY_RESTORE_RENEWAL_BROWSER_OK')

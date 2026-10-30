"""Reuse a diagnostic build at its exact original paths after verifying inputs."""
from pathlib import Path
import json,hashlib,os,shutil,sys
source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();assert source!=out
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((source/'framework-source.json').read_text())
for name,h in base['sha256'].items():assert sha(Path(base['root'])/name)==h,('framework',name)
audit=json.loads((source/'audit-manifest.json').read_text())
assert audit.get('profile','endurance')==os.environ.get('REPLAY_INPUT_AUDIT_PROFILE','endurance'), 'audit profile mismatch'
assert audit.get('shots',False)==(os.environ.get('REPLAY_INPUT_AUDIT_SHOTS','0')=='1'), 'shot audit mismatch'
for name,change in audit['changes'].items():assert sha(source/name)==change['after'],('audit source',name)
for line in (source/'source-sha256.txt').read_text().splitlines():
 h,name=line.split('  ',1)
 if name not in audit['changes']:assert sha(source/name)==h,('project source',name)
build=json.loads((source/'build-manifest.json').read_text());assert build['flags']==['-debug','-o:speed']
for name,h in build['binaries'].items():assert sha(source/name)==h,('binary',name)
for name in ('replay','framework'):(out/name).symlink_to(source/name,target_is_directory=True)
for name in ('contract.json','framework-source.json','audit-manifest.json','source-sha256.txt','build-manifest.json'):shutil.copy2(source/name,out/name)
(out/'reuse.json').write_text(json.dumps({'source':str(source),'project':str(source/'replay/project'),'verified_framework_project_edits_and_binaries':True},indent=2)+'\n')

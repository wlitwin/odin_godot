"""Reuse exact verified binaries after preparing and comparing fresh source copies."""
from pathlib import Path
import hashlib,json,shutil,sys
source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def manifest(p):return {line.split('  ',1)[1]:line.split('  ',1)[0] for line in p.read_text().splitlines()}
assert source!=out
old=json.loads((source/'framework-source.json').read_text());new=json.loads((out/'framework-source.json').read_text());assert old==new
for name,value in old['sha256'].items():assert digest(Path(old['root'])/name)==value
before=manifest(source/'source-sha256.txt');after=manifest(out/'source-sha256.txt');assert before.keys()==after.keys()
for name,value in before.items():
 assert digest(source/name)==value,('old source changed',name)
 if not name.endswith('/project/comparison.gd'):assert value==after[name],('compiled source/content changed',name)
build=json.loads((source/'build-manifest.json').read_text())
assert build['flags']==['-debug','-o:speed']
for name,value in build['binaries'].items():assert digest(source/name)==value
for impl in ('kit','replay'):
 for name in ('bin','.godot'):shutil.copytree(source/impl/'project'/name,out/impl/'project'/name)
 for p in (source/impl/'project').rglob('*'):
  if p.is_file() and p.suffix in ('.import','.uid') and '.godot' not in p.parts:
   target=out/impl/'project'/p.relative_to(source/impl/'project');target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
 for name in ('build.log','import.log','build-wait.json','final-build.log'):shutil.copy2(source/impl/name,out/impl/name)
(out/'reuse.json').write_text(json.dumps({'source':str(source),'source_build':build,'compiled_sources_and_content_verified':True,'framework_and_binaries_verified':True,'uncompiled_changes':['comparison.gd','project.godot (fresh isolated namespace)'],'build_logs':'copied from source build'},indent=2)+'\n')
print('REPLAY_SWARM_BINARIES_REUSED')

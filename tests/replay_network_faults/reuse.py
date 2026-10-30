from pathlib import Path
import hashlib,json,shutil,sys
source,out=map(lambda p:Path(p).resolve(),sys.argv[1:3])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def manifest(p):return {line.split('  ',1)[1]:line.split('  ',1)[0] for line in p.read_text().splitlines()}
old=json.loads((source/'framework-source.json').read_text());new=json.loads((out/'framework-source.json').read_text());assert old==new
for name,value in old['sha256'].items():assert digest(Path(old['root'])/name)==value
before,after=manifest(source/'source-sha256.txt'),manifest(out/'source-sha256.txt');assert before.keys()==after.keys()
for name,value in before.items():
 assert digest(source/name)==value
 if name!='replay/project/comparison.gd':assert value==after[name],name
build=json.loads((source/'build-manifest.json').read_text());assert build['flags']==['-debug','-o:speed']
for name,value in build['binaries'].items():assert digest(source/name)==value
base=source/'replay/project';dest=out/'replay/project'
for name in ('bin','.godot'):shutil.copytree(base/name,dest/name)
for p in base.rglob('*'):
 if p.is_file() and p.suffix in ('.import','.uid') and '.godot' not in p.parts:
  target=dest/p.relative_to(base);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
for name in ('build.log','import.log','build-wait.json','final-build.log'):shutil.copy2(source/name,out/name)
(out/'reuse.json').write_text(json.dumps({'source':str(source),'binaries':build['binaries'],'compiled_sources_and_framework_verified':True,'uncompiled_changes':['comparison.gd','isolated project namespace']},indent=2)+'\n')
print('NETWORK_FAULT_BINARIES_REUSED')

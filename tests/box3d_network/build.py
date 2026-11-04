#!/usr/bin/env python3
"""Build test endpoints against an already verified frozen native archive."""
import argparse,hashlib,json,os,pathlib,shlex,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inventory(framework="both"):
 result={}
 directories=['box3d','replay','tests/box3d_network','tests/replay_physics_net/fixture'];directories+=['kit'] if framework!='replay' else []
 for directory in directories:
  for p in (ROOT/directory).rglob('*'):
   if p.is_file() and p.suffix in ('.odin','.c','.h','.py','.sh','.md','.json') and '__pycache__' not in p.parts:result[str(p.relative_to(ROOT))]=sha(p)
 return result

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--archive',required=True);ap.add_argument('--out',required=True);ap.add_argument('--odin',default=os.environ.get('ODIN','odin'));ap.add_argument('--schema',action='store_true');ap.add_argument('--framework',choices=['both','kit','replay'],default='both');a=ap.parse_args()
 archive=pathlib.Path(a.archive).resolve();out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=True);assert not (out/'endpoint-manifest.json').exists(),'immutable endpoint build output already exists'
 native=archive.parent/'build-manifest.json';data=json.loads(native.read_text());assert sha(archive)==data['archive_sha256']
 for path,digest in data['native_sources'].items():assert sha(ROOT/path)==digest,('native source mismatch',path)
 before=inventory(a.framework);cc=shlex.split(data['commands'][0]['command'])[0];commands=[]
 def run(command,name):
  commands.append(command)
  with (out/(name+'.log')).open('w') as log:subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 opt=['-O0','-g'] if data['configuration']=='Debug' else ['-O2','-g']
 run([cc,'-std=c17','-UNDEBUG','-fno-fast-math','-ffp-contract=off','-Wall','-Wextra',*opt,'-c',str(ROOT/'tests/box3d_network/common/socket.c'),'-o',str(out/'socket.o')],'socket-build')
 run(['ar','rcs',str(out/'socket.a'),str(out/'socket.o')],'socket-archive')
 binaries={}
 for framework in (('kit','replay') if a.framework=='both' else (a.framework,)):
  modes=[False,True] if framework=='replay' and a.schema else [False]
  for variant in modes:
   name=framework+('-schema' if variant else '')
   command=[a.odin,'build',str(ROOT/'tests/box3d_network'/framework),'-collection:godot='+str(ROOT),'-define:BOX3D_LIBRARY='+str(archive),'-define:BOX3D_NETWORK_SOCKET_LIBRARY='+str(out/'socket.a'),'-out:'+str(out/name)]
   if data['configuration']=='Release':command+=['-o:speed']
   if variant:command+=['-define:BOX3D_NETWORK_SCHEMA_VARIANT=true']
   run(command,name+'-build');binaries[name]={'path':str(out/name),'sha256':sha(out/name)}
 after=inventory(a.framework);assert before==after,'endpoint source changed during build; rerun coherent build'
 manifest={'schema_version':1,'native_archive':str(archive),'native_archive_sha256':sha(archive),'native_manifest':str(native),'native_manifest_sha256':sha(native),'configuration':data['configuration'],'machine':data['machine'],'sources':before,'commands':commands,'binaries':binaries,'transport':'bounded real local TCP framing; test-only logical channel impairment'}
 (out/'endpoint-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out/'endpoint-manifest.json')
if __name__=='__main__':main()

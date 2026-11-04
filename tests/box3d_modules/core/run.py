#!/usr/bin/env python3
"""Independent pure host ABI + native-linked Core service controls."""
import argparse,hashlib,json,pathlib,shutil,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--native-dir',required=True);p.add_argument('--out',required=True);p.add_argument('--odin',default='odin');p.add_argument('--cc',default='clang');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[3];out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False);native=pathlib.Path(a.native_dir).resolve();records=[]
def run(name,cmd):
 r=subprocess.run(cmd,cwd=repo,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(out/(name+'.log')).write_bytes(r.stdout);records.append({'name':name,'argv':cmd,'exit_code':r.returncode,'log_sha256':hashlib.sha256(r.stdout).hexdigest()})
 if r.returncode: (out/'results.json').write_text(json.dumps(records,indent=2));sys.stdout.buffer.write(r.stdout);raise SystemExit(r.returncode)
 return r.stdout
run('c-abi-build',[a.cc,'-std=c17','-Ibox3d/godot','tests/box3d_modules/core/protocol_test.c','-o',str(out/'protocol-layout')]);layout=json.loads(run('c-abi-reference',[str(out/'protocol-layout')]))
identity=dict(x.split('=',1) for x in (native/'native-domain-identity.txt').read_text().splitlines()[:2]);common=['-collection:godot=.',f'-define:BOX3D_LIBRARY={native}/libogb3.a','-define:ODIN_TEST_THREADS=1']
run('registry',[a.odin,'test','tests/box3d_modules/core',*common,f'-out:{out}/registry-tests'])
for name,strict,reject in [('protocol-standalone',False,False),('protocol-strict',True,False),('protocol-old-build',True,True),('protocol-old-target',True,True)]:
 flags=[f'-define:HOST_PROTOCOL_FINGERPRINT={layout["fingerprint"]}',f'-define:BOX3D_REQUIRE_DOMAIN={str(strict).lower()}',f'-define:TEST_EXPECTED_REJECT={str(reject).lower()}',f'-define:BOX3D_EXPECTED_BUILD=sha256:{"f"*64 if name=="protocol-old-build" else identity["build"]}',f'-define:BOX3D_EXPECTED_TARGET=sha256:{"f"*64 if name=="protocol-old-target" else identity["target"]}']
 run(name,[a.odin,'test','tests/box3d_modules/core/protocol',*common,*flags,f'-out:{out}/{name}'])
report={'result':'PASS','layout':layout,'commands':records,'native_archive_sha256':hashlib.sha256((native/'libogb3.a').read_bytes()).hexdigest(),'identity':identity}
(out/'results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

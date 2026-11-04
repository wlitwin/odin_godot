#!/usr/bin/env python3
"""One compile/test of two public admission arms; no scriptgen or Godot."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

repo=Path(__file__).resolve().parents[4]
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
native=Path('/tmp/odin-box3d-goal-t4jbbj4v/box3d-native-count-once-v1/cache/build/Release/libogb3.a')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(native)=='6a6a19edc5f9c4023229155a4822630f3ea58e6363fd91be7100a10b00ef898f'
def sources():
    roots=['kit','box3d','replay/schema','examples/box3d_common',
           'tests/kit_box3d_net','tests/replay_physics_net/fixture',
           'tests/box3d_soak/kit/input_admission']
    return dict(sorted((str(p.relative_to(repo)),sha(p)) for root in roots
                       for p in (repo/root).rglob('*') if p.is_file()
                       and p.suffix in ('.odin','.py') and '__pycache__' not in p.parts))
before=sources();(out/'sources-before.json').write_text(json.dumps(before,sort_keys=True)+'\n')
command=['nix','develop',str(repo),'--command','odin','test',
         str(repo/'tests/box3d_soak/kit/input_admission'),'-collection:godot='+str(repo),
         '-define:ODIN_TEST_THREADS=1','-define:BOX3D_LIBRARY='+str(native),
         '-o:speed','-debug','-extra-linker-flags:-lc++','-keep-executable',
         '-out:'+str(out/'input-admission')]
with (out/'test.log').open('x') as log:
    completed=subprocess.run(command,cwd=out,stdout=log,stderr=subprocess.STDOUT)
after=sources();(out/'sources-after.json').write_text(json.dumps(after,sort_keys=True)+'\n')
records=[]
for line in (out/'test.log').read_text().splitlines():
    if line.startswith('KIT_INPUT_ADMISSION '):records.append(json.loads(line.split(' ',1)[1]))
arms=[r for r in records if 'name' in r]
files={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in out.glob('*.bin')}
report=dict(schema=1,scope='generic4_static_native9c66_nil_owner_public_Session_Lane_memory_queue_no_timing',
            argv=command,exit_code=completed.returncode,source_fence_unchanged=before==after,
            source_manifest_sha256=sha(out/'sources-after.json'),
            native_archive=str(native),native_archive_sha256=sha(native),
            native_manifest_sha256=sha(native.with_name('build-manifest.json')),
            binary_sha256=sha(out/'input-admission') if (out/'input-admission').exists() else None,
            records=records,files=files,ok=completed.returncode==0 and before==after and len(arms)==2)
(out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(report=str(out/'report.json'),report_sha256=sha(out/'report.json'),
                     exit_code=completed.returncode,ok=report['ok']),indent=2))
sys.exit(0 if report['ok'] else 1)

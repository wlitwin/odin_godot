#!/usr/bin/env python3
"""Build a scene with the existing helpers and bind exact sources to its binaries."""
from pathlib import Path
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time

from run import ROOT, source_manifest, sha
from accept import tree_manifest
from evidence import json_bytes, require

ODIN_WRAPPER = '''#!/usr/bin/env python3
import json,os,subprocess,sys
with open(os.environ['GATE_B_COMPILER_CALLS'],'a') as stream:
    stream.write(json.dumps({'argv':sys.argv[1:]})+chr(10))
raise SystemExit(subprocess.run([os.environ['GATE_B_REAL_ODIN'],*sys.argv[1:]]).returncode)
'''


def verify_example_copy(project, framework, manifest):
    prefix='examples/'+framework+'_box3d/'
    for name,expected in manifest.items():
        if name.startswith(prefix) and '.gen.odin' not in Path(name).name:
            copied=project/name[len(prefix):]
            require(copied.is_file() and sha(copied)==expected,
                    'consumed example copy differs from pre-copy source manifest: '+name)
    return True


def group_running(group):
    rows=subprocess.check_output(['ps','-axo','pid=,pgid=,stat='],text=True)
    return any(len(fields)==3 and int(fields[1])==group and not fields[2].startswith('Z')
               for fields in (line.split() for line in rows.splitlines()))


def signal_owned_group(group, sig):
    try:os.killpg(group,sig)
    except ProcessLookupError:pass
    except PermissionError:
        # Darwin may retain an empty/zombie group briefly after TERM. Never
        # dismiss a permission failure if an owned writer is still running.
        if group_running(group):raise


def run_owned_command(argv, *, cwd, env, output, timeout):
    """Own a new POSIX process group, including nested helper/compiler children."""
    child=subprocess.Popen(argv,cwd=cwd,env=env,stdin=subprocess.DEVNULL,
        stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
    timed_out=False
    try:
        code=child.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out=True
        # Keep the leader unreaped until the group is stopped. Only the new
        # group this call owns is signalled; no process-name/global kill.
        signal_owned_group(child.pid,signal.SIGTERM)
        time.sleep(0.25)
        if group_running(child.pid):signal_owned_group(child.pid,signal.SIGKILL)
        child.wait(timeout=5)
        code=None
    leftover=group_running(child.pid)
    if leftover:
        # Even a successful shell cannot certify files while an unjoined
        # compiler/helper remains. Stop only this owned group and reject it.
        signal_owned_group(child.pid,signal.SIGKILL)
        time.sleep(0.05)
    require(not group_running(child.pid),'build still has an owned running writer')
    return dict(exit_code=code,timed_out=timed_out,owned_process_group=child.pid,
                leftover_owned_children=leftover)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--framework',choices=('kit','replay'),required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--native',type=Path,required=True)
    p.add_argument('--odin',default='odin')
    p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot')
    a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    project=out/'project'
    source=ROOT/'examples'/(a.framework+'_box3d')
    before=source_manifest(a.framework)
    (out/'sources-before.json').write_bytes(json_bytes(before)+b'\n')
    shutil.copytree(source,project,ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin','*.gen.odin.uid','__pycache__'))
    copy_verified=verify_example_copy(project,a.framework,before)
    real_odin=Path(shutil.which(a.odin) or a.odin).resolve()
    calls=out/'compiler-calls.jsonl'
    wrapper=out/'record-odin.py'
    wrapper.write_text(ODIN_WRAPPER)
    wrapper.chmod(0o755)
    env={k:v for k,v in os.environ.items() if not k.startswith('B3_')}
    env.update(ROOT=str(ROOT),ODIN_GODOT_ROOT=str(ROOT),ODIN=str(wrapper),
        GATE_B_REAL_ODIN=str(real_odin),GATE_B_COMPILER_CALLS=str(calls),
        SKIP_CORE='1',SCRIPT_BUILD_FLAGS='-o:speed',BOX3D_NATIVE_LIBRARY=str(a.native.resolve()),
        BOX3D_RUNTIME_DIR=str(project/'bin'))
    suffix='.dylib' if sys.platform=='darwin' else '.so'
    commands=[
        ['bash',str(ROOT/'build/build_scripts.sh'),str(project)],
        ['bash','-c','source "$ROOT/build/common.sh"; atomic_odin_dll "$ROOT/core" "$BOX3D_RUNTIME_DIR/libodin_godot'+suffix+'" -o:speed -debug'],
        [sys.executable,str(ROOT/'build/box3d_profile.py'),'--prepare-import',str(project)],
        [a.godot,'--headless','--path',str(project),'--import'],
    ]
    steps=[];failure=None
    try:
        require(a.native.is_file(),'explicit Native library missing')
        require(real_odin.is_file(),'explicit Odin compiler missing')
        for index,argv in enumerate(commands):
            log=out/f'build-{index}.log'
            with log.open('xb') as stream:
                result=run_owned_command(argv,cwd=ROOT,env=env,output=stream,timeout=300)
            code=result['exit_code']
            steps.append(dict(argv=argv,**result,log=str(log),sha256=sha(log)))
            require(code==0 and not result['leftover_owned_children'],
                    ('scene build/import failed or left an unjoined writer',index,code,str(log)))
        actual_calls=[json.loads(line)['argv'] for line in calls.read_text().splitlines()]
        for target in (ROOT/'core',project/'scripts'):
            require(any(argv[:2]==['build',str(target)] and '-o:speed' in argv and '-debug' in argv
                        for argv in actual_calls),('explicit speed/debug compiler call not observed',str(target)))
    except Exception as error:
        failure=repr(error)
    after=source_manifest(a.framework)
    (out/'sources-after.json').write_bytes(json_bytes(after)+b'\n')
    changed=[name for name in set(before)|set(after) if before.get(name)!=after.get(name)]
    if changed:failure=failure or 'production sources changed during build'
    record=dict(schema=1,result='FAIL' if failure else 'PASS',framework=a.framework,
        project=str(project),exit_code=steps[-1]['exit_code'] if steps else None,error=failure,
        source_manifest=str(out/'sources-after.json'),source_manifest_sha256=sha(out/'sources-after.json'),
        source_fence_unchanged=not changed,source_changes=changed,
        consumed_example_source_copy_verified=copy_verified,
        frozen_project_files=tree_manifest(project),steps=steps,
        configuration='Odin speed+debug / explicit supplied Native configuration',
        compiler=dict(path=str(real_odin),sha256=sha(real_odin) if real_odin.is_file() else None),
        compiler_calls=dict(path=str(calls),sha256=sha(calls) if calls.exists() else None),
        supplied_native=dict(path=str(a.native.resolve()),sha256=sha(a.native) if a.native.is_file() else None),
        environment={name:env[name] for name in ('SKIP_CORE','SCRIPT_BUILD_FLAGS','BOX3D_NATIVE_LIBRARY')},
        generated_sources={str(f.relative_to(project)):sha(f) for f in (project/'scripts').glob('*.gen.odin')})
    (out/'build-record.json').write_bytes(json_bytes(record)+b'\n')
    print(json.dumps(dict(result=record['result'],record=str(out/'build-record.json'),error=failure)))
    return 0 if record['result']=='PASS' else 1


if __name__=='__main__':raise SystemExit(main())

#!/usr/bin/env python3
"""Run the real next-job button during a standard Native Host/Client session."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('dockyard_pair_helpers', ROOT / 'tests/box3d_samples/run.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)
spec = importlib.util.spec_from_file_location('dockyard_round_assessment', HERE / 'assess_pair.py')
assessment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assessment)


def project_fence(before, after, pids):
    pattern = r'(bin/libodinscripts[^/]*\.(dylib|so|dll))\.r([0-9]+)\.p([0-9]+)\.\2'
    prior, added = {}, {}
    for name, value in before.items():
        match = re.fullmatch(pattern,name)
        if match and before.get(match[1]) == value:
            prior[name] = dict(source=match[1],pid=int(match[4]),sha256=value)
    for name in after.keys()-before.keys():
        match = re.fullmatch(pattern,name)
        if match and int(match[4]) in pids and before.get(match[1]) == after[name]:
            added[name] = dict(source=match[1],pid=int(match[4]),sha256=after[name])
    valid = (all(after.get(name) == value for name,value in before.items() if name not in prior)
             and all(name not in after or after[name] == item['sha256'] for name,item in prior.items())
             and set(after)-set(before) == set(added))
    return valid,dict(prior=prior,added=added)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--build-record', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--ticks', type=int, default=3600)
    parser.add_argument('--execute', action='store_true')
    args = parser.parse_args()
    out, project = args.out.resolve(), args.project.resolve()
    if out.is_relative_to(ROOT) or not 1024 <= args.port <= 65535 or not 3600 <= args.ticks <= 10800:
        parser.error('fresh outside output, valid port and3600..10800ticks required')
    out.mkdir(parents=True,exist_ok=False)
    if not args.execute:
        (out/'plan.json').write_text(json.dumps(dict(result='STAGED_ONLY',runtime_jobs_started=0))+'\n')
        return 0
    build = json.loads(args.build_record.read_text())
    assessment.check(build['result']=='PASS' and Path(build['project']).resolve()==project and build['actual_build_exit']==0,'actual ordinary SDK build binding')
    for name,digest in build['actual_binaries_sha256'].items():
        assessment.check(shared.sha(project/name)==digest,'exact current compiled SDK binary')
    before = shared.project_files(project)
    script = HERE/'retry.gd'
    bindings = dict(script_sha256=shared.sha(script),godot_sha256=shared.sha(args.godot),build_sha256=shared.sha(args.build_record),controller_sha256=shared.sha(Path(__file__)))
    actors, errors = [], []
    argv = [args.godot,'--headless','--path',str(project),'--script',str(script)]
    error = None
    try:
        for role in ['host','client']:
            folder = out/role;folder.mkdir()
            env = os.environ.copy()
            env.update(BOX3D_SAMPLE_ROLE=role,BOX3D_SAMPLE_PORT=str(args.port),BOX3D_SAMPLE_TICKS=str(args.ticks),BOX3D_SAMPLE_SCRIPTED='1',BOX3D_SAMPLE_OUTPUT=str(folder))
            suffix = 'dylib' if os.uname().sysname=='Darwin' else 'so'
            env['ODIN_SCRIPTS_DLL']=str(project/'bin'/('libodinscripts.'+suffix))
            actors.append(shared.Actor(role,argv,env,folder))
        deadline = time.monotonic()+args.ticks/60+60
        for actor in actors:
            actor.process.wait(timeout=max(.01,deadline-time.monotonic()))
            actor.thread.join(timeout=max(.01,deadline-time.monotonic()))
            assessment.check(actor.process.returncode==0 and not actor.thread.is_alive() and actor.error is None,'actual natural process success/EOF')
    except Exception as exception:
        error = repr(exception)
    finally:
        if error:
            for actor in actors:
                try: actor.kill_owned_group()
                except ProcessLookupError: pass
                except OSError as exception: errors.append(repr(exception))
        for actor in actors:
            try: actor.process.wait(timeout=10)
            except Exception as exception: errors.append(repr(exception))
            actor.thread.join(timeout=10)
    valid,copies = project_fence(before,shared.project_files(project),{a.process.pid for a in actors})
    valid = valid and bindings['script_sha256']==shared.sha(script) and bindings['godot_sha256']==shared.sha(args.godot) and bindings['build_sha256']==shared.sha(args.build_record) and bindings['controller_sha256']==shared.sha(Path(__file__))
    report = dict(result='PASS' if error is None and valid and not errors else 'FAIL',error=error,framework='replay',target=args.ticks,argv=argv,
                  project_fence=valid,cleanup_errors=errors,bindings=bindings,module_copies=copies,
                  actors=[dict(role=a.role,pid=a.process.pid,actual_exit=a.process.returncode,intake_drained=not a.thread.is_alive(),intake_error=a.error,
                               log=str(a.folder/'godot.log'),log_sha256=shared.sha(a.folder/'godot.log'),events=a.rows) for a in actors])
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    try:
        result = assessment.native(out,retry=True)
    except Exception as exception:
        result = dict(result='FAIL',error=repr(exception))
    (out/'game-assessment.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(dict(result=result['result'],report=str(out/'report.json'),assessment=str(out/'game-assessment.json'),error=result.get('error',error))))
    return 0 if result['result']=='PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())

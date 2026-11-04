#!/usr/bin/env python3
"""Example-owned, bounded real Godot rejoin probe; observation-only controller."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def records(path):
    result = []
    if path.exists():
        for line in path.read_text().splitlines():
            if line.startswith('{'):
                try:
                    result.append(json.loads(line))
                except json.JSONDecodeError:
                    pass  # A running process may not have completed its last line.
    return result


def one(items, kind):
    found = [x for x in items if x.get('event') == kind]
    assert len(found) == 1, (kind, len(found))
    return found[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--project', type=Path, help='existing coherently built/imported Kit project to copy; never rebuilt here')
    parser.add_argument('--port', type=int, default=43131)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    args.stage.mkdir(parents=True, exist_ok=False)
    project = args.stage / 'project'
    source_project = (args.project or repo / 'examples/kit_box3d').resolve()
    shutil.copytree(source_project, project,
                    ignore=shutil.ignore_patterns('*.dSYM', '*.r*.dylib', '.odin_crash.log'))
    processes, streams = {}, {}
    library_ext = '.dylib' if sys.platform == 'darwin' else '.so'
    canonical_libraries = [project/'bin'/(name+library_ext)
                           for name in ('libodin_godot','libodinscripts','libogb3')]
    binary_before = {p.name:sha(p) for p in canonical_libraries}
    report = {'result': 'FAIL', 'scope': 'focused Kit example two-process client teardown/rejoin',
              'control_truth_injection': False, 'coherent_build_claim': False,
              'source_project': str(source_project), 'build_performed_by_controller': False,
              'binaries': binary_before,
              'source': {str(p.relative_to(project)): sha(p) for p in (project/'scripts').glob('*.odin')}}

    def note(value):
        with (args.stage / 'control.jsonl').open('a') as out:
            out.write(json.dumps(value, sort_keys=True) + '\n')

    def launch(label, role, extra):
        output = args.stage / ('host' if role == 'host' else 'client')
        output.mkdir(exist_ok=True)
        env = os.environ.copy()
        native_ext = '.dylib' if sys.platform == 'darwin' else '.so'
        env['ODIN_SCRIPTS_DLL'] = str(project/'bin'/('libodinscripts'+native_ext))
        env.update(B3_ROLE=role, B3_PORT=str(args.port), B3_TOKEN='101' if role == 'host' else '202',
                   B3_ADDRESS='127.0.0.1', B3_SEED='1', B3_BODIES='4', B3_TICKS='240',
                   B3_END_TICK='360', B3_SCRIPTED='1', B3_EXPECT_OBSERVERS='0', B3_OUTPUT=str(output))
        env.update(extra)
        streams[label] = (args.stage/(label+'.log')).open('w')
        process = subprocess.Popen([args.godot, '--headless', '--max-fps', '60', '--path', str(project)],
                                   env=env, stdout=streams[label], stderr=subprocess.STDOUT)
        processes[label] = process
        note({'event': 'SPAWN', 'label': label, 'pid': process.pid, 'env': {k:v for k,v in env.items() if k.startswith('B3_')}})

    try:
        with (args.stage/'prepare-profile.log').open('w') as log:
            prepared = subprocess.run([sys.executable, str(repo/'build/box3d_profile.py'), '--prepare-import', str(project)],
                                      stdout=log, stderr=subprocess.STDOUT, timeout=30)
        assert prepared.returncode == 0, 'profile import preparation failed'
        with (args.stage/'prepared-import.log').open('w') as log:
            imported = subprocess.run([args.godot, '--headless', '--path', str(project), '--import'],
                                      stdout=log, stderr=subprocess.STDOUT, timeout=45)
        assert imported.returncode == 0, 'prepared import failed'
        assert 'ERROR:' not in (args.stage/'prepared-import.log').read_text(), 'prepared import Godot error'
        assert {p.name:sha(p) for p in canonical_libraries} == binary_before, 'import rebuilt or replaced supplied libraries'
        launch('host', 'host', {})
        launch('source-client', 'client', {'B3_EXIT_AT': '80', 'B3_GENERATION': '1'})
        deadline = time.monotonic() + 60
        opened = False
        while time.monotonic() < deadline:
            for label in processes:
                assert 'ERROR:' not in (args.stage/(label+'.log')).read_text(), (label, 'Godot error')
            host = records(args.stage/'host.log')
            old = records(args.stage/'source-client.log')
            if not opened and processes['source-client'].poll() is not None:
                assert processes['source-client'].returncode == 0, 'source client failed'
                ready, exited = one(old, 'READY'), one(old, 'SESSION_EXIT')
                assert exited['ok'] and all(exited[k] == 0 for k in ('engine_live', 'wrapper_live', 'meter_live', 'cleanup_errors'))
                left = [x for x in host if x.get('event') == 'PLAYER_LEFT' and x['player'] == ready['me']]
                if left:
                    note({'event': 'SOURCE_ZERO_AND_AUTHORITY_LEFT_OBSERVED', 'source_exit': exited, 'authority_left': left[-1], 'ready': ready})
                    launch('fresh-client', 'client', {'B3_GENERATION': '2', 'B3_SOURCE_GEN': '1', 'B3_EXIT_AT': '0',
                           'B3_TICKS': '32', 'B3_EXPECT_PLAYER': str(ready['me']), 'B3_EXPECT_PLAYER1': str(ready['players'][0]),
                           'B3_EXPECT_PLAYER2': str(ready['players'][1]), 'B3_EXPECT_SEAT': str(ready['seat']),
                           'B3_EXPECT_EPOCH': str(ready['epoch'])})
                    opened = True
            if opened and all(p.poll() is not None for p in processes.values()):
                break
            if processes['host'].poll() is not None:
                assert opened, 'authority exited before actual rejoin'
            time.sleep(.01)
        assert opened and all(p.poll() is not None for p in processes.values()), 'bounded rejoin timeout'
        assert all(p.returncode == 0 for p in processes.values()), 'child exit failure'
        all_records = {label: records(args.stage/(label+'.log')) for label in processes}
        for label, rs in all_records.items():
            text = (args.stage/(label+'.log')).read_text()
            assert not any(x in text for x in ('ERROR:', 'SCRIPT ERROR:', 'SIGSEGV', 'SIGABRT')), label
            ending = one(rs, 'SESSION_EXIT' if label == 'source-client' else 'RESULT')
            assert ending['ok'] and all(ending[k] == 0 for k in ('engine_live', 'wrapper_live', 'meter_live', 'cleanup_errors')), label
        host, old, fresh = [all_records[x] for x in ('host','source-client','fresh-client')]
        before, after = one(old, 'READY'), one(fresh, 'READY')
        assert all(before[k] == after[k] for k in ('token','me','seat','players','epoch'))
        assert after['baseline'] >= one(old, 'SESSION_EXIT')['tick'] and 360-after['baseline'] >= 32
        admitted, accepted = one(host, 'REJOIN_ADMITTED'), one(host, 'REJOIN_ACCEPTED')
        assert admitted['same_identity'] and accepted['matched'] and not accepted['inherited_ack']
        assert admitted['old_peer'] != admitted['peer'] == accepted['peer']
        assert admitted['player'] == accepted['player'] == before['me']
        assert admitted['token_hash'] == accepted['from_token_hash'] and accepted['incarnation'] == 2
        assert accepted['baseline'] == after['baseline']
        sys.path.insert(0, str(repo/'tests/box3d_slices/harness'))
        import evidence as e
        frames = {label: {x['tick']: e.load_frame(args.stage/('host' if label=='host' else 'client'), x)
                         for x in rs if x.get('event')=='FRAME'} for label, rs in all_records.items()}
        compared = []
        for tick, actual in frames['fresh-client'].items():
            expected = frames['host'][tick]
            assert actual.sig == expected.sig and actual.parts() == expected.parts()
            compared.append(tick)
        assert 360 in compared and len(compared) >= 2
        semantic = lambda x: tuple(x[k] for k in ('epoch','tick','serial','lifetime','seat','kind','key'))
        future_fx = [x for x in host if x.get('event')=='FX' and x['tick']>after['baseline']]
        actual_fx = [x for x in fresh if x.get('event')=='FX']
        assert future_fx and [semantic(x) for x in future_fx] == [semantic(x) for x in actual_fx]
        assert len({x['key'] for x in actual_fx}) == len(actual_fx)
        decision = lambda x: tuple(x[k] for k in ('epoch','tick','seat','kind','applied','origin','sequence','accepted'))
        expected_actions = [x for x in host if x.get('event')=='APPLIED' and x['tick']>after['baseline']]
        actual_actions = [x for x in fresh if x.get('event')=='APPLIED']
        assert expected_actions and [decision(x) for x in expected_actions] == [decision(x) for x in actual_actions]
        report.update(result='PASS', before=before, after=after, admitted=admitted, accepted=accepted,
                      compared_ticks=compared, future_ticks=360-after['baseline'], future_fx=len(actual_fx),
                      future_decisions=len(actual_actions), no_recovery_claim=not any(x.get('event')=='RECOVERED' for x in fresh))
    except Exception as error:
        report['error'] = repr(error)
    finally:
        for label, process in processes.items():
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
            streams[label].close()
        report['exits'] = {label:p.returncode for label,p in processes.items()}
        report['logs'] = {label:sha(args.stage/(label+'.log')) for label in processes}
        report['binaries_after'] = {p.name:sha(p) for p in canonical_libraries if p.is_file()}
        report['binaries_unchanged'] = report['binaries_after'] == binary_before
        if not report['binaries_unchanged']:
            report.update(result='FAIL',error='supplied libraries changed during the controller run')
        (args.stage/'report.json').write_text(json.dumps(report, sort_keys=True, indent=2)+'\n')
    print(json.dumps({'result':report['result'], 'error':report.get('error'), 'stage':str(args.stage)}))
    return 0 if report['result']=='PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())

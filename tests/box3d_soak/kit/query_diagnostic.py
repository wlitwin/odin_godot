#!/usr/bin/env python3
"""Prepare/build an allowlisted CURRENT Example scratch observer. Never run it."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import os
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
OWN = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tests/box3d_soak/controller'))
from build import run_owned_command, ODIN_WRAPPER
from run import source_manifest

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def manifest(folder):
    return {str(p.relative_to(folder)): sha(p) for p in sorted(folder.rglob('*'))
            if p.is_file() and not any(part in ('bin', '.godot', '__pycache__') for part in p.parts)
            and '.gen.' not in p.name and not p.name.endswith('.dSYM')
            and str(p.relative_to(folder))!='scripts/diagnostic_input.odin.uid'}

def dump(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

def patch_runtime(original):
    changes = [
        (' impairment:Scene_Impairment,\n}',
         ' impairment:Scene_Impairment,\n input_diagnostic:Input_Diagnostic,\n}'),
        (' rt:=new(Runtime,alloc);rt.sdk=sdk;rt.allocator=alloc;rt.node=node;rt.role=role;rt.created_at=n.now_s();rt.generation=generation',
         ' diagnostic_allocation_before,diagnostic_allocation_status:=bm.stats(sdk.memory)\n'
         ' rt:=new(Runtime,alloc);rt.sdk=sdk;rt.allocator=alloc;rt.node=node;rt.role=role;rt.created_at=n.now_s();rt.generation=generation\n'
         ' input_diagnostic_allocation(rt,diagnostic_allocation_before,diagnostic_allocation_status)'),
        ('  capture_ingress(rt)\n  _=k.lane_frame(&rt.lane,0)\n  observe_recovered(rt)',
         '  capture_ingress(rt)\n  input_diagnostic_before_ingest(rt,delta)\n'
         '  diagnostic_ingest_steps:=k.lane_frame(&rt.lane,0)\n'
         '  input_diagnostic_after_ingest(rt,delta,diagnostic_ingest_steps)\n  observe_recovered(rt)'),
        (' dt:=min(delta,2.0/60)\n',
         ' dt:=min(delta,2.0/60)\n diagnostic_after_catchup:=dt\n'),
        (' if !rt.ses.is_host {available:=u64(8)-min(u64(8),rt.lane.ticker.tick-k.lane_world_confirmed(&rt.lane));dt=min(dt,f64(available)/60)}\n rt.diagnostic_dt=dt\n _=k.lane_frame(&rt.lane,dt)\n intent_published(rt)',
         ' diagnostic_after_target:=dt\n'
         ' if !rt.ses.is_host {available:=u64(8)-min(u64(8),rt.lane.ticker.tick-k.lane_world_confirmed(&rt.lane));dt=min(dt,f64(available)/60)}\n'
         ' input_diagnostic_before_normal(rt,delta,diagnostic_after_catchup,diagnostic_after_target,dt)\n'
         ' rt.diagnostic_dt=dt\n diagnostic_normal_steps:=k.lane_frame(&rt.lane,dt)\n'
         ' input_diagnostic_after_normal(rt,diagnostic_normal_steps)\n intent_published(rt)'),
        ('runtime_destroy :: proc(rt:^Runtime,final:bool=true)->bool {\n if rt==nil {return true}\n context.allocator=rt.allocator\n',
         'runtime_destroy :: proc(rt:^Runtime,final:bool=true)->bool {\n if rt==nil {return true}\n context.allocator=rt.allocator\n input_diagnostic_summary(rt,"close")\n'),
    ]
    text = original
    for before, after in changes:
        if text.count(before) != 1:
            raise ValueError('Current Runtime anchor is absent/ambiguous; refuse stale fallback: ' + before[:70])
        text = text.replace(before, after, 1)
    reverse = text
    for before, after in reversed(changes):
        if reverse.count(after) != 1:
            raise ValueError('Instrumented Runtime reverse proof failed')
        reverse = reverse.replace(after, before, 1)
    if reverse != original:
        raise ValueError('Original runtime bytes not preserved by reverse allowlist')
    return text, changes

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    out = args.out.resolve(); out.mkdir(parents=True, exist_ok=False)
    project = out / 'project'; source = ROOT / 'examples/kit_box3d'
    original_tree = manifest(source); shared_before = source_manifest('kit')
    dump(out/'production-example-before.json', original_tree)
    dump(out/'shared-before.json', shared_before)
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('bin', '.godot', '*.gen.odin', '*.gen.odin.uid', '__pycache__'))
    original = (source/'scripts/runtime.odin').read_text()
    text, changes = patch_runtime(original)
    (project/'scripts/runtime.odin').write_text(text)
    template = OWN/'query_diagnostic/diagnostic_input.odin'
    helper = template.read_text()
    forbidden = ('lane_frame(', 'lane_world_request_reset(', 'world_step(', 'now_s(', 'tick_now(', 'session_app_', 'wire_send(', 'world_restore(', 'intent_sample(', 'intent_rebase(')
    if any(word in helper for word in forbidden):
        raise ValueError('Diagnostic helper contains a forbidden mutation/clock path')
    shutil.copy2(template, project/'scripts/diagnostic_input.odin')
    copied_tree = manifest(project)
    difference = sorted(k for k in original_tree.keys() | copied_tree.keys() if original_tree.get(k) != copied_tree.get(k))
    if difference != ['scripts/diagnostic_input.odin', 'scripts/runtime.odin']:
        raise ValueError(('copy diff outside allowlist', difference))
    diff = ''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile='CURRENT/scripts/runtime.odin', tofile='COPY/scripts/runtime.odin'))
    (out/'runtime-allowlisted.patch').write_text(diff)
    dump(out/'copied-authored-before-build.json', copied_tree)
    static = dict(status='COPY_ONLY_STATIC_DIFF_PASS', original_tree_sha256=sha(out/'production-example-before.json'),
        copied_tree_sha256=sha(out/'copied-authored-before-build.json'), differences=difference,
        runtime_diff_sha256=sha(out/'runtime-allowlisted.patch'), runtime_reverse_proof=True,
        exact_replacement_count=len(changes), production_runtime_unchanged=sha(source/'scripts/runtime.odin')==original_tree['scripts/runtime.odin'],
        protected_files_identical=all(copied_tree[k]==v for k,v in original_tree.items() if k!='scripts/runtime.odin'),
        helper_sha256=sha(template), no_run=True)
    dump(out/'static-diff-record.json', static)
    if args.prepare_only:
        print(json.dumps(static)); return 0
    native = args.native.resolve()
    real_odin = Path(shutil.which('odin')).resolve()
    calls = out/'compiler-calls.jsonl'; wrapper = out/'record-odin.py'
    wrapper.write_text(ODIN_WRAPPER); wrapper.chmod(0o755)
    env = {k:v for k,v in os.environ.items() if not k.startswith('B3_')}
    env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), ODIN=str(wrapper), GATE_B_REAL_ODIN=str(real_odin),
        GATE_B_COMPILER_CALLS=str(calls), SKIP_CORE='1', SCRIPT_BUILD_FLAGS='-o:speed', BOX3D_NATIVE_LIBRARY=str(native), BOX3D_RUNTIME_DIR=str(project/'bin'))
    commands = [
        ['bash', str(ROOT/'build/build_scripts.sh'), str(project)],
        ['bash', '-c', 'source "$ROOT/build/common.sh"; atomic_odin_dll "$ROOT/core" "$BOX3D_RUNTIME_DIR/libodin_godot.dylib" -o:speed -debug'],
        [sys.executable, str(ROOT/'build/box3d_profile.py'), '--prepare-import', str(project)],
        [args.godot, '--headless', '--path', str(project), '--import'],
    ]
    steps=[]; failure=None
    try:
        for index, argv in enumerate(commands):
            path=out/f'build-{index}.log'
            with path.open('xb') as log:
                result=run_owned_command(argv,cwd=ROOT,env=env,output=log,timeout=300)
            steps.append(dict(argv=argv,**result,log=str(path),sha256=sha(path)))
            if result['exit_code'] != 0 or result['leftover_owned_children']:
                raise ValueError(('build/import failed or left writer', index, result))
        actual=[json.loads(line)['argv'] for line in calls.read_text().splitlines()]
        for target in (ROOT/'core',project/'scripts'):
            if not any(call[:2]==['build',str(target)] and '-o:speed' in call and '-debug' in call for call in actual):
                raise ValueError('Explicit speed+debug compile not recorded: '+str(target))
    except Exception as error:
        failure=repr(error)
    shared_after=source_manifest('kit'); prod_after=manifest(source)
    dump(out/'shared-after.json',shared_after); dump(out/'production-example-after.json',prod_after)
    if shared_before != shared_after or original_tree != prod_after:
        failure=failure or 'Production source changed during transaction'
    authored_after=manifest(project)
    if copied_tree != authored_after:
        failure=failure or 'Copied authored input changed during build/import'
    record=dict(schema=1,result='FAIL' if failure else 'PASS',scope='COPY_ONLY_OBSERVATIONAL_NOT_RUN',error=failure,
        project=str(project),static_diff=static,source_fence_unchanged=shared_before==shared_after and original_tree==prod_after,
        copied_authored_fence_unchanged=copied_tree==authored_after,steps=steps,
        compiler_calls=dict(path=str(calls),sha256=sha(calls) if calls.exists() else None),
        configuration='Odin speed+debug / Native Release explicit supplied',native_source_sha256=sha(native),
        generated_sources={str(p.relative_to(project)):sha(p) for p in (project/'scripts').glob('*.gen.odin')},
        generated_helper_uid=sha(project/'scripts/diagnostic_input.odin.uid') if (project/'scripts/diagnostic_input.odin.uid').exists() else None,
        binary_hashes={p.name:sha(p) for p in (project/'bin').glob('*.dylib')},
        production_shared_manifest_sha256=sha(out/'shared-after.json'),no_actual_diagnostic_run=True)
    dump(out/'build-record.json',record)
    print(json.dumps(dict(result=record['result'],record=str(out/'build-record.json'),error=failure)))
    return 0 if not failure else 1

if __name__=='__main__':
    raise SystemExit(main())

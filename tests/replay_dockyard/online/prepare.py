#!/usr/bin/env python3
"""Prepare a source-bound menu automation project and the existing room service."""
import argparse
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('integration', ROOT/'tests/box3d_web/integration/run.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--export-record',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--service-record',type=Path,help='Reuse the sealed unchanged service from an earlier actual preparation')
    p.add_argument('--live-game',action='store_true',help='Ordinary SDK build from current authored source before adding the test-only autoload')
    p.add_argument('--odin',required=True)
    p.add_argument('--godot',required=True)
    p.add_argument('--emcc',required=True)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    original=json.loads(a.export_record.read_text())
    if original['result']!='EXPORTED_BROWSER_PENDING':raise ValueError('successful ordinary export required')
    project=out/'project';service=out/'service'
    ignore=shutil.ignore_patterns('.godot','__pycache__','*.p*.dylib','*.p*.so')
    if a.live_game:
        prior_sdk=json.loads((a.export_record.parent/'sdk/report.json').read_text())
        args=['python3','-B',str(ROOT/'examples/replay_dockyard/prepare.py'),'--out',str(out/'sdk'),'--native-library',prior_sdk['native_library'],'--sqlite-library',os.environ['REPLAY_SQLITE_LIBRARY'],'--odin',a.odin,'--godot',a.godot,'--build']
        with (out/'live-sdk.log').open('xb') as log:
            code=subprocess.run(args,stdout=log,stderr=subprocess.STDOUT,timeout=600).returncode
        if code:raise RuntimeError('ordinary current SDK build failed; live-sdk.log retained')
        project=out/'sdk/project'
    else:
        shutil.copytree(original['project'],project,ignore=ignore)
    prior_service=None
    if a.service_record:
        prior_service=json.loads(a.service_record.read_text())
        if prior_service['result']!='EXPORTED_BROWSER_PENDING':raise ValueError('successful prior preparation required')
        prior=Path(prior_service['service'])
        for name,digest in prior_service['service_binaries'].items():
            if re.fullmatch(r'bin/libodinscripts[^/]*\.dylib\.r[0-9]+\.p[0-9]+\.dylib',name):continue
            if shared.sha(prior/name)!=digest:raise ValueError('prior service binary changed: '+name)
        shutil.copytree(prior,service,ignore=ignore)
    else:
        shutil.copytree(ROOT/'examples/replay_room_service',service,ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin','*.uid'))
    bridge=Path(__file__).with_name('bridge.gd');shutil.copy2(bridge,project/'n1_bridge.gd')
    settings=project/'project.godot';before=shared.sha(settings)
    if 'N1Bridge="*res://n1_bridge.gd"' not in settings.read_text():
        settings.write_text(settings.read_text()+'\n[autoload]\nN1Bridge="*res://n1_bridge.gd"\n')
    sdk=json.loads((a.export_record.parent/'sdk/report.json').read_text())
    native=Path(sdk['native_library'])
    if shared.sha(native)!=original.get('native_sha256',sdk['native_sha256']):raise ValueError('original Native input changed')
    env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(ROOT),ROOT=str(ROOT),ODIN=a.odin,GODOT=a.godot,EMCC=a.emcc,
      BOX3D_NATIVE_LIBRARY=str(native),BOX3D_WEB_ARCHIVE=os.environ['BOX3D_WEB_ARCHIVE'],BOX3D_WEB_DEBUG_NAMES='1')
    env.pop('SCRIPT_BUILD_FLAGS',None)
    sqlite=Path(os.environ['REPLAY_SQLITE_LIBRARY']).resolve(strict=True)
    if sqlite.suffix!='.a' or any(c.isspace() for c in str(sqlite)):raise ValueError('explicit static SQLite archive required')
    report=dict(result='FAIL',steps=[],original_export_record=str(a.export_record),original_export_sha256=shared.sha(a.export_record),
      sqlite_library=str(sqlite),sqlite_sha256=shared.sha(sqlite),driver_sha256=shared.sha(Path(__file__)),bridge_sha256=shared.sha(bridge),settings_before=before,settings_after=shared.sha(settings),project=str(project),service=str(service))
    if a.live_game:
        report['game_sdk_record']=str(out/'sdk/report.json');report['game_sdk_record_sha256']=shared.sha(out/'sdk/report.json')
    try:
        # Replay's aggregate native package imports the Box3D adapter. Select
        # the exact supplied shared artifact rather than an absent default .a.
        service_env=env.copy();service_env.pop('BOX3D_WEB_ARCHIVE',None)
        service_env['SCRIPT_BUILD_FLAGS']='-define:REPLAY_SQLITE_LIBRARY='+str(sqlite)
        if prior_service is None:
            shared.command(out,'service-build',['bash',str(ROOT/'build/build_scripts.sh'),str(service)],service_env,report)
            shared.command(out,'service-import',[a.godot,'--headless','--editor','--path',str(service),'--quit-after','120'],service_env,report)
            shared.command(out,'service-final',['bash',str(ROOT/'build/build_scripts.sh'),str(service)],service_env,report)
        else:
            report['service_reused_record']=str(a.service_record)
            report['service_reused_record_sha256']=shared.sha(a.service_record)
        shared.command(out,'prepare-import',['python3',str(ROOT/'build/box3d_profile.py'),'--prepare-import',str(project)],env,report)
        shared.command(out,'import',[a.godot,'--headless','--editor','--path',str(project),'--quit-after','120'],env,report)
        (out/'export').mkdir()
        shared.command(out,'export',[a.godot,'--headless','--path',str(project),'--export-release','Web',str(out/'export/index.html')],env,report)
        report.update(result='EXPORTED_BROWSER_PENDING',export_files={str(f.relative_to(out/'export')):shared.sha(f) for f in (out/'export').rglob('*') if f.is_file()},
          service_binaries={str(f.relative_to(service)):shared.sha(f) for f in (service/'bin').iterdir() if f.is_file()},
          scope='Derived project adds only the source-bound test bridge autoload. Same authored game; ordinary exporter. Runtime acceptance separate.')
    except Exception as e:report['error']=repr(e)
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(result=report['result'],error=report.get('error'),report=str(out/'report.json'))))
    return 0 if report['result']=='EXPORTED_BROWSER_PENDING' else 1

if __name__=='__main__':raise SystemExit(main())

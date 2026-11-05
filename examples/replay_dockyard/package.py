#!/usr/bin/env python3
"""Package verified ordinary export bytes for review; never deploy or admit them."""
import argparse
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import shutil
import tempfile
from urllib.parse import urlencode, urlsplit

ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path(__file__).resolve().parent
LIMIT_FILES=4096
LIMIT_BYTES=512*1024*1024

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def files(directory):
    if directory.is_symlink() or not directory.is_dir():raise ValueError('regular input directory required')
    result={}
    for p in sorted(directory.rglob('*')):
        if p.is_symlink():raise ValueError('symlink inputs are not packaged')
        if p.is_file():result[str(p.relative_to(directory))]=sha(p)
        elif not p.is_dir():raise ValueError('non-regular input')
    return result
def read_record(path):
    if path.is_symlink() or not path.is_file():raise ValueError('regular JSON record required')
    return json.loads(path.read_text())
def arm64_dylib(path):
    with path.open('rb') as f:header=f.read(8)
    return header[:4]==b'\xcf\xfa\xed\xfe' and int.from_bytes(header[4:8],'little')==0x0100000c
def native_allowed(relative):
    parts=relative.parts
    if any(x in parts for x in ['__pycache__','.git']):return False
    if parts[0]=='.godot':
        return len(parts)==2 and parts[1] in ['extension_list.cfg','global_script_class_cache.cfg','uid_cache.bin','.gdignore'] or len(parts)>2 and parts[1]=='imported'
    if parts[0]=='bin':
        return len(parts)==2 and (parts[1]=='box3d-runtime.json' or parts[1].endswith('.dylib') and '.r' not in parts[1] and '.p' not in parts[1])
    if parts[0] in ['content','audio','addons','modules','scripts']:
        return not relative.name.endswith(('.gen.odin','.sqlite','.sqlite3','.db','.pem','.key'))
    return len(parts)==1 and relative.name in ['project.godot','odin_godot.gdextension','main.tscn','view.gd','feedback.gd','web_text_entry.gd','web_runtime.gd','launch.py','CONTRIBUTING.md']

SERVE='''#!/usr/bin/env python3
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import argparse
class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        for key,value in [('Cross-Origin-Opener-Policy','same-origin'),('Cross-Origin-Embedder-Policy','require-corp'),('Cross-Origin-Resource-Policy','same-origin')]:self.send_header(key,value)
        super().end_headers()
def main():
    p=argparse.ArgumentParser(description='Serve this candidate locally with required isolation headers; room service is separate.');p.add_argument('--port',type=int,default=8080);a=p.parse_args()
    if not 1024<=a.port<=65535:p.error('port must be1024..65535')
    root=Path(__file__).resolve().parent/'web'
    with ThreadingHTTPServer(('127.0.0.1',a.port),partial(Handler,directory=str(root))) as server:
        print(f'Local candidate: http://127.0.0.1:{a.port}/index.html (configure a compatible room service)',flush=True);server.serve_forever()
if __name__=='__main__':main()
'''

def collect(export_record,qualification_report,include_native,godot_notices=None):
    record=read_record(export_record);export=export_record.parent/'export'
    if record.get('result')!='EXPORTED_BROWSER_PENDING':raise ValueError('successful ordinary export record required')
    if files(export)!=record.get('export_files'):raise ValueError('ordinary export bytes differ from their record')
    selected=[(export/name,Path('web')/name,expected) for name,expected in record['export_files'].items()]
    custom=record.get('custom_web_template')
    if custom:
        template_path=Path(custom['record']);read_record(template_path)
        if sha(template_path)!=custom['record_sha256']:raise ValueError('custom template record pin differs')
        helper=ROOT/'build/web_rtc_template.py'
        spec=importlib.util.spec_from_file_location('dockyard_rtc_template',helper)
        template_tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(template_tool)
        template=template_tool.verify(template_path)
        if custom['selection']['template_sha256']!=template['template']['sha256']:raise ValueError('selected custom template differs')
        for target,source in [('index.js','godot.js'),('index.wasm','godot.wasm'),('index.side.wasm','godot.side.wasm')]:
            if record['export_files'].get(target)!=template['entry_sha256'][source]:raise ValueError('export differs from custom template payload')
        selected += [(helper,Path('reproduce/web_rtc_template.py'),sha(helper)),
            (template_path,Path('reproduce/template-record.json'),sha(template_path))]
    if godot_notices is not None:
        notice_path=godot_notices/'godot-compiled-notices.json';notice=read_record(notice_path)
        license_path=godot_notices/'godot-license.txt'
        if (license_path.is_symlink() or not license_path.is_file() or not license_path.read_text().strip()
                or not notice.get('version') or not notice.get('copyright_info') or not notice.get('license_info')):
            raise ValueError('complete compiled Godot notices required')
        selected += [(license_path,Path('licenses/godot-license.txt'),sha(license_path)),
            (notice_path,Path('licenses/godot-compiled-notices.json'),sha(notice_path))]
    for p in (SOURCE/'deploy').rglob('*'):
        if '__pycache__' in p.parts or p.suffix=='.pyc':continue
        if p.is_symlink():raise ValueError('symlink operator template')
        if p.is_file():selected.append((p,Path('operator')/p.relative_to(SOURCE/'deploy'),sha(p)))
    selected += [(ROOT/'LICENSE',Path('licenses/odin-godot.txt'),sha(ROOT/'LICENSE')),
        (ROOT/'NOTICE',Path('licenses/odin-godot-NOTICE.txt'),sha(ROOT/'NOTICE')),
        (ROOT/'box3d/native/THIRD_PARTY_NOTICES.txt',Path('licenses/box3d-third-party.txt'),sha(ROOT/'box3d/native/THIRD_PARTY_NOTICES.txt')),
        (SOURCE/'audio/PROVENANCE.md',Path('licenses/audio-provenance.md'),sha(SOURCE/'audio/PROVENANCE.md')),
        (qualification_report,Path('qa/qualification.json'),sha(qualification_report))]
    native=None
    if include_native:
        project=Path(record['project']).resolve(strict=True)
        native=read_record(project/'bin/box3d-runtime.json')
        if native.get('target')!='macos' or native.get('domain',{}).get('pointer_bits')!=64:raise ValueError('this frozen Native SDK handoff is macOS ARM64 only')
        library=project/'bin/libogb3.dylib'
        if sha(library)!=native['deployed_library_sha256']:raise ValueError('Native deployment bytes differ')
        for p in project.rglob('*'):
            relative=p.relative_to(project)
            if not native_allowed(relative):continue
            if p.is_symlink():raise ValueError('symlink Native input')
            if p.is_file():
                if relative.parts[0]=='bin' and p.suffix=='.dylib' and not arm64_dylib(p):raise ValueError('thin ARM64 SDK library required')
                selected.append((p,Path('native-macos-arm64')/relative,sha(p)))
        for name in ['libodin_godot.dylib','libodinscripts.dylib','libodinscripts_dockyard.dylib','libogb3.dylib']:
            if not (project/'bin'/name).is_file():raise ValueError('incomplete frozen Native SDK')
    destinations=[str(p) for _,p,_ in selected]
    if len(set(destinations))!=len(destinations):raise ValueError('duplicate package path')
    if len(selected)>LIMIT_FILES or sum(p.stat().st_size for p,_,_ in selected)>LIMIT_BYTES:raise ValueError('package bounds exceeded')
    return record,selected,native

def package(export_record,out,qualification_report,include_native=False,runtime_report=None,godot_notices=None):
    if out.exists() or out.is_symlink():raise ValueError('choose a new output directory')
    if out.is_relative_to(ROOT):raise ValueError('output must be outside the repository')
    out=out.parent.resolve()/out.name
    if out.is_relative_to(ROOT):raise ValueError('output parent resolves inside the repository')
    record,selected,native=collect(export_record,qualification_report,include_native,godot_notices)
    qualification=read_record(qualification_report)
    runtime=None;cohort=None
    if runtime_report is not None:
        runtime=read_record(runtime_report);binding=read_record(runtime_report.parent/'export-binding.json')
        if runtime.get('all_five_byte_equal') is not True or binding.get('actual_exit')!=0 or binding.get('export_record_sha256')!=sha(export_record) or binding.get('export_unchanged') is not True:raise ValueError('matching actual runtime record required for cohort')
        cohort=runtime.get('host',{}).get('cohort')
        if not isinstance(cohort,str) or not re.fullmatch('[0-9a-f]{16}',cohort) or runtime.get('client',{}).get('cohort')!=cohort:raise ValueError('actual common Web cohort missing')
    out.parent.mkdir(parents=True,exist_ok=True)
    staging=Path(tempfile.mkdtemp(prefix='.'+out.name+'-',dir=out.parent));created=False
    try:
        for source,relative,expected in selected:
            target=staging/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
            if sha(source)!=expected or sha(target)!=expected:raise ValueError('input changed while copying')
        (staging/'serve-web.py').write_text(SERVE)
        if cohort:
            template=staging/'operator/service.env.example';text=template.read_text()
            if text.count('REPLAY_ROOM_CONTENT=\n')!=1:raise ValueError('operator cohort placeholder mismatch')
            template.write_text(text.replace('REPLAY_ROOM_CONTENT=\n','REPLAY_ROOM_CONTENT=0x'+cohort+'\n'))
            (staging/'qa/runtime-summary.json').write_text(json.dumps({'result':runtime.get('result'),'all_five_byte_equal':True,'web_cohort':cohort,'runtime_report_sha256':sha(runtime_report),'release_admitted':False},indent=2)+'\n')
        (staging/'README.txt').write_text('''DOCKYARD DUO — UNRELEASED REVIEW CANDIDATE

Public Internet acceptance and two-human co-op review remain open.
Read qa/qualification.json for this exact build's performance verdict.
No room service, TURN credentials, private databases, browser profiles or TLS
private keys are included. The operator files are templates, not a deployment.

Web: python3 serve-web.py --port 8080
Open http://127.0.0.1:8080/index.html?service=ENCODED_COMPATIBLE_WSS_URL&relay=1
Configure and run the separate compatible Replay Room service and TURN relay.
For public hosting, use HTTPS/WSS and the headers in operator/Caddyfile.

Native (when included): requires Godot4.7.1 on macOS ARM64, bundle floor14.0.
python3 native-macos-arm64/launch.py host --project native-macos-arm64 --godot GODOT_BIN
python3 native-macos-arm64/launch.py client --project native-macos-arm64 --godot GODOT_BIN
This is a frozen SDK project with its runtime import cache, not a signed app
or an Intel/universal SDK. Editing/rebuilding needs the source repository/tools.

WASD/arrows move; aim+hold mouse pulls cargo; Space boosts; F2 settings;
Escape crew/leave; F3 diagnostics. Host shares Copy Invite; recipient uses Join.
Release cargo in its matching bay and allow two seconds to latch. At results,
host selects NEXT JOB. Native/Web crossplay is not qualified.

Verify all packaged bytes with examples/replay_dockyard/package.py verify
from the source repository. Do not publish this review package as qualified.
''')
        deployed_url=qualification.get('deployed_service',{}).get('url')
        if deployed_url:
            endpoint=urlsplit(deployed_url)
            if (endpoint.scheme!='wss' or not endpoint.hostname or endpoint.username is not None
                    or endpoint.password is not None or endpoint.query or endpoint.fragment):
                raise ValueError('qualification service endpoint must be a credential-free WSS URL')
            with (staging/'README.txt').open('a') as instructions:
                instructions.write('\nDeployed review Room service: '+deployed_url+'\n')
                instructions.write('After starting the local server, open:\nhttp://127.0.0.1:8080/index.html?'+urlencode({'service':deployed_url,'relay':'1'})+'\n')
        if record.get('custom_web_template'):
            (staging/'reproduce/README.txt').write_text('''The template record retains original build paths as provenance.
To reproduce the ZIP in a new directory, use the exact installed official
Godot 4.7.1 web_dlink_release.zip with its recorded SHA256:

python3 reproduce/web_rtc_template.py derive --source /PATH/web_dlink_release.zip --out /NEW/OUTPUT/DIRECTORY

The new template record has new paths; the derived ZIP SHA256 must match
template-record.json. Only godot.js changes. Both official engine Wasm
payloads remain byte-identical. Rebuilding the game extension/PCK also needs
the source repository and the toolchain documented there.
''')
        payload=files(staging)
        manifest={'schema_version':1,'result':'CANDIDATE_PACKAGED_NOT_RELEASED','release_admitted':False,
            'qualification_result':qualification.get('result'),'qualification_sha256':sha(qualification_report),
            'package_tool_sha256':sha(Path(__file__)),
            'export_record_sha256':sha(export_record),'web_native_archive_sha256':record.get('web_archive_sha256'),
            'custom_web_template_record_sha256':record.get('custom_web_template',{}).get('record_sha256'),
            'web_cohort':cohort,'runtime_report_sha256':sha(runtime_report) if runtime_report else None,
            'native_scope':'macOS ARM64 frozen SDK project, no signed/universal app claim' if native else None,
            'native_domain':native.get('domain') if native else None,'files':payload,
            'excluded':['test bridge','browser profiles','enrollment databases','credentials','TLS private keys','PID reload copies','editor user state'],
            'limits':{'files':LIMIT_FILES,'bytes':LIMIT_BYTES},'processes_started':0,'external_deployment_performed':False}
        (staging/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        # Reserve a new destination before moving any payload into it. An
        # incomplete interrupted directory has no valid manifest/verification.
        out.mkdir();created=True
        for p in staging.iterdir():shutil.move(str(p),str(out/p.name))
        verify(out)
        return manifest
    except BaseException:
        if created:shutil.rmtree(out)
        raise
    finally:shutil.rmtree(staging,ignore_errors=True)

def verify(directory,manifest_sha256=None):
    if manifest_sha256 is not None and sha(directory/'manifest.json')!=manifest_sha256:raise ValueError('candidate manifest pin differs')
    manifest=read_record(directory/'manifest.json')
    if manifest.get('schema_version')!=1 or manifest.get('result')!='CANDIDATE_PACKAGED_NOT_RELEASED' or manifest.get('release_admitted') is not False:raise ValueError('unsupported candidate manifest')
    actual=files(directory);actual.pop('manifest.json',None)
    if actual!=manifest.get('files'):raise ValueError('candidate package bytes differ')
    return manifest

def main():
    parser=argparse.ArgumentParser(description=__doc__);commands=parser.add_subparsers(dest='command',required=True)
    p=commands.add_parser('collect');p.add_argument('--export-record',type=Path,required=True);p.add_argument('--runtime-report',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--qualification-report',type=Path,default=ROOT/'tests/replay_dockyard/online/current-handoff-status.json');p.add_argument('--include-native-sdk',action='store_true');p.add_argument('--godot-notices',type=Path)
    v=commands.add_parser('verify');v.add_argument('--package',type=Path,required=True);v.add_argument('--manifest-sha256');a=parser.parse_args()
    try:
        if a.command=='collect':r=package(a.export_record.resolve(strict=True),a.out.absolute(),a.qualification_report.resolve(strict=True),a.include_native_sdk,a.runtime_report.resolve(strict=True),a.godot_notices);print(json.dumps({'result':r['result'],'package':str(a.out.absolute()),'manifest_sha256':sha(a.out/'manifest.json'),'files':len(r['files']),'release_admitted':False}))
        else:r=verify(a.package.resolve(strict=True),a.manifest_sha256);print(json.dumps({'result':'CANDIDATE_BYTES_VALID','files':len(r['files']),'release_admitted':False}))
        return 0
    except (ValueError,OSError,KeyError,json.JSONDecodeError) as error:print(json.dumps({'result':'REJECTED','error':str(error)}));return 2
if __name__=='__main__':raise SystemExit(main())

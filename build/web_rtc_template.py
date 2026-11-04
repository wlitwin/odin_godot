#!/usr/bin/env python3
"""Derive/select the pinned Godot 4.7.1 RTC scratch-buffer Web template.

Only godot.js changes. Engine Wasm, side Wasm and other template payloads retain
their original bytes. The scratch backing store is bounded to 64 KiB per engine
JavaScript module; views are transient and no peer/frame data is retained.
Official installed templates and already exported games are never modified.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROFILE = 'godot4.7.1-web-dlink-rtc-scratch-v1'
SOURCE_SHA = '3d9a4f7963759b31d9bc19fffe0991b7348eeeb970187c9f09bbf1aa843a0c6c'
JS_SHA = '878c9ae7fb3c27ce886faea8da0670dc1a97fb93930fac4b433a1bb56e662d3a'
FUNCTION_SHA = '136788a75549a37ff40a77539fc3a6c64ed017177b3a15c68f48771734c76f4d'
FUNCTION_START = b'function _godot_js_rtc_datachannel_send('
FUNCTION_END = b'_godot_js_rtc_datachannel_send.sig='
INSERT_BEFORE = b'const bytes_array=new Uint8Array(p_length);'
# Godot's worker proxy and stock fallback remain outside this inserted branch.
# A nested send uses the original path, preserving the outer borrowed view.
SCRATCH = (
    b'if(p_raw&&Number.isInteger(p_buffer)&&Number.isInteger(p_length)'
    b'&&p_buffer>=0&&p_length>=0&&p_length<=65536&&p_buffer+p_length<=HEAPU8.length){'
    b'const scratch=GodotRTCDataChannel._odin_send_scratch_v1||'
    b'(GodotRTCDataChannel._odin_send_scratch_v1={bytes:new Uint8Array(65536),busy:false});'
    b'if(!scratch.busy){scratch.busy=true;try{'
    b'const view=scratch.bytes.subarray(0,p_length);'
    b'view.set(HEAPU8.subarray(p_buffer,p_buffer+p_length));ref.send(view);return 0'
    b'}finally{scratch.busy=false}}}'
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def patched_js(data):
    if digest(data) != JS_SHA:
        raise ValueError('unsupported template JavaScript identity')
    if data.count(FUNCTION_START) != 1 or data.count(FUNCTION_END) != 1:
        raise ValueError('ambiguous RTC send function')
    start, end = data.index(FUNCTION_START), data.index(FUNCTION_END)
    function = data[start:end]
    if digest(function) != FUNCTION_SHA or function.count(INSERT_BEFORE) != 1:
        raise ValueError('RTC send preimage differs')
    function = function.replace(INSERT_BEFORE, SCRATCH + INSERT_BEFORE, 1)
    return data[:start] + function + data[end:]


def source_payloads(source):
    if sha(source) != SOURCE_SHA:
        raise ValueError('unsupported official template ZIP identity')
    with zipfile.ZipFile(source) as archive:
        infos = archive.infolist()
        if len({i.filename for i in infos}) != len(infos):
            raise ValueError('duplicate template entries')
        payloads = {i.filename: archive.read(i) for i in infos}
    payloads['godot.js'] = patched_js(payloads['godot.js'])
    if sha(source) != SOURCE_SHA:
        raise ValueError('template source changed while reading')
    return infos, payloads


def derive(source, output):
    source, output = source.resolve(strict=True), output.resolve()
    if output.exists():
        raise FileExistsError(output)
    if output.is_relative_to(ROOT):
        raise ValueError('choose a new template output outside this repository')
    infos, payloads = source_payloads(source)
    output.mkdir(parents=True, exist_ok=False)
    target = output / 'web_dlink_release.rtc-scratch-v1.zip'
    with zipfile.ZipFile(target, 'x') as archive:
        for info in infos:
            archive.writestr(info, payloads[info.filename])
    record = dict(schema_version=1, result='DERIVED_TEMPLATE', profile=PROFILE,
        godot_version='4.7.1.stable', helper_sha256=sha(Path(__file__)),
        source=dict(path=str(source), sha256=SOURCE_SHA, javascript_sha256=JS_SHA,
                    rtc_send_function_sha256=FUNCTION_SHA),
        template=dict(path=str(target), sha256=sha(target)),
        entry_sha256={name: digest(data) for name, data in payloads.items()},
        changed_entries=['godot.js'], scratch_backing_bytes_max=65536,
        scratch_lifetime='One backing store per loaded engine JavaScript module; no per-peer/frame growth.',
        scope='Pinned custom Web template derivation only; runtime and performance acceptance separate')
    record_path = output / 'template-record.json'
    record_path.write_text(json.dumps(record, indent=2) + '\n')
    verify(record_path)
    return record_path, record


def verify(record_path):
    record = json.loads(record_path.read_text())
    if (record.get('result') != 'DERIVED_TEMPLATE' or record.get('profile') != PROFILE
            or record.get('helper_sha256') != sha(Path(__file__))):
        raise ValueError('unsupported template record or helper identity')
    if record['source']['sha256'] != SOURCE_SHA:
        raise ValueError('recorded template source identity differs')
    infos, expected = source_payloads(Path(record['source']['path']).resolve(strict=True))
    target = Path(record['template']['path']).resolve(strict=True)
    if sha(target) != record['template']['sha256']:
        raise ValueError('derived template ZIP identity differs')
    with zipfile.ZipFile(target) as archive:
        if archive.namelist() != [i.filename for i in infos]:
            raise ValueError('derived template inventory differs')
        actual = {i.filename: archive.read(i.filename) for i in infos}
    hashes = {name: digest(data) for name, data in expected.items()}
    if actual != expected or record['entry_sha256'] != hashes:
        raise ValueError('derived payload differs from the pinned transformation')
    if record.get('changed_entries') != ['godot.js'] or record.get('scratch_backing_bytes_max') != 65536:
        raise ValueError('template transformation contract differs')
    return record


def select(record_path, project, preset='Web'):
    record = verify(record_path)
    project = project.resolve(strict=True)
    if project.is_relative_to(ROOT):
        raise ValueError('select a staged project outside this repository')
    config = project / 'export_presets.cfg'
    before = config.read_bytes()
    text = before.decode('utf-8')
    sections = list(re.finditer(r'(?ms)^\[preset\.(\d+)\]\r?\n(.*?)(?=^\[|\Z)', text))
    selected = [s for s in sections if re.search(r'(?m)^name=' + re.escape(json.dumps(preset)) + r'\r?$', s[2])]
    if len(selected) != 1 or not re.search(r'(?m)^platform="Web"\r?$', selected[0][2]):
        raise ValueError('exactly one selected Web preset is required')
    section = r'(?ms)(^\[preset\.' + selected[0][1] + r'\.options\]\r?\n)(.*?)(?=^\[|\Z)'
    options = re.search(section, text)
    if options is None:
        raise ValueError('selected Web options are absent')
    body = options[2]
    field = r'(?m)^custom_template/release=.*?\r?$'
    if len(re.findall(field, body)) > 1:
        raise ValueError('duplicate custom release template option')
    value = 'custom_template/release=' + json.dumps(record['template']['path'], ensure_ascii=False)
    if re.search(field, body):
        body = re.sub(field, lambda _: value, body, count=1)
    else:
        body = value + '\n' + body
    updated = (text[:options.start(2)] + body + text[options.end(2):]).encode('utf-8')
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=project, prefix='.rtc-template-', delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(updated)
        os.chmod(temporary, config.stat().st_mode & 0o777)
        os.replace(temporary, config)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()
    return dict(result='CUSTOM_TEMPLATE_SELECTED', profile=PROFILE, project=str(project), preset=preset,
        record_sha256=sha(record_path), template_sha256=record['template']['sha256'],
        preset_before_sha256=digest(before), preset_after_sha256=sha(config))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    build = commands.add_parser('derive', help='Create a new derived ZIP and provenance record')
    build.add_argument('--source', type=Path, required=True)
    build.add_argument('--out', type=Path, required=True)
    check = commands.add_parser('verify', help='Verify the exact pinned transformation, read-only')
    check.add_argument('--record', type=Path, required=True)
    configure = commands.add_parser('select', help='Select a verified custom template in a staged Web preset')
    configure.add_argument('--record', type=Path, required=True)
    configure.add_argument('--project', type=Path, required=True)
    configure.add_argument('--preset', default='Web')
    configure.add_argument('--out', type=Path, required=True, help='New selection report file')
    args = parser.parse_args()
    if args.action == 'derive':
        path, record = derive(args.source, args.out)
        print(json.dumps(dict(result=record['result'], profile=PROFILE, record=str(path))))
    elif args.action == 'verify':
        record = verify(args.record)
        print(json.dumps(dict(result='TEMPLATE_BYTES_VERIFIED', profile=PROFILE,
                              template_sha256=record['template']['sha256'])))
    else:
        if args.out.exists():
            raise FileExistsError(args.out)
        result = select(args.record, args.project, args.preset)
        with args.out.open('x') as stream:
            json.dump(result, stream, indent=2)
            stream.write('\n')
        print(json.dumps(result))


if __name__ == '__main__':
    main()

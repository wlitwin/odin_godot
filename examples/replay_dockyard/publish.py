#!/usr/bin/env python3
"""Create an itch.io HTML5 ZIP; optionally upload it with --push USER/GAME."""
import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile
from urllib.parse import urlsplit
import zipfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('dockyard_package', HERE / 'package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
ZIP_NAME = 'Dockyard-Duo-html5.zip'
CONFIG_ID = 'dockyard-launch-config'


@contextmanager
def candidate_input(source):
    if source.is_dir():
        yield source
        return
    # Review archives contain one candidate directory. Extract only ordinary
    # files/directories ourselves, including on Python versions without data_filter.
    with tempfile.TemporaryDirectory(prefix='dockyard-candidate-') as temporary:
        root = Path(temporary)
        with tarfile.open(source, 'r:*') as archive:
            members = archive.getmembers()
            if len(members) > package.LIMIT_FILES * 2 or sum(m.size for m in members) > package.LIMIT_BYTES:
                raise ValueError('candidate archive exceeds package bounds')
            names = set()
            top = set()
            for member in members:
                path = PurePosixPath(member.name)
                if (path.is_absolute() or '..' in path.parts or not path.parts
                        or any('\\' in part or ':' in part for part in path.parts)
                        or not (member.isfile() or member.isdir()) or path in names):
                    raise ValueError('candidate archive must contain unique ordinary relative paths')
                names.add(path)
                top.add(path.parts[0])
                target = root.joinpath(*path.parts)
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(member) as data, target.open('xb') as output:
                        shutil.copyfileobj(data, output)
            if len(top) != 1:
                raise ValueError('candidate archive must contain one top-level candidate directory')
        yield root / top.pop()


def endpoint(value):
    parsed = urlsplit(value)
    if (parsed.scheme != 'wss' or not parsed.hostname or parsed.username is not None
            or parsed.password is not None or parsed.query or parsed.fragment
            or any(c.isspace() or ord(c) < 32 for c in value)
            or parsed.port is not None and not 1 <= parsed.port <= 65535):
        raise ValueError('service URL must be a credential-free WSS endpoint without query or fragment')
    return value


def configure_html(html, service):
    if html.count('</head>') != 1 or CONFIG_ID in html:
        raise ValueError('expected one unconfigured Godot HTML head')
    # Launch parameters already come from location.search in the frozen game.
    # Set defaults before engine startup without changing its JS/Wasm/PCK files.
    defaults = json.dumps({'service': endpoint(service), 'relay': '1', 'local': '0'})
    defaults = defaults.replace('<', '\\u003c')
    script = f'''<script id="{CONFIG_ID}">
(() => {{
    const url = new URL(location.href);
    for (const [key, value] of Object.entries({defaults})) {{
        if (!url.searchParams.has(key)) url.searchParams.set(key, value);
    }}
    history.replaceState(history.state, '', url);
}})();
</script>
'''
    return html.replace('</head>', script + '</head>')


def verify_output(out, build_id):
    report = package.read_record(out / 'build.json')
    if report.get('build_id') != build_id or report.get('result') != 'ITCH_ZIP_READY':
        raise ValueError('output belongs to another build; choose a new --out directory')
    if package.files(out / 'web') != report['files']:
        raise ValueError('existing HTML5 bundle bytes differ')
    archive = out / ZIP_NAME
    if package.sha(archive) != report['zip_sha256']:
        raise ValueError('existing ZIP bytes differ')
    with zipfile.ZipFile(archive) as zipped:
        if sorted(zipped.namelist()) != sorted(report['files']):
            raise ValueError('ZIP entries differ from the HTML5 bundle')
        for name, expected in report['files'].items():
            if hashlib.sha256(zipped.read(name)).hexdigest() != expected:
                raise ValueError('ZIP payload differs: ' + name)
    return report


def bundle(candidate, out=None, service=None):
    manifest = package.verify(candidate)
    qa = package.read_record(candidate / 'qa/qualification.json')
    service = endpoint(service or qa.get('deployed_service', {}).get('url', ''))
    source_manifest_sha = package.sha(candidate / 'manifest.json')
    identity = {'candidate_manifest_sha256': source_manifest_sha, 'service_url': service,
                'publish_tool_sha256': package.sha(Path(__file__))}
    build_id = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()[:16]
    out = out.absolute() if out else HERE / 'out' / ('itch-' + build_id)
    if out.is_symlink():
        raise ValueError('output must not be a symlink')
    if out.exists():
        return out, verify_output(out, build_id)
    if candidate == out or candidate in out.parents:
        raise ValueError('output must be outside the prepared candidate')
    out.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='.dockyard-itch-', dir=out.parent))
    try:
        web = staging / 'web'
        for directory in ['web', 'licenses', 'qa']:
            for source in sorted((candidate / directory).rglob('*')):
                if not source.is_file():
                    continue
                relative = source.relative_to(candidate)
                if directory == 'qa' and relative.name not in ['qualification.json', 'runtime-summary.json']:
                    continue
                destination = web / (source.relative_to(candidate / 'web') if directory == 'web' else relative)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
                if package.sha(destination) != manifest['files'][relative.as_posix()]:
                    raise ValueError('candidate changed while copying')
        index = web / 'index.html'
        index.write_text(configure_html(index.read_text(), service))
        payload = package.files(web)
        sizes = [(web / name).stat().st_size for name in payload]
        if (len(payload) > 1000 or any(len(name) > 240 for name in payload)
                or sum(sizes) > 500_000_000 or any(size > 200_000_000 for size in sizes)):
            raise ValueError('bundle exceeds itch.io HTML5 ZIP limits')
        with zipfile.ZipFile(staging / ZIP_NAME, 'w', compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as archive:
            for name in sorted(payload):
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                with (web / name).open('rb') as source, archive.open(info, 'w') as target:
                    shutil.copyfileobj(source, target)
        # The original candidate is immutable and keeps its original manifest.
        package.verify(candidate, source_manifest_sha)
        report = {'schema_version': 1, 'result': 'ITCH_ZIP_READY', 'build_id': build_id,
                  **identity, 'web_cohort': manifest.get('web_cohort'),
                  'release_admitted': False, 'qualification_result': qa.get('result'),
                  'files': payload, 'zip_sha256': package.sha(staging / ZIP_NAME),
                  'zip_bytes': (staging / ZIP_NAME).stat().st_size,
                  'html_launch_defaults': {'service': service, 'relay': '1', 'local': '0'},
                  'runtime_payloads_unchanged': True}
        (staging / 'build.json').write_text(json.dumps(report, indent=2) + '\n')
        verify_output(staging, build_id)
        staging.rename(out)
        return out, report
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def push(out, target, channel, version):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+', target):
        raise ValueError('--push must be USER/GAME, for example itchyitches/dockyard-duo')
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', channel):
        raise ValueError('channel must contain lowercase letters, digits or hyphens')
    command = ['butler'] if shutil.which('butler') else ['nix', 'run', 'nixpkgs#butler', '--']
    subprocess.run(command + ['push', str(out / 'web'), target + ':' + channel,
                             '--userversion', version], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path, required=True,
                        help='Prepared candidate directory or review .tar.gz archive')
    parser.add_argument('--out', type=Path,
                        help='New output directory; default: examples/replay_dockyard/out/itch-BUILD_ID')
    parser.add_argument('--service-url', help='Defaults to the candidate\'s deployed Room endpoint')
    parser.add_argument('--push', metavar='USER/GAME', help='Also upload with Butler (explicit opt-in)')
    parser.add_argument('--channel', default='html5')
    parser.add_argument('--version', help='Butler version; default: review-BUILD_ID')
    args = parser.parse_args()
    try:
        with candidate_input(args.package.resolve(strict=True)) as candidate:
            out, report = bundle(candidate, args.out, args.service_url)
        print('ZIP: ' + str(out / ZIP_NAME), flush=True)
        print('Web: ' + str(out / 'web'), flush=True)
        print('Room service: ' + report['service_url'], flush=True)
        if args.push:
            push(out, args.push, args.channel, args.version or 'review-' + report['build_id'])
            print('Uploaded ' + args.push + ':' + args.channel)
        print('itch.io settings: HTML game; mark the upload playable in browser; enable SharedArrayBuffer support.')
        return 0
    except (ValueError, OSError, KeyError, json.JSONDecodeError, zipfile.BadZipFile, tarfile.TarError,
            subprocess.CalledProcessError) as error:
        parser.exit(1, 'publish: ' + str(error) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())

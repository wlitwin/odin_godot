"""Bake with Godot's typed extractor, or verify the committed canonical artifact.

Run after building/importing the project:
    python3 tools/stock.py --project /absolute/path/to/built/project
Headless CI needs only --check; it never interprets TRES properties.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import zlib
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = Path('shared/content/stock.rpldef')
RECEIPT = Path('shared/content/stock.manifest.json')


def sources(root):
    paths = set((root / 'data').rglob('*.tres'))
    paths.update(p for p in (root / 'scripts/defs').glob('*.odin') if '.gen.' not in p.name)
    paths.update(root / p for p in ['scripts/content.odin', 'scripts/content_export.odin', 'shared/content/content.odin'])
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def source_id(manifest):
    encoded = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
    return int.from_bytes(hashlib.sha256(encoded).digest()[:8], 'little') & ((1 << 63) - 1)


def fnv(data, seed=14695981039346656037):
    for b in data:
        seed = ((seed ^ b) * 1099511628211) & ((1 << 64) - 1)
    return seed


def describe(data, manifest):
    if len(data) < 52:
        raise ValueError('Truncated artifact')
    magic, version, kind, epoch, source, schema, semantic, size, checksum = struct.unpack('<4sHHQQQQIQ', data[:52])
    if magic != b'RPLY' or version != 1 or kind != 0x4446 or epoch != 1 or size != len(data)-52:
        raise ValueError('Invalid definition artifact header')
    if source != source_id(manifest) or checksum != fnv(data[52:], fnv(data[:44])):
        raise ValueError('Artifact source/checksum mismatch')
    return {'format': 1, 'sources': manifest, 'source_id': source, 'schema': schema,
            'semantic': semantic, 'canonical_digest': fnv(data[52:]),
            'artifact_sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--project', type=Path, help='built and imported Godot project containing the same authoring sources')
    args = parser.parse_args()
    manifest = sources(ROOT)
    if args.check:
        expected = describe((ROOT / ARTIFACT).read_bytes(), manifest)
        if json.loads((ROOT / RECEIPT).read_text()) != expected:
            raise SystemExit('Stale stock artifact/receipt; rebuild and run tools/stock.py --project PATH')
        print('SCRAPYARD_STOCK_CURRENT', expected['canonical_digest'])
        return
    if args.project is None:
        parser.error('baking requires --project pointing to a built/imported project')
    project = args.project.resolve()
    if sources(project) != manifest:
        raise SystemExit('Built project sources differ; rebuild from current sources before baking')
    guard = project / 'scripts/odin_godot_guard.gen.odin'
    guarded = {name: int(crc, 16) for name, crc in re.findall(r'#load_hash\("([^\"]+)", "crc32"\) == 0x([0-9a-f]+)', guard.read_text())}
    for path in manifest:
        if path.startswith('scripts/') and path.endswith('.odin'):
            relative = path.removeprefix('scripts/')
            if guarded.get(relative) != zlib.crc32((project/path).read_bytes()):
                raise SystemExit(f'Stale generated bindings for {path}; rebuild before baking')
    expected_code = (str(zlib.crc32(guard.read_bytes())), str(zlib.crc32((project/'shared/content/content.odin').read_bytes())))
    # Temporary output is on the destination filesystem. A interrupted pair of
    # replacements is detected by --check, never accepted as a current artifact.
    with tempfile.TemporaryDirectory(prefix='bake-', dir=ROOT / 'shared/content') as tmp:
        output = Path(tmp) / 'catalog.rpldef'
        env = os.environ | {'RSY_BAKE_OUTPUT': str(output), 'RSY_BAKE_SOURCE': str(source_id(manifest))}
        ext = 'dylib' if os.uname().sysname == 'Darwin' else 'so'
        env['ODIN_SCRIPTS_DLL'] = str(project / f'bin/libodinscripts.{ext}')
        result = subprocess.run([os.environ.get('GODOT', 'godot'), '--headless', '--path', str(project), 'res://dev/export_content.tscn'],
                                env=env, capture_output=True, text=True, timeout=60)
        if result.returncode or 'RSY_BAKE_OK' not in result.stdout or 'ERROR:' in result.stderr:
            raise SystemExit(result.stdout + result.stderr)
        compiled = re.findall(r'RSY_BAKE_CODE guard=(\d+) catalog=(\d+)', result.stdout)
        if compiled != [expected_code]:
            raise SystemExit('Compiled extractor differs from source/generated bindings; rebuild before baking')
        if sources(ROOT) != manifest or sources(project) != manifest:
            raise SystemExit('Authoring sources changed during baking; artifact not published')
        receipt = describe(output.read_bytes(), manifest)
        record = Path(tmp) / 'manifest.json'
        record.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
        output.replace(ROOT / ARTIFACT)
        record.replace(ROOT / RECEIPT)
        print(result.stdout.strip())


if __name__ == '__main__':
    main()

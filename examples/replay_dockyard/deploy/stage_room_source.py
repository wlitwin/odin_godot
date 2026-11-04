#!/usr/bin/env python3
"""Freeze current working sources for the Pi service without changing Git state."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[3]
TOPS = ['build', 'core', 'godot', 'gdext', 'libgd', 'runtime', 'decl', 'flow',
        'flowgd', 'events', 'kit', 'play', 'replay', 'box3d', 'scriptgen', 'examples']
TESTS = ['box3d_native', 'box3d_recovery', 'box3d_modules', 'box3d_authoring',
         'box3d_motion', 'box3d_upgrade', 'box3d_soak/native_observe']
SKIP = {'bin', '.godot', 'node_modules', '.git', '__pycache__', 'addons', 'out', 'dist'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources(root):
    result = {}
    for directory in [*(root/x for x in TOPS), *(root/'tests'/x for x in TESTS)]:
        if not directory.is_dir():
            continue
        for p in directory.rglob('*'):
            relative = p.relative_to(root)
            if any(part in SKIP or part.startswith('.') for part in relative.parts):
                continue
            if p.is_symlink():
                raise ValueError('source symlink: '+str(relative))
            if p.is_file():
                result[str(relative)] = sha(p)
    for relative in ['LICENSE', 'NOTICE', 'extension_api.json', 'gdextension_interface.h',
                     'tests/replay_comparison/wait_builds.py',
                     'tests/replay_dockyard/package/engine_notices.gd']:
        result[relative] = sha(root/relative)
    return result

def stage(root, archive, out):
    if out.exists() or out.is_symlink():
        raise ValueError('choose a new output directory')
    if out.resolve().is_relative_to(root.resolve()):
        raise ValueError('stage outside the source repository')
    manifest = json.loads((root/'box3d/dependency.json').read_text())
    archive_hash = manifest['dependencies']['box3d']['git_archive_sha256']
    if archive.is_symlink() or sha(archive) != archive_hash:
        raise ValueError('engine archive identity differs')
    before = sources(root)
    if len(before) > 16384 or sum((root/p).stat().st_size for p in before) > 128*1024*1024:
        raise ValueError('source snapshot bounds exceeded')
    lock = json.loads((root/'flake.lock').read_text())
    nixpkgs = lock['nodes']['nixpkgs']
    out.parent.mkdir(parents=True, exist_ok=True)
    temp = Path(tempfile.mkdtemp(prefix='.'+out.name+'-', dir=out.parent))
    try:
        for relative, digest in before.items():
            target = temp/relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root/relative, target)
            if sha(target) != digest:
                raise ValueError('source changed while copying: '+relative)
        (temp/'vendor').mkdir()
        shutil.copy2(archive, temp/'vendor/box3d.tar')
        if sources(root) != before or sha(archive) != archive_hash:
            raise ValueError('source/archive changed while staging')
        (temp/'flake.nix').write_text('''{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs { system = "aarch64-linux"; };
  in { packages.aarch64-linux.default = pkgs.callPackage
    ./examples/replay_dockyard/deploy/room-service.nix {}; };
}
''')
        (temp/'flake.lock').write_text(json.dumps({'version': 7, 'root': 'root', 'nodes': {
            'root': {'inputs': {'nixpkgs': 'nixpkgs'}}, 'nixpkgs': nixpkgs}}, indent=2)+'\n')
        record = {'schema_version': 1, 'result': 'FROZEN_WORKING_SOURCE',
                  'files': before, 'engine_archive_sha256': archive_hash,
                  'nixpkgs': nixpkgs['locked'], 'target': 'aarch64-linux',
                  'scope': 'Room/control service only; client artifact and performance unchanged.'}
        (temp/'source-manifest.json').write_text(json.dumps(record, indent=2)+'\n')
        temp.rename(out)
        return record
    finally:
        if temp.exists():
            shutil.rmtree(temp)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--engine-archive', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    r = stage(ROOT, a.engine_archive, a.out.absolute())
    print(json.dumps({'result': r['result'], 'source': str(a.out.absolute()),
                      'files': len(r['files']), 'manifest_sha256': sha(a.out/'source-manifest.json')}))

if __name__ == '__main__':
    main()

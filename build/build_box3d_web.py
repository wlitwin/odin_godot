#!/usr/bin/env python3
"""Build one verified, position-independent Box3D wasm32 archive.

The archive is linked once into the existing Odin/Godot AOT extension. This
builder does not install a runtime service or infer a browser/test verdict.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from box3d_source import prepare_source


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def encoded_hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def source_inputs(repo, engine):
    paths = [repo / 'box3d/dependency.json', repo / 'build/box3d_source.py',
             repo / 'build/build_box3d_web.py', repo / 'build/build_box3d.sh']
    paths += [p for p in (repo / 'box3d/native').rglob('*') if p.is_file()]
    paths += [p for folder in [engine / 'src', engine / 'include']
              for p in folder.rglob('*') if p.is_file() and p.suffix in ('.c', '.h', '.inl')]
    return {('engine/' + str(p.relative_to(engine)) if p.is_relative_to(engine)
             else str(p.relative_to(repo))): sha(p) for p in sorted(paths)}


def build(repo, cache, variant, testing=False, jobs=4):
    cache.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((repo / 'box3d/dependency.json').read_text())
    engine = prepare_source(repo, cache, manifest)
    compiler = Path(shutil.which('emcc') or '')
    archiver = Path(shutil.which('emar') or '')
    if not compiler.is_file() or not archiver.is_file():
        raise RuntimeError('Web builds require installed emcc and emar')
    version = subprocess.check_output([str(compiler), '--version'], text=True).strip()
    if 'emscripten' not in version.lower():
        raise RuntimeError('selected compiler is not Emscripten')
    flags = ['-O2', '-std=gnu17', '-fPIC', '-fvisibility=hidden', '-pthread',
             '-UNDEBUG', '-DBOX3D_VALIDATE', '-DB3_ENABLE_ASSERT',
             '-fno-fast-math', '-ffp-contract=off', '-sSUPPORT_LONGJMP=wasm']
    flags += ['-msimd128', '-msse2'] if variant == 'WebSIMD' else ['-DBOX3D_DISABLE_SIMD']
    flags += ['-DOGB3_HAS_SNAPSHOTS', '-DOGB3_HAS_STATE_DUMP', '-DOGB3_HAS_RECOVERY']
    if testing:
        flags += ['-DOGB3_TESTING=1']
    inputs = source_inputs(repo, engine)
    target_contract = dict(schema_version=1, kind='emscripten-wasm32', pointer_bits=32,
                           endian='little', compiler_version=version,
                           compiler_sha256=sha(compiler), flags=flags)
    target_id = encoded_hash(target_contract)
    build_id = encoded_hash(dict(target=target_id, source=inputs, dependency=manifest))
    output = cache / 'build' / variant / build_id
    receipt = output / 'build-manifest.json'
    if output.exists():
        if not receipt.is_file():
            raise RuntimeError('incomplete build exists; select a new cache or inspect it: ' + str(output))
        saved = json.loads(receipt.read_text())
        if (saved['source_inputs'] != inputs or saved['build'] != build_id or
                saved['archive_sha256'] != sha(output / 'libogb3.a')):
            raise RuntimeError('content-keyed Wasm build changed')
        return output
    output.mkdir(parents=True)
    objects = output / 'objects'
    objects.mkdir()
    includes = ['-I' + str(engine / 'include'), '-I' + str(engine / 'src'),
                '-I' + str(repo / 'box3d/native')]
    definitions = ['-DOGB3_RECOVERY_BUILD_ID="' + build_id + '"',
                   '-DOGB3_NATIVE_TARGET_ID="' + target_id + '"']
    sources = sorted((engine / 'src').glob('*.c'))
    sources += [repo / 'box3d/native' / name for name in
                ['api.c', 'motion.c', 'rollback_shim.c', 'owned_snapshot.c',
                 'state_dump.c', 'recovery_codec.c', 'authoring_catalog.c']]

    def compile_one(path):
        name = ('engine-' if path.is_relative_to(engine) else 'glue-') + path.stem
        obj, log = objects / (name + '.o'), objects / (name + '.log')
        argv = [str(compiler), *flags, *includes, *definitions, '-c', str(path), '-o', str(obj)]
        with log.open('xb') as stream:
            code = subprocess.run(argv, stdout=stream, stderr=subprocess.STDOUT, timeout=180).returncode
        return dict(source=str(path), object=str(obj), argv=argv, actual_exit=code,
                    log_sha256=sha(log), object_sha256=sha(obj) if obj.exists() else None)

    with ThreadPoolExecutor(max_workers=jobs) as pool:
        commands = list(pool.map(compile_one, sources))
    (output / 'compile-commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    if any(row['actual_exit'] != 0 for row in commands):
        raise RuntimeError('Wasm object compile failed; preserved logs: ' + str(objects))
    archive = output / 'libogb3.a'
    argv = [str(archiver), 'rcs', str(archive), *[row['object'] for row in commands]]
    subprocess.run(argv, check=True, timeout=120)
    if source_inputs(repo, engine) != inputs:
        raise RuntimeError('source changed during Wasm compilation')
    probe = subprocess.check_output([str(compiler), *flags, *includes, '-dM', '-E',
                                     str(engine / 'src/aabb.c')], text=True)
    macros = {}
    for line in probe.splitlines():
        words = line.split(maxsplit=2)
        if len(words) >= 2 and (words[1].startswith(('B3_SIMD_', '__wasm', '__EMSCRIPTEN'))
                               or words[1] in ['__SIZEOF_POINTER__', '__BYTE_ORDER__',
                                               'B3_ENABLE_ASSERT', 'BOX3D_VALIDATE']):
            macros[words[1]] = words[2] if len(words) == 3 else ''
    result = dict(schema_version=1, result='ARCHIVE_BUILT_TESTS_NOT_RUN', variant=variant,
                  build=build_id, target=target_id, target_contract=target_contract,
                  testing_enabled=testing, observation_enabled=False,
                  dependency_manifest=manifest, source_inputs=inputs,
                  source_fence_unchanged=True, archive_sha256=sha(archive),
                  resolved_simulation_macros=macros, compiler=str(compiler),
                  archiver=str(archiver), compile_commands_sha256=sha(output / 'compile-commands.json'),
                  archive_argv=argv, link_flags=['-pthread', '-sSUPPORT_LONGJMP=wasm'] +
                  (['-msimd128', '-msse2'] if variant == 'WebSIMD' else []),
                  scope='Static wasm32 backend archive only; one simulation caller; no runtime/browser verdict')
    receipt.write_text(json.dumps(result, indent=2) + '\n')
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('configuration', choices=['WebScalar', 'WebSIMD'])
    parser.add_argument('cache', type=Path)
    parser.add_argument('--testing', action='store_true')
    parser.add_argument('--jobs', type=int, default=min(4, os.cpu_count() or 1))
    args = parser.parse_args()
    if not 1 <= args.jobs <= 16:
        parser.error('jobs must be in 1..16')
    output = build(Path(__file__).resolve().parents[1], args.cache.resolve(),
                   args.configuration, args.testing, args.jobs)
    print(json.dumps(dict(result='ARCHIVE_AVAILABLE', archive=str(output / 'libogb3.a'),
                         manifest=str(output / 'build-manifest.json'))))


if __name__ == '__main__':
    main()

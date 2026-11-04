#!/usr/bin/env python3
"""Link one AOT backend and prove its actual function-table interval size."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def leb(data, offset):
    value = shift = 0
    for _ in range(5):
        if offset >= len(data):
            raise ValueError('truncated wasm integer')
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, offset
        shift += 7
    raise ValueError('invalid wasm integer')


def table_size(path):
    data = path.read_bytes()
    if data[:8] != b'\0asm\x01\0\0\0':
        raise ValueError('not a wasm module')
    offset = 8
    while offset < len(data):
        kind = data[offset]
        size, start = leb(data, offset + 1)
        end = start + size
        if end > len(data):
            raise ValueError('wasm section exceeds module')
        if kind == 0:
            length, cursor = leb(data, start)
            name = data[cursor:cursor + length]
            cursor += length
            if name == b'dylink.0':
                while cursor < end:
                    subsection = data[cursor]
                    length, body = leb(data, cursor + 1)
                    stop = body + length
                    if stop > end:
                        raise ValueError('dylink subsection exceeds section')
                    if subsection == 1:
                        _memory, body = leb(data, body)
                        _memory_align, body = leb(data, body)
                        count, body = leb(data, body)
                        _table_align, body = leb(data, body)
                        if body != stop or count == 0:
                            raise ValueError('invalid dylink memory/table info')
                        return count
                    cursor = stop
        offset = end
    raise ValueError('missing dylink.0 table interval')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def imported_symbols(path):
    """Read standard wasm32 imports; fail rather than omit unknown descriptors."""
    data = path.read_bytes()
    offset = 8
    def name_at(cursor):
        length, cursor = leb(data, cursor)
        end = cursor + length
        if end > len(data):
            raise ValueError('truncated import name')
        return data[cursor:end].decode('utf-8'), end
    def limits(cursor):
        flags, cursor = leb(data, cursor)
        if flags & ~3:
            raise ValueError('unsupported non-wasm32 limits')
        _, cursor = leb(data, cursor)
        if flags & 1:
            _, cursor = leb(data, cursor)
        return cursor
    while offset < len(data):
        section = data[offset]
        size, start = leb(data, offset + 1)
        end = start + size
        if end > len(data):
            raise ValueError('invalid import section extent')
        if section == 2:
            count, cursor = leb(data, start)
            result = []
            for _ in range(count):
                module, cursor = name_at(cursor)
                name, cursor = name_at(cursor)
                kind = data[cursor]
                cursor += 1
                if kind == 0:
                    _, cursor = leb(data, cursor)
                elif kind == 1:
                    if data[cursor] not in (0x70, 0x6f):
                        raise ValueError('unsupported table reference type')
                    cursor = limits(cursor + 1)
                elif kind == 2:
                    cursor = limits(cursor)
                elif kind == 3:
                    cursor += 2  # primitive value type and mutability
                elif kind == 4:
                    _, cursor = leb(data, cursor)
                    _, cursor = leb(data, cursor)
                else:
                    raise ValueError('unknown wasm import kind')
                result.append(dict(module=module, name=name, kind=kind))
            if cursor != end:
                raise ValueError('import section not completely consumed')
            return result
        offset = end
    return []


def exported_functions(path):
    data = path.read_bytes()
    offset = 8
    while offset < len(data):
        section = data[offset]
        size, cursor = leb(data, offset + 1)
        end = cursor + size
        if end > len(data):
            raise ValueError('invalid export section extent')
        if section == 7:
            count, cursor = leb(data, cursor)
            functions = set()
            for _ in range(count):
                length, cursor = leb(data, cursor)
                name = data[cursor:cursor + length].decode('utf-8')
                cursor += length
                kind = data[cursor]
                _, cursor = leb(data, cursor + 1)
                if kind == 0:
                    functions.add(name)
            if cursor != end:
                raise ValueError('export section not completely consumed')
            return functions
        offset = end
    return set()


def link(emcc, obj, archive, output, manifest):
    root = Path(__file__).resolve().parents[1]
    info = json.loads(manifest.read_text())
    if info['testing_enabled'] or info['observation_enabled']:
        raise ValueError('AOT production link refuses instrumented backend')
    if sha(archive) != info['archive_sha256']:
        raise ValueError('selected web archive changed')
    bridge, image = root / 'build/box3d_web_bridge.c', root / 'build/box3d_web_image.s'
    inputs = {str(path): sha(path) for path in [obj, archive, manifest, bridge, image]}
    common = [emcc, str(obj), str(bridge), str(image), str(archive),
              '-O2', '-fPIC', '-fno-fast-math', '-ffp-contract=off',
              '-sSIDE_MODULE=1', *info['link_flags']]
    debug_names = os.environ.get('BOX3D_WEB_DEBUG_NAMES') == '1'
    if debug_names:
        common.append('--profiling-funcs')
    first = output.with_name(output.name + '.table-probe.wasm')
    first_argv = [*common, '-DODIN_BOX3D_TABLE_SIZE=2147483647', '-o', str(first)]
    subprocess.run(first_argv, check=True)
    count = table_size(first)
    final_argv = [*common, '-DODIN_BOX3D_TABLE_SIZE=' + str(count), '-o', str(output)]
    subprocess.run(final_argv, check=True)
    actual = table_size(output)
    if actual != count:
        raise ValueError('function-table interval changed during verified final link')
    if inputs != {name: sha(Path(name)) for name in inputs}:
        raise ValueError('AOT link input changed')
    imports = imported_symbols(output)
    definitions = exported_functions(output)
    backend_relocations, unresolved = [], []
    for row in imports:
        backend = row['name'].startswith(('ogb3_', 'b3', 'odin_box3d_'))
        if backend and row['kind'] == 3 and row['module'] == 'GOT.func' and row['name'] in definitions:
            # PIC function-pointer relocation to this module's own definition,
            # resolved by the normal loader; it is not a second implementation.
            backend_relocations.append(row)
        elif backend or row['module'].startswith('system:') or row['module'].endswith('.a'):
            unresolved.append(row)
    if unresolved:
        raise ValueError('backend/helper symbols remain imported rather than linked once: ' +
                         json.dumps(unresolved[:6]))
    record = dict(result='LINKED_RUNTIME_PENDING', table_size=actual,
                  diagnostic_function_names=debug_names,
                  first_argv=first_argv, final_argv=final_argv, input_sha256=inputs,
                  first_wasm_sha256=sha(first), final_wasm_sha256=sha(output),
                  imports=imports, backend_function_imports=0,
                  own_backend_pointer_relocations=backend_relocations,
                  origin='Actual imported __table_base plus verified dylink.0 table count',
                  scope='One linked AOT image; no runtime/service verdict inferred')
    output.with_suffix('.box3d-link.json').write_text(json.dumps(record, indent=2) + '\n')
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--emcc', required=True)
    parser.add_argument('--object', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    record = link(args.emcc, args.object, args.archive, args.out, args.manifest)
    print(json.dumps(dict(result=record['result'], table_size=record['table_size'])))


if __name__ == '__main__':
    main()

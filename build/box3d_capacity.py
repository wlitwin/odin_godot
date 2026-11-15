#!/usr/bin/env python3
"""One capacity profile for the native backend and every Odin consumer."""
import argparse
import json
import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = 2
FIELDS = ('max_bodies', 'max_shapes', 'max_contacts', 'max_joints', 'max_assets',
          'max_sensor_pairs', 'memory_bytes', 'recovery_bytes', 'dto_bytes',
          'snapshot_bytes', 'network_bytes', 'debug_lines', 'history_frames',
          'kit_repair_ticks', 'replay_prediction_ticks', 'replay_window_ticks',
          'tick_hz', 'substeps')


def validate(profile):
    if (set(profile) != {'schema_version', *FIELDS} or
            type(profile['schema_version']) is not int or profile['schema_version'] != SCHEMA_VERSION):
        raise ValueError('capacity profile needs schema_version 2 and the documented profile fields')
    for name in FIELDS:
        value = profile[name]
        maximum = (1 << 63) - 1 if name == 'memory_bytes' else (1 << 30) - 1
        if type(value) is not int or not 0 < value <= maximum:
            raise ValueError(f'{name} must be a positive integer <= {maximum}')
    if 4 * max(profile[name] for name in ('max_bodies', 'max_shapes', 'max_contacts', 'max_joints')) > (1 << 31) - 1:
        raise ValueError('derived sparse/tree capacities must fit a signed wasm32 integer')
    if profile['network_bytes'] < profile['recovery_bytes'] + profile['snapshot_bytes']:
        raise ValueError('network_bytes must cover recovery_bytes + snapshot_bytes')
    if profile['memory_bytes'] < profile['network_bytes'] + profile['dto_bytes']:
        raise ValueError('memory_bytes must cover network_bytes + dto_bytes')
    history = profile['history_frames']
    if not 32 <= history <= 1024:
        raise ValueError('history_frames must be from 32 through 1024')
    if not 1 <= profile['kit_repair_ticks'] <= min(255, history - 3):
        raise ValueError('kit_repair_ticks must be from 1 through min(255, history_frames - 3)')
    if not 4 <= profile['replay_window_ticks'] <= history - 3:
        raise ValueError('replay_window_ticks must be from 4 through history_frames - 3')
    if not 4 <= profile['replay_prediction_ticks'] <= profile['replay_window_ticks']:
        raise ValueError('replay_prediction_ticks must be from 4 through replay_window_ticks')
    if not 1 <= profile['tick_hz'] <= 240:
        raise ValueError('tick_hz must be from 1 through 240 for the managed frameworks')
    if not 1 <= profile['substeps'] <= 128:
        raise ValueError('substeps must be from 1 through 128')
    return profile


def load(filename=None):
    profile = json.loads((REPO / 'box3d/capacity.json').read_text())
    if filename:
        overrides = json.loads(Path(filename).read_text())
        unknown = set(overrides) - set(profile)
        if unknown:
            raise ValueError('unknown capacity fields: ' + ', '.join(sorted(unknown)))
        profile.update(overrides)
        # Capacity-only project files remain usable; resolve them into the
        # current complete profile before hashing or passing compiler flags.
        if type(profile['schema_version']) is int and profile['schema_version'] == 1:
            profile['schema_version'] = SCHEMA_VERSION
    return validate(profile)


def canonical(profile):
    return json.dumps(validate(profile), sort_keys=True, separators=(',', ':'))


def fingerprint(profile):
    value = 0xcbf29ce484222325
    for name in FIELDS:
        for byte in profile[name].to_bytes(8, 'little'):
            value = ((value ^ byte) * 0x100000001b3) & ((1 << 64) - 1)
    return value


def odin_flags(profile):
    return [f'-define:BOX3D_{name.upper()}={profile[name]}' for name in FIELDS]


def cmake_flags(profile):
    return [f'-DOGB3_{name.upper()}={profile[name]}' for name in FIELDS]


def c_flags(profile):
    return [f'-DOGB3_{name.upper()}={profile[name]}' for name in FIELDS]


def gd_source(profile):
    return '# Generated capacity profile; the SDK build selects the backend values.\nextends RefCounted\nconst PROFILE = ' + json.dumps(validate(profile), indent=4) + '\n'


def install_authoring(profile, project):
    addon = Path(project) / 'addons/box3d_authoring'
    if not addon.is_dir():
        return
    path = addon / 'capacity_defaults.gd'
    content = gd_source(profile)
    if path.is_file() and path.read_text() == content:
        return
    if path.resolve() == (REPO / 'addons/box3d_authoring/capacity_defaults.gd').resolve():
        raise ValueError('copy the authoring addon into the project before selecting a custom capacity profile')
    temporary = path.with_suffix('.gd.tmp')
    temporary.write_text(content)
    temporary.replace(path)


def generated():
    profile = load()
    odin = '// Generated from box3d/capacity.json by build/box3d_capacity.py.\npackage box3d_limits\n\n'
    header = '/* Generated from box3d/capacity.json. */\n#ifndef OGB3_CAPACITY_H\n#define OGB3_CAPACITY_H\n#include <stdint.h>\n'
    for name in FIELDS:
        key = name.upper()
        value = profile[name]
        odin += f'{key} :: #config(BOX3D_{key}, {value})\n'
        header += f'#ifndef OGB3_{key}\n#define OGB3_{key} {value}\n#endif\n'
    odin += '''
OPERATION_RESERVE_BYTES :: 2 * SNAPSHOT_BYTES + max(DTO_BYTES, 8 * 1024 * 1024)
MAX_SENSOR_EVENTS :: 2 * MAX_SENSOR_PAIRS
MAX_SPARSE_SLOTS :: max(512, 4 * max(MAX_BODIES, MAX_SHAPES, MAX_CONTACTS, MAX_JOINTS))
MAX_TREE_NODES :: max(512, 4 * MAX_SHAPES)
NETWORK_PARTS :: (NETWORK_BYTES + 32767) / 32768

// Compared with the actual native macros before constructing a world.
fingerprint :: proc() -> u64 {
    values := [?]u64{''' + ', '.join(name.upper() for name in FIELDS) + '''}
    value := u64(0xcbf29ce484222325)
    for field in values {
        for shift in 0 ..< 8 {
            value = (value ~ ((field >> uint(shift * 8)) & 255)) * 0x100000001b3
        }
    }
    return value
}
'''
    header += '''#define OGB3_MAX_SENSOR_EVENTS (2u * OGB3_MAX_SENSOR_PAIRS)
#define OGB3_FIXED_SECONDS (1.0f / (float)OGB3_TICK_HZ)
#define OGB3_CAP_MAX(a,b) ((a) > (b) ? (a) : (b))
#define OGB3_MAX_SPARSE_SLOTS OGB3_CAP_MAX(512u, (4u * OGB3_CAP_MAX(OGB3_CAP_MAX(OGB3_MAX_BODIES, OGB3_MAX_SHAPES), OGB3_CAP_MAX(OGB3_MAX_CONTACTS, OGB3_MAX_JOINTS))))
#define OGB3_MAX_TREE_NODES OGB3_CAP_MAX(512u, (4u * OGB3_MAX_SHAPES))
#define OGB3_CAPACITY_VALUES {''' + ', '.join('OGB3_' + name.upper() for name in FIELDS) + '''}
#endif
'''
    return {REPO / 'box3d/limits/limits.gen.odin': odin,
            REPO / 'box3d/native/capacity.h': header,
            REPO / 'addons/box3d_authoring/capacity_defaults.gd': gd_source(profile)}


def check_generated(write=False):
    for path, content in generated().items():
        if write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        elif not path.is_file() or path.read_text() != content:
            raise ValueError(f'{path.relative_to(REPO)} is stale; run python3 build/box3d_capacity.py --generate')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generate', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--odin-flags', action='store_true')
    parser.add_argument('--install-authoring', type=Path)
    args = parser.parse_args()
    if args.generate or args.check:
        check_generated(args.generate)
        return
    if args.manifest:
        profile = validate(json.loads(args.manifest.read_text())['capacity_profile'])
    else:
        profile = load(args.profile or os.environ.get('BOX3D_CAPACITY_PROFILE'))
    if args.install_authoring:
        install_authoring(profile, args.install_authoring)
    elif args.odin_flags:
        print('\n'.join(odin_flags(profile)))
    else:
        print(json.dumps(profile, indent=2))


if __name__ == '__main__':
    main()

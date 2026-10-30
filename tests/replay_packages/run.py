"""Compile Replay's feature boundaries and check their compiler-visible API."""

from pathlib import Path
import json
import os
import re
import subprocess
import sys


root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
if (out / 'result.json').exists():
    raise SystemExit('Choose a fresh Replay package output directory.')
odin = os.environ.get('ODIN', 'odin')
collection = f'-collection:godot={root}'
core = 'replay/godot'
features = ['transport', 'storage', 'scene', 'input', 'debug']
targets = {'native': [], 'wasm': ['-target:freestanding_wasm32']}


def run(arguments, log_name):
    result = subprocess.run(
        [odin, *arguments], cwd=root, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, timeout=120,
    )
    (out / log_name).write_text(result.stdout)
    return result


def require(condition, message, log_name=None):
    if not condition:
        detail = f'; inspect {out / log_name}' if log_name else ''
        raise SystemExit(f'{message}{detail}')


# Establish that every canonical import is usable before interpreting any
# expected failure. Missing dependencies or syntax errors must fail this gate.
positive = []
for target, flags in targets.items():
    log_name = f'canonical-{target}.log'
    checked = run([
        'check', str(root / 'tests/replay_packages/fixture'), collection,
        '-no-entry-point', *flags,
    ], log_name)
    require(checked.returncode == 0, f'Canonical package imports failed ({target})', log_name)
    positive.append(target)


def public_names(package):
    log_name = package.replace('/', '_') + '.doc'
    document = run(['doc', str(root / package), collection], log_name)
    # Pinned Odin returns status 1 even when doc emits a complete valid listing.
    # Validate the listing after successful compilation instead of accepting a
    # failed command or an empty inventory as evidence of a small API.
    package_name = 'replay_godot' + ('' if package == core else '_' + package.rsplit('/', 1)[1])
    require(
        re.search(rf'^package {re.escape(package_name)}\s*$', document.stdout, re.MULTILINE),
        f'Missing compiler documentation for {package}', log_name,
    )
    require('\tprocedures\n' in document.stdout and '\ttypes\n' in document.stdout,
            f'Incomplete compiler documentation for {package}', log_name)
    names = re.findall(r'^\t\t([A-Za-z_]\w*)\s*::', document.stdout, re.MULTILINE)
    require(names and len(names) == len(set(names)), f'Invalid public inventory for {package}', log_name)
    return set(names)


inventories = {core: public_names(core)}
for feature in features:
    package = f'{core}/{feature}'
    inventories[package] = public_names(package)
root_names = inventories[core]
require({'Session', 'Room', 'Party', 'session_open', 'session_close'} <= root_names,
        'Core inventory lost required session owners')
require(len(root_names) <= 160,
        f'Core Replay Godot surface grew to {len(root_names)} declarations (limit 160)')
for package, names in inventories.items():
    if package != core:
        duplicated = sorted(root_names & names)
        require(not duplicated, f'Core re-exports feature declarations from {package}: {duplicated}')

# Representative moved types must also fail actual name lookup in client code;
# checking a documentation listing alone cannot establish compiler visibility.
probes = {
    'Enet': 'replaygd.Enet',
    'Storage_Error': 'replaygd.Storage_Error',
    'Script_View': 'replaygd.Script_View(u8, Script)',
    'Debug_Overlay': 'replaygd.Debug_Overlay',
    'Input_Binding': 'replaygd.Input_Binding(Control)',
}
probe = out / 'negative'
probe.mkdir(exist_ok=False)
negative = []
for symbol, expression in probes.items():
    (probe / 'probe.odin').write_text(
        'package replay_packages_negative\n'
        'import gd "godot:godot"\n'
        'import replaygd "godot:replay/godot"\n'
        'Script :: struct {owner: gd.Node2d}\n'
        'Control :: struct {held: u64}\n'
        f'Leaked :: {expression}\n'
    )
    for target, flags in targets.items():
        log_name = f'absent-{symbol}-{target}.log'
        rejected = run(['check', str(probe), collection, '-no-entry-point', *flags], log_name)
        require(rejected.returncode != 0, f'Root still exposes {symbol} ({target})', log_name)
        expected = rf"'{re.escape(symbol)}' is not (?:declared|exported) by 'replaygd'"
        require(re.search(expected, rejected.stdout),
                f'Root absence probe failed for an unrelated reason: {symbol} ({target})', log_name)
        negative.append({'symbol': symbol, 'target': target})


def imports(file):
    text = file.read_text()
    for match in re.finditer(r'^\s*import\s+(?:(?:\w+|\.)\s+)?"([^"\n]+)"', text, re.MULTILINE):
        target = match[1]
        if target.startswith('godot:'):
            destination = root / target.removeprefix('godot:')
        elif ':' not in target:
            destination = file.parent / target
        else:
            continue
        yield destination.resolve()


core_directory = root / core
optional_directories = [core_directory / feature for feature in ['scene', 'input', 'debug']]
edges = []
for file in sorted(core_directory.glob('*.odin')):
    for destination in imports(file):
        require(not any(destination == forbidden or forbidden in destination.parents
                        for forbidden in optional_directories),
                f'Core imports an optional feature: {file.relative_to(root)} -> {destination}')
        edges.append(str(file.relative_to(root)))
for feature in ['transport', 'storage', 'internal/wire']:
    for file in sorted((core_directory / feature).rglob('*.odin')):
        for destination in imports(file):
            require(destination != core_directory,
                    f'Foundational package imports core: {file.relative_to(root)}')
            edges.append(str(file.relative_to(root)))

result = {
    'pass': True,
    'canonical_targets': positive,
    'negative_probes': negative,
    'public_declarations': {package: len(names) for package, names in inventories.items()},
    'core_limit': 160,
    'import_files_checked': len(set(edges)),
    'feature_reexports': False,
}
(out / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(f'REPLAY_PACKAGES_OK core={len(root_names)} limit=160 {out}')

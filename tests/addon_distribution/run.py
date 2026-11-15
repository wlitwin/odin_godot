#!/usr/bin/env python3
"""Install a release ZIP and exercise its own SDK without checkout dependencies."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--web-build', action='store_true')
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'
    project.mkdir()
    with zipfile.ZipFile(args.archive.resolve(strict=True)) as archive:
        for entry in archive.infolist():
            name = Path(entry.filename)
            if name.is_absolute() or '..' in name.parts or name.parts[:1] != ('addons',):
                raise ValueError('unexpected release member: ' + entry.filename)
        archive.extractall(project)
    addon = project / 'addons/odin_godot'
    for name in ('core', 'godot', 'gdext', 'libgd', 'runtime', 'decl', 'flow',
                 'flowgd', 'events', 'kit', 'play', 'replay', 'box3d', 'scriptgen',
                 'template', 'build', 'docs'):
        if not (addon / name / '.gdignore').is_file():
            raise ValueError('Godot must ignore SDK source directory: ' + name)
    if '@ODIN_VERSION@' in (addon / 'README.md').read_text():
        raise ValueError('release README has an unstamped compiler version')

    environment = os.environ.copy()
    for name in ('ODIN_SCRIPTS_DLL', 'BOX3D_NATIVE_LIBRARY', 'BOX3D_WEB_ARCHIVE', 'SCRIPT_BUILD_FLAGS'):
        environment.pop(name, None)
    environment.update(ODIN_GODOT_ROOT=str(addon), SKIP_CORE='1', GODOT=args.godot)
    records = []

    def run(name, command, marker=None, cwd=project):
        logfile = output / (name + '.log')
        with logfile.open('w') as log:
            result = subprocess.run(command, cwd=cwd, env=environment,
                                    stdout=log, stderr=subprocess.STDOUT, timeout=600)
        text = logfile.read_text()
        errors = ('SCRIPT ERROR', 'ERROR:', 'ODIN_SCRIPT_PANIC',
                  'instances were leaked', 'resources still in use')
        if result.returncode or any(error in text for error in errors) or (marker and marker not in text):
            raise RuntimeError(name + ' failed: ' + text[-10000:])
        records.append({'name': name, 'exit': result.returncode, 'log': str(logfile)})
        print(name + ' PASS', flush=True)

    for helper in ('box3d_profile.py', 'box3d_capacity.py', 'box3d_web_link.py'):
        run(helper, [sys.executable, str(addon / 'build' / helper), '--help'])
    run('capacity-defaults', [sys.executable, str(addon / 'build/box3d_capacity.py'), '--odin-flags'])

    # A native-free consumer still needs Kit/Replay's shared diagnostic types.
    probe = output / 'library-probe'
    probe.mkdir()
    (probe / 'main.odin').write_text('''package main
import k "godot:kit/sim"
import r "godot:replay"
import bcap "godot:box3d/limits"
main :: proc() {
    assert(k.WORLD_HISTORY_FRAMES == 128)
    assert(bcap.current().max_bodies >= 1000)
    error := r.Error.None
    assert(error == .None)
}
''')
    run('native-free-libraries', ['odin', 'run', str(probe), '-collection:godot=' + str(addon),
                                  '-out:' + str(output / 'library-probe-run')])
    shutil.copytree(addon / 'template/scripts', project / 'scripts')
    (project / 'project.godot').write_text('''config_version=5
[application]
config/name="odin_godot release check"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
    (project / 'driver.gd').write_text('''extends SceneTree
func _initialize() -> void:
    call_deferred("exercise")
func exercise() -> void:
    var script: Script=load("res://scripts/hello.odin")
    if script==null:
        push_error("Release Hello script did not load")
        quit(1)
        return
    var node:=Node.new()
    node.set_script(script)
    root.add_child(node)
    await process_frame
    node.queue_free()
    await process_frame
    print("ADDON_HELLO_OK")
    quit(0)
''')
    run('consumer-build', ['bash', str(addon / 'build/build_scripts.sh'), str(project)])
    run('godot-import', [args.godot, '--headless', '--editor', '--path', str(project), '--quit-after', '120'])
    run('godot-hello', [args.godot, '--headless', '--path', str(project), '--script', 'driver.gd'], 'ADDON_HELLO_OK')
    if 'Hello from Odin!' not in (output / 'godot-hello.log').read_text():
        raise RuntimeError('the bundled Hello script did not execute its Odin lifecycle hook')
    if args.web_build:
        run('web-build', ['bash', str(addon / 'build/build_web.sh'), str(project)])
        if (project / 'bin/libodin_godot.wasm').read_bytes()[:8] != b'\0asm\x01\0\0\0':
            raise RuntimeError('the packaged web builder did not produce a WebAssembly module')
    (output / 'report.json').write_text(json.dumps({'result': 'PASS', 'archive': str(args.archive.resolve()),
        'project': str(project), 'web_build': args.web_build, 'steps': records}, indent=2) + '\n')
    print('ADDON_DISTRIBUTION_OK', flush=True)


if __name__ == '__main__':
    main()

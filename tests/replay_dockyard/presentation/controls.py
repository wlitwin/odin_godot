#!/usr/bin/env python3
"""Run production Dockyard input checks in an isolated Godot project, without Box3D binaries."""
import argparse
import gzip
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'examples/replay_dockyard'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dockyard-controls-') as temporary:
        project = Path(temporary)
        # Keep actual display settings and scripts; omit the Odin runtime and
        # editor plugin because this fixture supplies the public driver methods.
        config = (SOURCE / 'project.godot').read_text()
        config = config.replace('run/main_scene="res://main.tscn"\n', '')
        config = config.replace('enabled=PackedStringArray("res://addons/box3d_authoring/plugin.cfg")',
                                'enabled=PackedStringArray()')
        (project / 'project.godot').write_text(config)
        for name in ['view.gd', 'feedback.gd', 'web_runtime.gd', 'web_text_entry.gd']:
            shutil.copy2(SOURCE / name, project / name)
        for name in ['audio', 'content']:
            shutil.copytree(SOURCE / name, project / name)
        trace = Path(__file__).with_name('remote-heading.csv.gz')
        (project / 'heading-baseline.csv').write_bytes(gzip.decompress(trace.read_bytes()))
        shutil.copytree(ROOT / 'addons/box3d_authoring', project / 'addons/box3d_authoring',
                        ignore=shutil.ignore_patterns('.godot', '*.uid', '*.import'))
        commands = [
            [args.godot, '--headless', '--path', str(project), '--editor', '--import'],
            [args.godot, '--headless', '--path', str(project), '--script',
             str(Path(__file__).with_suffix('.gd'))],
        ]
        for command in commands:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=60)
            print(result.stdout, end='')
            if result.returncode or 'SCRIPT ERROR:' in result.stdout:
                return result.returncode or 1
        for line in result.stdout.splitlines():
            if line.startswith('DOCKYARD_CONTROLS_TEST '):
                report = json.loads(line.removeprefix('DOCKYARD_CONTROLS_TEST '))
                return 0 if report['result'] == 'PASS' and not report['failures'] else 1
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

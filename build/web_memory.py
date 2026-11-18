#!/usr/bin/env python3
"""Resolve the Web side module's memory mode from the selected Godot preset."""
from __future__ import annotations
import argparse
import configparser
import os
from pathlib import Path
import sys


def resolve(project: Path, box3d: bool, selected: str | None) -> bool:
    if selected is not None:
        if selected not in ('0', '1'):
            raise ValueError('ODIN_WEB_THREADS must be 0 or 1')
        threaded = selected == '1'
    else:
        config = configparser.ConfigParser(interpolation=None, strict=True)
        config.read(project / 'export_presets.cfg')
        modes = set()
        for section in config.sections():
            if not section.startswith('preset.') or section.endswith('.options'):
                continue
            if config.get(section, 'platform', fallback='').strip('"') != 'Web':
                continue
            value = config.get(section + '.options', 'variant/thread_support', fallback='false')
            if value not in ('true', 'false'):
                raise ValueError(f'{section}: variant/thread_support must be true or false')
            modes.add(value == 'true')
        if len(modes) > 1:
            raise ValueError('Web presets use different memory modes. Export the selected preset from Godot, '
                             'or select ODIN_WEB_THREADS=0 or 1 for a direct side-module build.')
        threaded = modes.pop() if modes else box3d
    if box3d and not threaded:
        raise ValueError('The Box3D Web backend requires shared memory. Enable Thread Support in the selected Web export preset.')
    return threaded


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    parser.add_argument('--box3d', action='store_true')
    args = parser.parse_args()
    try:
        print(int(resolve(args.project, args.box3d, os.environ.get('ODIN_WEB_THREADS'))))
    except (ValueError, configparser.Error) as error:
        print('Web export setup: ' + str(error), file=sys.stderr)
        raise SystemExit(1)

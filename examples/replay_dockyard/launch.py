#!/usr/bin/env python3
"""Launch one role from an ordinary prepared Dockyard Duo project."""
import argparse
import os
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['online', 'host', 'client', 'practice'])
    parser.add_argument('--service', help='Verified WSS room-service URL for online play')
    parser.add_argument('--ca', help='Optional native client CA certificate path')
    parser.add_argument('--local-development', action='store_true')
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--godot', default=os.environ.get('GODOT') or shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--address', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=49791)
    parser.add_argument('--latency', type=int, default=0,
                        help='Simulated receive delay in ms for this process (set on both roles; RTT = sum)')
    parser.add_argument('--jitter', type=int, default=0, help='Simulated extra random delay in ms')
    parser.add_argument('--loss', type=int, default=0, help='Simulated unreliable packet loss, per 10000')
    parser.add_argument('--input-delay', type=int, default=0,
                        help='Client input delay cap in ticks (0..6), applied once the round trip exceeds 100 ms')
    args = parser.parse_args()
    project = args.project.resolve(strict=True)
    if not (project / 'project.godot').is_file() or not (project / 'bin').is_dir():
        parser.error('prepare/build this project first')
    if not 1024 <= args.port <= 65535:
        parser.error('port must be in 1024..65535')
    if not Path(args.godot).is_file():
        parser.error('supply an installed Godot executable with --godot')
    extension = 'dylib' if os.uname().sysname == 'Darwin' else 'so'
    scripts = project / 'bin' / ('libodinscripts.' + extension)
    if not scripts.is_file():
        parser.error('prepared scripts library is missing')
    env = os.environ.copy()
    env.update(BOX3D_SAMPLE_ROLE='client' if args.mode == 'client' else 'host',
               BOX3D_SAMPLE_SCRIPTED='0', BOX3D_SAMPLE_TICKS='0',
               BOX3D_SAMPLE_PORT=str(args.port), DOCKYARD_HOST=args.address,
               ODIN_SCRIPTS_DLL=str(scripts),
               DOCKYARD_LATENCY=str(args.latency), DOCKYARD_JITTER=str(args.jitter), DOCKYARD_LOSS=str(args.loss),
               DOCKYARD_INPUT_DELAY=str(args.input_delay))
    env.pop('BOX3D_SAMPLE_OUTPUT', None)
    if args.mode == 'online':
        env.pop('BOX3D_SAMPLE_ROLE', None)
        if args.service: env['DOCKYARD_ROOM_SERVICE'] = args.service
        if args.ca: env['DOCKYARD_ROOM_CA'] = str(Path(args.ca).resolve(strict=True))
        env['DOCKYARD_ROOM_LOCAL'] = '1' if args.local_development else '0'
    argv = [args.godot, '--path', str(project), '--resolution', '1280x720']
    print('Dockyard Duo: ' + args.mode + '. WASD/arrows move; aim and hold mouse to pull; Space boosts.', flush=True)
    os.execve(args.godot, argv, env)


if __name__ == '__main__':
    main()

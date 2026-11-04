#!/usr/bin/env python3
"""Own one temporary loopback Pi service and SSH tunnel for pre-deploy checks."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import signal
import socket
import subprocess
import time

SSH = ['ssh', '-p', '82', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
       '-o', 'ConnectTimeout=6', 'pi@10.0.0.10']

def remote(args, timeout=20):
    return subprocess.run([*SSH, shlex.join(args)], capture_output=True, text=True,
                          timeout=timeout, check=True).stdout

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--package', required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    if not re.fullmatch(r'/nix/store/[a-z0-9]{32}-dockyard-replay-room-1', a.package):
        p.error('use the successful package store path')
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False, mode=0o700)
    unit = 'dockyard-room-review-'+secrets.token_hex(4)
    state = '/var/lib/'+unit
    runtime = '/run/'+unit
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    environment = {
        'PATH': '/run/current-system/sw/bin',
        'REPLAY_ROOM_CONTENT': '0x58a43f78f7481773',
        'REPLAY_ROOM_CHECKPOINT_MODEL': 'disabled',
        'REPLAY_ROOM_BIND': '127.0.0.1', 'REPLAY_ROOM_PORT': '49740',
        'REPLAY_ROOM_LOCAL_DEVELOPMENT': '1',
        'REPLAY_ROOM_DB': state+'/rooms.sqlite3', 'REPLAY_ROOM_CREATE_DB': '1',
        'REPLAY_ROOM_TURN_URLS': 'turn:mc.laserturtle.net:3478',
        'REPLAY_ROOM_TURN_TTL': '600', 'REPLAY_ROOM_TURN_RELAY_ONLY': '1',
        'XDG_CONFIG_HOME': state+'/config', 'XDG_DATA_HOME': state+'/data',
        'XDG_CACHE_HOME': runtime+'/cache',
    }
    start = ['sudo', '-n', 'systemd-run', '--quiet', '--collect', '--unit='+unit,
             '--uid=pi', '--property=StateDirectory='+unit,
             '--property=StateDirectoryMode=0700', '--property=RuntimeDirectory='+unit,
             '--property=RuntimeDirectoryMode=0700', '--property=RuntimeMaxSec=600',
             '--property=MemoryMax=1G', '--property=CPUQuota=100%',
             '--property=LoadCredential=turn-secret:/var/lib/secrets/turn.secret']
    start += ['--setenv='+key+'='+value for key, value in environment.items()]
    script = ('umask 077; mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"; '
              'export REPLAY_ROOM_TURN_SECRET_FILE="$CREDENTIALS_DIRECTORY/turn-secret"; exec "$1"')
    start += ['/run/current-system/sw/bin/bash', '-c', script, 'room-review',
              a.package+'/bin/replay-room-service']
    record = {'unit': unit, 'package': a.package, 'private_service_url': 'ws://127.0.0.1:'+str(port),
              'public_service_started': False, 'remote_bind': '127.0.0.1:49740',
              'state_directory': state, 'scope': 'Owned temporary private service; no public deployment claim.'}
    (out/'launch.json').write_text(json.dumps(record, indent=2)+'\n')
    stopping = False
    def stop(*_):
        nonlocal stopping
        stopping = True
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    tunnel = None
    stream = None
    started = False
    error = None
    try:
        remote(start)
        started = True
        deadline = time.monotonic()+40
        while time.monotonic() < deadline:
            log = remote(['sudo', '-n', 'journalctl', '-u', unit, '-o', 'cat', '--no-pager', '-n', '100'])
            (out/'private-service.log').write_text(log)
            if 'REPLAY_ROOM_SERVICE_READY' in log:
                break
            if any(x in log for x in ['SCRIPT ERROR', 'ERROR:', 'CONTRACT_REJECTED', 'REPLAY_ROOM_SERVICE_FAIL']):
                raise RuntimeError('private service startup rejected; log retained')
            active = remote(['sudo', '-n', 'systemctl', 'show', unit, '--property=ActiveState', '--value']).strip()
            if active in ['failed', 'inactive']:
                raise RuntimeError('private service exited during startup; log retained')
            time.sleep(.25)
        else:
            raise TimeoutError('bounded private service startup')
        tunnel_args = [*SSH[:-1], '-o', 'ExitOnForwardFailure=yes', '-o', 'ServerAliveInterval=10',
                       '-N', '-L', f'127.0.0.1:{port}:127.0.0.1:49740', SSH[-1]]
        stream = (out/'tunnel.log').open('xb')
        tunnel = subprocess.Popen(tunnel_args, stdout=stream, stderr=subprocess.STDOUT,
                                  start_new_session=True)
        deadline = time.monotonic()+10
        while time.monotonic() < deadline:
            if tunnel.poll() is not None:
                raise RuntimeError('owned SSH forward did not start')
            with socket.socket() as check:
                if check.connect_ex(('127.0.0.1', port)) == 0:
                    break
            time.sleep(.05)
        else:
            raise TimeoutError('bounded owned SSH forward startup')
        record.update(result='PRIVATE_SERVICE_READY',tunnel_pid=tunnel.pid)
        (out/'ready.json').write_text(json.dumps(record, indent=2)+'\n')
        print(json.dumps(record), flush=True)
        deadline = time.monotonic()+540
        while not stopping and not (out/'stop').exists() and time.monotonic() < deadline:
            if tunnel.poll() is not None:
                raise RuntimeError('owned SSH forward stopped')
            time.sleep(.25)
    except Exception as e:
        error = type(e).__name__+': '+str(e)
    finally:
        if tunnel is not None and tunnel.poll() is None:
            os.killpg(tunnel.pid, signal.SIGTERM)
            tunnel.wait(timeout=10)
        if stream is not None:
            stream.close()
        if started:
            try:
                remote(['sudo', '-n', 'systemctl', 'stop', unit])
                log = remote(['sudo', '-n', 'journalctl', '-u', unit, '-o', 'cat', '--no-pager', '-n', '200'])
                (out/'private-service.log').write_text(log)
            except Exception as e:
                error = error or ('owned unit stop: '+str(e))
        record.update(result='STOPPED' if error is None else 'FAIL', error=error)
        (out/'report.json').write_text(json.dumps(record, indent=2)+'\n')
    print(json.dumps({'result': record['result'], 'error': error, 'report': str(out/'report.json')}))
    return 0 if error is None else 1

if __name__ == '__main__':
    raise SystemExit(main())

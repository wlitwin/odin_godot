from pathlib import Path
import json
import os
import re
import socket
import subprocess
import sys
import time
from forward import Forward

build, out = map(lambda value: Path(value).resolve(), sys.argv[1:3])
mode = sys.argv[3] if len(sys.argv) > 3 else 'creator'
assert mode in {'guest', 'creator', 'outage'}
out.mkdir(parents=True, mode=0o700, exist_ok=False)
os.chmod(out, 0o700)
os.umask(0o077)
godot = os.environ['GODOT']
extension = 'dylib' if sys.platform == 'darwin' else 'so'
processes = []
forwards = []
forwarded = os.environ.get('REPLAY_P2P_FORWARDED') == '1'

def port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]

def spawn(name, project, options):
    env = os.environ | options | {'ODIN_SCRIPTS_DLL': str(project / f'bin/libodinscripts.{extension}')}
    with (out / f'{name}.log').open('w') as log:
        proc = subprocess.Popen([godot, '--headless', '--max-fps', '120', '--path', str(project)], env=env, stdout=log, stderr=subprocess.STDOUT)
    processes.append((name, proc))
    return proc

def text(name): return (out / f'{name}.log').read_text()

def wait(predicate, label, timeout=35):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        for name, proc in processes:
            log = text(name)
            assert not any(x in log for x in ['REPLAY_DUEL_FAIL', 'REPLAY_DUEL_SERVICE_FAIL', 'SCRIPT ERROR', 'ERROR:']), (name, log)
        if predicate(): return
        time.sleep(.05)
    raise AssertionError(f'Timeout: {label}')

try:
    with (out / 'certificate.log').open('w') as log:
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(out / 'key.pem'), '-out', str(out / 'cert.pem'), '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'], stdout=log, stderr=subprocess.STDOUT, check=True)
    service_port, creator_port, guest_port = port(), port(), port()
    creator_listen_port = creator_port
    if forwarded:
        proxy = Forward(creator_listen_port); forwards.append(proxy); creator_port = proxy.port
    server = spawn('service', build / 'service', {'DUEL_SERVICE_PORT': str(service_port), 'DUEL_SERVICE_LOCAL': '0', 'DUEL_SERVICE_CERT': str(out / 'cert.pem'), 'DUEL_SERVICE_KEY': str(out / 'key.pem'), 'DUEL_SERVICE_DB': str(out / 'rooms.sqlite3'), 'DUEL_SERVICE_CREATE': '1', 'DUEL_SERVICE_STOP_FILE': str(out / 'stop')})
    wait(lambda: 'REPLAY_DUEL_SERVICE_READY' in text('service'), 'TLS service')
    common = {'RDP_SERVICE': f'wss://localhost:{service_port}', 'RDP_CA': str(out / 'cert.pem'), 'RDP_LOCAL': '0', 'RDP_TEST': '1', 'RDP_UNTIL': '600', 'RDP_LIVE_REJOIN': '1', 'RDP_LATENCY': '100', 'RDP_JITTER': '15', 'RDP_LOSS': '500', 'RDP_DUPLICATE': '500', 'RDP_ADDRESS': '127.0.0.1'}
    if mode == 'outage': common['RDP_UNTIL'] = '1200'
    creator_env = common | {'RDP_ROLE': 'listen', 'RDP_PARTY': 'create', 'RDP_PORT': str(creator_port), 'RDP_ROOMS_DB': str(out / 'creator.sqlite3'), 'RDP_ARCHIVE': str(out / 'creator.rply'), 'RDP_STAGE': 'save' if mode == 'creator' else '', 'RDP_INVITE_FILE': str(out / 'invitation')}
    if forwarded: creator_env.update(RDP_BIND_ADDRESS='127.0.0.1', RDP_BIND_PORT=str(creator_listen_port))
    creator = spawn('creator', build / 'duel', creator_env)
    wait(lambda: (out / 'invitation').exists(), 'durable creator invitation')
    invitation = (out / 'invitation').read_text()
    assert invitation
    guest_env = common | {'RDP_ROLE': 'dial', 'RDP_PARTY': 'join', 'RDP_INVITE': invitation, 'RDP_PORT': str(guest_port), 'RDP_ROOMS_DB': str(out / 'guest.sqlite3'), 'RDP_ARCHIVE': str(out / 'guest.rply'), 'RDP_STAGE': 'save' if mode == 'guest' else '', 'RDP_INVITE_FILE': ''}
    guest = spawn('guest', build / 'duel', guest_env)
    if mode == 'outage':
        wait(lambda: all('encrypted=true' in text(name) for name in ['creator', 'guest']), 'initial admitted links')
        stopped_at = time.monotonic()
        server.kill(); server.wait(timeout=5)
        wait(lambda: all('RDP_CONTROL_UNAVAILABLE' in text(name) for name in ['creator', 'guest']), 'bounded control failure', 16)
        unavailable_at = time.monotonic()
        wait(lambda: all('RDP_RESULT' in text(name) for name in ['creator', 'guest']), 'gameplay without service')
        assert creator.wait(timeout=5) == 0 and guest.wait(timeout=5) == 0
        results = [re.search(r'RDP_RESULT .*', text(name))[0] for name in ['creator', 'guest']]
        assert all('tick=1200' in line for line in results)
        assert re.search(r'hash=(\d+)', results[0])[1] == re.search(r'hash=(\d+)', results[1])[1]
        assert unavailable_at - stopped_at >= 9
        for name in ['creator', 'guest']:
            assert text(name).index('RDP_CONTROL_UNAVAILABLE') < text(name).index('RDP_RESULT')
            assert 'RDP_NATIVE_LINK serial=1' in text(name)
            assert not any(x in text(name) for x in ['instances were leaked', 'resources still in use'])
        (out / 'result.json').write_text(json.dumps({'pass': True, 'mode': mode, 'tls': True, 'control_failure_seconds': unavailable_at-stopped_at, 'results': results, 'checks': ['real service process kill', 'bounded registration failure', 'party no longer admits new connections', 'existing encrypted links retained', 'full-world reference after service loss']}, indent=2)+'\n')
        print('REPLAY_P2P_NATIVE_OK outage')
        raise SystemExit(0)
    leaving_name, leaving = ('creator', creator) if mode == 'creator' else ('guest', guest)
    survivor_name, survivor = ('guest', guest) if mode == 'creator' else ('creator', creator)
    wait(lambda: 'RDP_SAVED' in text(leaving_name), 'encrypted gameplay and archive')
    saved = re.search(r'RDP_SAVED .*bytes=(\d+)', text(leaving_name))
    assert (out / f'{leaving_name}.rply').stat().st_size == int(saved[1])
    leaving.kill(); leaving.wait(timeout=5)
    wait(lambda: 'RDP_REJOIN_WAIT' in text(survivor_name), 'survivor timeout')
    assert survivor.poll() is None
    returning_env = dict(creator_env if mode == 'creator' else guest_env)
    returning_env.update(RDP_PARTY='rejoin', RDP_STAGE='resume', RDP_INVITE_FILE='')
    replacement_port = port() if mode == 'creator' else guest_port
    if forwarded and mode == 'creator':
        replacement_listen_port = replacement_port
        proxy = Forward(replacement_listen_port); forwards.append(proxy); replacement_port = proxy.port
        returning_env.update(RDP_BIND_ADDRESS='127.0.0.1', RDP_BIND_PORT=str(replacement_listen_port))
    returning_env['RDP_PORT'] = str(replacement_port)
    returning = spawn('returning', build / 'duel', returning_env)
    wait(lambda: 'RDP_RESULT' in text('returning') and 'RDP_RESULT' in text(survivor_name), 'restored convergence')
    assert returning.wait(timeout=5) == 0 and survivor.wait(timeout=5) == 0
    results = [re.search(r'RDP_RESULT .*', text(name))[0] for name in [survivor_name, 'returning']]
    hashes = [re.search(r'hash=(\d+)', line)[1] for line in results]
    assert hashes[0] == hashes[1] == '9353382615414616636'
    assert 'RDP_RESTORED' in text('returning') and re.search(r'RDP_LIVE_REBOUND .*retained=true .*generation=2', text(survivor_name))
    for name in [survivor_name, 'returning']:
        assert re.search(r'RDP_ADMITTED .*incarnation=3 encrypted=true', text(survivor_name))
        match = re.search(r'RDP_NATIVE_LINK serial=(\d+) sent=(\d+) received=(\d+) confirmed=(\d+) target_port=(\d+)', text(name))
        assert match and all(int(value) > 0 for value in match.groups()[:4]), name
        if mode == 'creator' and name == survivor_name: assert int(match[5]) == replacement_port != creator_port
        assert not any(x in text(name) for x in ['instances were leaked', 'resources still in use'])
    (out / 'stop').touch(); assert server.wait(timeout=5) == 0
    assert not any(x in text('service') for x in ['instances were leaked', 'resources still in use'])
    forwarding = [proxy.close() for proxy in forwards]; forwards.clear()
    if forwarded:
        assert all(row['advertised_port'] != row['listen_port'] and row['to_listener'] > 0 and row['to_peer'] > 0 for row in forwarding)
    (out / 'result.json').write_text(json.dumps({'pass': True, 'mode': mode, 'tls': True, 'creator_port': creator_port, 'replacement_port': replacement_port, 'forwarding': forwarding, 'results': results, 'checks': ['persisted create/join enrollment', 'TLS pair provisioning', 'authenticated encrypted ENet traffic', 'process kill after participant archive', 'new incarnation', 'preserved survivor runner', 'fresh connection generation', 'current signed endpoint discovery', 'faulted full-world reference']}, indent=2) + '\n')
    print('REPLAY_P2P_NATIVE_OK', mode)
finally:
    for proxy in forwards: proxy.close()
    for _, proc in processes:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()

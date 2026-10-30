from pathlib import Path
import os
import socket
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[2]
project, out = map(lambda value: Path(value).resolve(), sys.argv[1:])
out.mkdir(parents=True, exist_ok=False)
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
extension = 'dylib' if sys.platform == 'darwin' else 'so' if sys.platform.startswith('linux') else 'dll'
env = os.environ | {'RDP_PARTY': '', 'RDP_TEST': '1', 'RDP_PORT': str(port), 'RDP_LATENCY': '120', 'RDP_JITTER': '20', 'RDP_LOSS': '1000', 'RDP_DUPLICATE': '1000', 'ODIN_SCRIPTS_DLL': str(project / f'bin/libodinscripts.{extension}')}
processes = []
try:
    for role in ['listen', 'dial']:
        with (out / f'{role}.log').open('w') as log:
            proc = subprocess.Popen([env['GODOT'], '--headless', '--path', str(project)], env=env | {'RDP_ROLE': role}, stdout=log, stderr=subprocess.STDOUT)
        processes.append(proc)
        if role == 'listen':
            end = time.monotonic() + 10
            while time.monotonic() < end:
                if 'REPLAY_DUEL_LISTENING' in (out / 'listen.log').read_text(): break
                assert proc.poll() is None, (out / 'listen.log').read_text()
                time.sleep(.05)
            assert 'REPLAY_DUEL_LISTENING' in (out / 'listen.log').read_text()
    for proc in processes: assert proc.wait(timeout=45) == 0
    for file in out.glob('*.log'):
        assert not any(text in file.read_text() for text in ['REPLAY_DUEL_FAIL', 'SCRIPT ERROR', 'ERROR:', 'instances were leaked', 'resources still in use']), file
    subprocess.run(['node', str(root / 'examples/replay_duel/check.mjs'), str(out)], check=True)
    print('REPLAY_P2P_PARTY_NATIVE_REGRESSION_OK')
finally:
    for proc in processes:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()

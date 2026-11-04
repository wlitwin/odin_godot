#!/usr/bin/env python3
"""Run independent browsers against one immutable export and the existing RTC relay."""
import argparse
from functools import partial
import importlib.util
import json
from pathlib import Path
import select
import signal
import socket
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('integration_browser', ROOT / 'tests/box3d_web/integration/browser.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-record', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--ticks', type=int, default=120)
    args = parser.parse_args()
    if not 120 <= args.ticks <= 216000:
        parser.error('ticks must be 120..216000')
    args.out.mkdir(parents=True, exist_ok=False)
    record = json.loads(args.export_record.read_text())
    if record['result'] != 'EXPORTED_BROWSER_PENDING':
        raise SystemExit('actual ordinary export required')
    export = args.export_record.parent / 'export'
    before = {str(p.relative_to(export)): shared.sha(p) for p in export.rglob('*') if p.is_file()}
    if before != record['export_files']:
        raise SystemExit('export differs from its actual record')
    server = shared.ThreadingHTTPServer(('127.0.0.1', 0), partial(shared.Handler, directory=str(export)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with socket.socket() as reserved:
        reserved.bind(('127.0.0.1', 0))
        port = reserved.getsockname()[1]
    relay_argv = ['node', str(ROOT / 'tests/replay_rtc/signal_server.mjs'), str(port)]
    relay = subprocess.Popen(relay_argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
    argv = ['node', str(Path(__file__).with_name('drive.mjs')),
            f'http://127.0.0.1:{server.server_port}/index.html', f'ws://127.0.0.1:{port}',
            str(args.out), str(args.ticks)]
    code = 1
    relay_log = bytearray()
    try:
        deadline = time.monotonic() + 15
        while b'REPLAY_SIGNAL_READY' not in relay_log:
            if relay.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('existing signalling fixture did not start')
            if select.select([relay.stdout], [], [], 0.2)[0]:
                relay_log.extend(relay.stdout.readline())
        with (args.out / 'driver.log').open('xb') as stream:
            child = subprocess.Popen(argv, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = child.wait(timeout=240)
            except subprocess.TimeoutExpired:
                child.send_signal(signal.SIGTERM)
                child.wait(timeout=15)
                code = 124
    finally:
        relay.terminate()
        relay_log.extend(relay.communicate(timeout=15)[0])
        (args.out / 'signalling.log').write_bytes(relay_log)
        server.shutdown()
        server.server_close()
        after = {str(p.relative_to(export)): shared.sha(p) for p in export.rglob('*') if p.is_file()}
        fence = dict(export_unchanged=before == after, export_record_sha256=shared.sha(args.export_record),
                     export_files=before, argv=argv, relay_argv=relay_argv, relay_pid=relay.pid, actual_exit=code)
        (args.out / 'export-binding.json').write_text(json.dumps(fence, indent=2) + '\n')
    print(json.dumps(dict(actual_exit=code, export_unchanged=before == after, report=str(args.out / 'report.json'))))
    return 0 if code == 0 and before == after else 1


if __name__ == '__main__':
    raise SystemExit(main())

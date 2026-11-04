#!/usr/bin/env python3
"""Serve one immutable normal export and run its actual browser acceptance."""
import argparse
from functools import partial
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import signal
import subprocess
import threading


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        super().end_headers()

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-record', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    record = json.loads(args.export_record.read_text())
    if record['result'] != 'EXPORTED_BROWSER_PENDING':
        raise SystemExit('actual ordinary export required')
    export = args.export_record.parent / 'export'
    before = {str(p.relative_to(export)): sha(p) for p in export.rglob('*') if p.is_file()}
    if before != record['export_files']:
        raise SystemExit('export differs from its actual record')
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(export)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    argv = ['node', str(Path(__file__).with_name('drive.mjs')),
            'http://127.0.0.1:' + str(server.server_port) + '/index.html', str(args.out)]
    try:
        with (args.out / 'driver.log').open('xb') as stream:
            child = subprocess.Popen(argv, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = child.wait(timeout=210)
            except subprocess.TimeoutExpired:
                child.send_signal(signal.SIGTERM)
                child.wait(timeout=15)
                code = 124
    finally:
        server.shutdown()
        server.server_close()
    after = {str(p.relative_to(export)): sha(p) for p in export.rglob('*') if p.is_file()}
    fence = dict(export_unchanged=before == after, export_record_sha256=sha(args.export_record),
                 export_files=before, argv=argv, actual_exit=code)
    (args.out / 'export-binding.json').write_text(json.dumps(fence, indent=2) + '\n')
    print(json.dumps(dict(actual_exit=code, export_unchanged=fence['export_unchanged'],
                          report=str(args.out / 'report.json'))))
    return 0 if code == 0 and before == after else 1


if __name__ == '__main__':
    raise SystemExit(main())

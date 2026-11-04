#!/usr/bin/env python3
"""Build and execute the production backend in Node and actual isolated Chrome."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'build'))
from build_box3d_web import build, sha, source_inputs
from run import run_step


class IsolatedHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        super().end_headers()

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    server = None
    report = dict(result='FAIL', steps=[], variants={},
                  scope='Actual production C backend Node/browser execution and bounded C composite comparison; not a game/adapter/rendering performance verdict')
    fixture = Path(__file__).with_name('runtime.c')
    fixture_before = sha(fixture)
    try:
        for variant in ['WebScalar', 'WebSIMD']:
            archive_dir = build(ROOT, args.cache.resolve(), variant, testing=False)
            manifest = archive_dir / 'build-manifest.json'
            info = json.loads(manifest.read_text())
            assert info['testing_enabled'] is False and info['observation_enabled'] is False
            archive = archive_dir / 'libogb3.a'
            engine = args.cache.resolve() / ('box3d-' + info['dependency_manifest']['dependencies']['box3d']['commit'])
            before = source_inputs(ROOT, engine)
            dest = output / variant
            dest.mkdir()
            program = dest / 'runtime.js'
            argv = [info['compiler'], *info['target_contract']['flags'],
                    '-I' + str(ROOT / 'box3d/native'), str(fixture), str(archive),
                    '-sENVIRONMENT=web,node', '-sEXIT_RUNTIME=1', '-sASSERTIONS=2',
                    '-sALLOW_MEMORY_GROWTH=1', '-sMAXIMUM_MEMORY=536870912',
                    '-sSTACK_SIZE=2097152', '-sPTHREAD_POOL_SIZE=0', '-o', str(program)]
            run_step(output, variant + '-compile', argv, report)
            run_step(output, variant + '-node', ['node', str(program)], report)
            (dest / 'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Box3D backend runtime</title>
<script>window.backendSamples=[];var Module={print(text){console.log(text);
if(text.startsWith('WASM_BACKEND_SAMPLE '))backendSamples.push(JSON.parse(text.slice(20)));
if(text.startsWith('WASM_BACKEND_RESULT '))window.backendResult=JSON.parse(text.slice(20));
},printErr(text){console.error(text)}};</script><script src="runtime.js"></script>''')
            assert before == source_inputs(ROOT, engine) and fixture_before == sha(fixture)
            report['variants'][variant] = dict(archive=str(archive), archive_sha256=sha(archive),
                manifest=str(manifest), manifest_sha256=sha(manifest), source_fence_unchanged=True,
                wasm_sha256=sha(dest / 'runtime.wasm'), program_sha256=sha(program))
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(IsolatedHandler, directory=str(output)))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = 'http://127.0.0.1:' + str(server.server_port)
        report['owned_http_address'] = url
        run_step(output, 'actual-chrome', ['node', str(Path(__file__).with_name('drive.mjs')), url, str(output)], report)
        browser = json.loads((output / 'browser-report.json').read_text())
        assert browser['result'] == 'PASS'
        report['browser_report_sha256'] = sha(output / 'browser-report.json')
        report['fixture_sha256'] = fixture_before
        report['result'] = 'PASS'
    except Exception as exc:
        report['error'] = repr(exc)
    finally:
        if server:
            server.shutdown()
            server.server_close()
        (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(output / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())

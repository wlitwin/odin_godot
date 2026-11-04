#!/usr/bin/env python3
"""Run one bounded installed-browser startup probe against immutable game bytes."""
import argparse
from functools import partial
import importlib.util
import json
from pathlib import Path
import os
import signal
import subprocess
import threading

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('browser',ROOT/'tests/box3d_web/integration/browser.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
def mapping(p):return {str(f.relative_to(p)):shared.sha(f) for f in p.rglob('*') if f.is_file()}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--export-record',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--browser',choices=['chrome','firefox'],required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False,mode=0o700);r=json.loads(a.export_record.read_text());export=a.export_record.parent/'export';before=mapping(export)
    if r['result']!='EXPORTED_BROWSER_PENDING' or before!=r['export_files']:raise ValueError('immutable successful ordinary export required')
    server=shared.ThreadingHTTPServer(('127.0.0.1',0),partial(shared.Handler,directory=str(export)));threading.Thread(target=server.serve_forever,daemon=True).start()
    driver=Path(__file__).with_suffix('.mjs');source=shared.sha(driver);argv=['node',str(driver),f'http://127.0.0.1:{server.server_port}/index.html',str(out),a.browser]
    child=None;code=1
    try:
        with (out/'driver.log').open('xb') as f:
            child=subprocess.Popen(argv,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
            try:code=child.wait(timeout=150)
            except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGTERM);child.wait(timeout=10);code=124
    finally:server.shutdown();server.server_close()
    fence=dict(actual_exit=code,export_unchanged=before==mapping(export),driver_source_unchanged=source==shared.sha(driver),driver_sha256=source,argv=argv,export_record_sha256=shared.sha(a.export_record))
    (out/'binding.json').write_text(json.dumps(fence,indent=2)+'\n');print(json.dumps(dict(actual_exit=code,binding=str(out/'binding.json'))))
    return 0 if code==0 and fence['export_unchanged'] and fence['driver_source_unchanged'] else 1
if __name__=='__main__':raise SystemExit(main())

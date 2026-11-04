#!/usr/bin/env python3
"""Serve a qualified local build for human play; never emits a gameplay verdict."""
import argparse
from functools import partial
import hashlib
from http.server import ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('headers',ROOT/'tests/box3d_web/integration/browser.py')
headers=importlib.util.module_from_spec(spec);spec.loader.exec_module(headers)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def port():
    with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--export-record',type=Path,required=True)
    p.add_argument('--acceptance-report',type=Path,required=True)
    p.add_argument('--service-record',type=Path,required=True)
    p.add_argument('--turnserver',type=Path,required=True)
    p.add_argument('--godot',required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();record=json.loads(a.export_record.read_text());accepted=json.loads(a.acceptance_report.read_text())
    binding=json.loads(a.acceptance_report.with_name('export-binding.json').read_text())
    if record['result']!='EXPORTED_BROWSER_PENDING' or accepted['result']!='PASS' or binding['export_record_sha256']!=sha(a.export_record):p.error('bind an actual accepted production export')
    export=a.export_record.parent/'export'
    if {str(f.relative_to(export)):sha(f) for f in export.rglob('*') if f.is_file()}!=record['export_files']:p.error('export changed')
    service_record=json.loads(a.service_record.read_text());service=Path(service_record['service'])
    if not (service/'.godot/extension_list.cfg').is_file():p.error('ordinarily import the prepared service first')
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False,mode=0o700)
    cohort=accepted['host']['cohort'];control,turn=port(),port();secret=secrets.token_hex(32)
    secret_file=out/'private-turn-secret';secret_file.write_text(secret);secret_file.chmod(0o600)
    cfg=out/'private-turn.conf'
    cfg.write_text('\n'.join(['listening-ip=127.0.0.1','relay-ip=127.0.0.1',f'listening-port={turn}','min-port=55000','max-port=55100','realm=dockyard-play.invalid','fingerprint','use-auth-secret','static-auth-secret='+secret,'no-tls','no-dtls','no-cli','allow-loopback-peers','no-multicast-peers','relay-threads=1','user-quota=8','total-quota=16','log-file=stdout','simple-log','pidfile='+str(out/'turn.pid')])+'\n');cfg.chmod(0o600)
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(headers.Handler,directory=str(export)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    env=os.environ.copy();env.update(REPLAY_ROOM_CONTENT='0x'+cohort,REPLAY_ROOM_CHECKPOINT_MODEL='disabled',REPLAY_ROOM_BIND='127.0.0.1',REPLAY_ROOM_PORT=str(control),REPLAY_ROOM_DB=str(out/'private-rooms.sqlite3'),REPLAY_ROOM_CREATE_DB='1',REPLAY_ROOM_LOCAL_DEVELOPMENT='1',REPLAY_ROOM_TURN_SECRET_FILE=str(secret_file),REPLAY_ROOM_TURN_URLS=f'turn:127.0.0.1:{turn}?transport=udp',REPLAY_ROOM_TURN_TTL='600',REPLAY_ROOM_TURN_RELAY_ONLY='1',ODIN_SCRIPTS_DLL=str(service/'bin/libodinscripts.dylib'))
    stopped=threading.Event()
    for sig in [signal.SIGTERM,signal.SIGINT]:signal.signal(sig,lambda *_:stopped.set())
    children=[];streams=[]
    try:
        for name,argv in [('turn',[str(a.turnserver.resolve(strict=True)),'-c',str(cfg)]),('service',[a.godot,'--headless','--max-fps','120','--path',str(service)])]:
            stream=(out/(name+'.log')).open('xb');streams.append(stream)
            child=subprocess.Popen(argv,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True);children.append(child)
        until=time.monotonic()+20
        while b'REPLAY_ROOM_SERVICE_READY' not in (out/'service.log').read_bytes():
            if any(c.poll() is not None for c in children) or time.monotonic()>until:raise RuntimeError('owned local services did not start; logs retained')
            stopped.wait(.05)
        url=f'http://127.0.0.1:{server.server_port}/index.html?service=ws%3A%2F%2F127.0.0.1%3A{control}&local=1&relay=1'
        info=dict(result='INTERACTIVE_ONLY_NO_GAME_VERDICT',url=url,cohort=cohort,export_record_sha256=sha(a.export_record),acceptance_report_sha256=sha(a.acceptance_report),public_internet_claim=False,pids=[c.pid for c in children])
        (out/'interactive.json').write_text(json.dumps(info,indent=2)+'\n');print(json.dumps(info),flush=True)
        while not stopped.wait(1):
            if any(c.poll() is not None for c in children):raise RuntimeError('owned local service stopped')
    finally:
        for child in children:
            if child.poll() is None:
                os.killpg(child.pid,signal.SIGTERM)
                try:child.wait(timeout=10)
                except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=5)
        server.shutdown();server.server_close()
        for stream in streams:stream.close()
    return 0

if __name__=='__main__':raise SystemExit(main())

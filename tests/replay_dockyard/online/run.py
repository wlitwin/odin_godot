#!/usr/bin/env python3
"""Run actual local room enrollment/menu/physics with the existing service."""
import argparse
from functools import partial
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import select
import signal
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('browser',ROOT/'tests/box3d_web/integration/browser.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)

def mapping(base):return {str(p.relative_to(base)):shared.sha(p) for p in base.rglob('*') if p.is_file()}
def external_service_url(value):
    try:
        parsed=urlsplit(value)
        if (parsed.scheme!='wss' or not parsed.hostname or parsed.username is not None
                or parsed.password is not None or parsed.query or parsed.fragment):raise ValueError()
        _=parsed.port
    except ValueError:
        raise argparse.ArgumentTypeError('external service requires a credential-free wss:// URL without query or fragment') from None
    return value
def loopback_service_url(value):
    try:
        parsed=urlsplit(value)
        if (parsed.scheme!='ws' or parsed.hostname not in ['127.0.0.1','::1']
                or parsed.username is not None or parsed.password is not None
                or parsed.query or parsed.fragment):raise ValueError()
        _=parsed.port
    except ValueError:
        raise argparse.ArgumentTypeError('private service requires a credential-free literal loopback ws:// URL') from None
    return value
def main(driver=None,max_ticks=3600,case_timeout=240):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--export-record',type=Path,required=True)
    p.add_argument('--service-record',type=Path,help='Prepared existing service when testing an ordinary production export')
    p.add_argument('--service-url',type=external_service_url,help='Use an existing verified WSS endpoint; start no local service')
    p.add_argument('--loopback-service-url',type=loopback_service_url,help='Explicit private WS endpoint, including an owned SSH tunnel; no Internet claim')
    p.add_argument('--ice-config',type=Path,help='Private runtime ICE file; mutually exclusive with owned TURN or provider')
    p.add_argument('--production-ui',action='store_true',help='Use real canvas inputs and console evidence, with no test autoload')
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--godot',required=True)
    p.add_argument('--ticks',type=int,default=1200)
    p.add_argument('--case',choices=['pair','bad-turn','no-isolation'],default='pair')
    p.add_argument('--turnserver',type=Path)
    p.add_argument('--turn-bind-address',default='127.0.0.1',help='Literal local/private interface for the owned test relay; default loopback')
    p.add_argument('--provider',action='store_true',help='Use the existing authenticated expiring relay-credential service')
    p.add_argument('--certificate',type=Path)
    p.add_argument('--key',type=Path)
    p.add_argument('--certificate-spki',help='Pin for this private local test certificate, never a production trust bypass')
    a=p.parse_args()
    if a.service_url and a.loopback_service_url:p.error('choose one existing service endpoint')
    public_service_url=a.service_url
    a.service_url=a.service_url or a.loopback_service_url
    try:relay_address=ipaddress.ip_address(a.turn_bind_address)
    except ValueError:p.error('test relay address must be a literal private IPv4 address')
    if relay_address.version!=4 or not relay_address.is_private or relay_address.is_unspecified or relay_address.is_multicast:p.error('test relay requires a specific private IPv4 interface')
    tls=a.certificate is not None
    if tls != (a.key is not None) or tls != bool(a.certificate_spki):p.error('local TLS requires certificate, key and exact SPKI pin')
    if not 120<=a.ticks<=max_ticks:p.error('ticks outside the selected runner bound')
    if a.case=='bad-turn' and not (a.turnserver or a.ice_config):p.error('bad-turn requires an owned TURN fixture or explicit private ICE credentials')
    if a.provider and (not (a.turnserver or a.service_url) or a.case=='bad-turn'):p.error('provider requires an owned TURN fixture or external service')
    if a.service_url and a.turnserver:p.error('external service does not start a local TURN fixture')
    if a.ice_config and (a.turnserver or a.provider):p.error('external ICE is separate from owned TURN and provider credentials')
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False,mode=0o700)
    record=json.loads(a.export_record.read_text());export=a.export_record.parent/'export'
    if record['result']!='EXPORTED_BROWSER_PENDING' or mapping(export)!=record['export_files']:raise ValueError('immutable actual export required')
    before=mapping(export)
    service_env=os.environ.copy()
    service=None
    if not a.service_url:
        service_record=json.loads(a.service_record.read_text()) if a.service_record else record
        service=Path(service_record['service'])
        deployment=json.loads((service/'bin/box3d-runtime.json').read_text())
        service_env.update(ODIN_GODOT_ROOT=str(ROOT),ROOT=str(ROOT),GODOT=a.godot,ODIN=shutil.which('odin') or 'odin',
          BOX3D_NATIVE_LIBRARY=deployment['source_library'],SCRIPT_BUILD_FLAGS='-define:REPLAY_SQLITE_LIBRARY='+service_record['sqlite_library'])
    handler=shared.Handler
    if a.case=='no-isolation':
        from http.server import SimpleHTTPRequestHandler
        class NoIsolation(SimpleHTTPRequestHandler):
            def log_message(self,*_):pass
        handler=NoIsolation
    server=shared.ThreadingHTTPServer(('127.0.0.1',0),partial(handler,directory=str(export)))
    if tls:
        ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(a.certificate,a.key)
        server.socket=ctx.wrap_socket(server.socket,server_side=True)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
    selected_driver=Path(driver).resolve(strict=True) if driver else Path(__file__).with_name('drive.mjs')
    helper_sources=list(dict.fromkeys([selected_driver,Path(__file__).with_name('drive.mjs'),Path(__file__),Path(sys.argv[0]).resolve(strict=True)]))
    if selected_driver.parent.name=='qualification':
        helper_sources += [selected_driver.with_name('plan.json'),selected_driver.with_name('soak-plan.json'),selected_driver.with_name('buffered-plan.json'),selected_driver.with_name('trace-plan.json'),ROOT/'tests/box3d_web/contract.json']
    helper_before={str(p):shared.sha(p) for p in helper_sources}
    service_url=a.service_url or f'{"wss" if tls else "ws"}://127.0.0.1:{port}'
    argv=['node',str(selected_driver),f'{"https" if tls else "http"}://127.0.0.1:{server.server_port}/index.html',service_url,str(out),str(a.ticks)]
    service_argv=[a.godot,'--headless','--max-fps','120','--path',str(service)] if service else None
    child=service_child=turn_child=None;code=1;error=None;service_stream=turn_stream=None
    child_env=os.environ.copy()
    child_env['N1_CASE']=a.case
    if a.production_ui:child_env['N1_PRODUCTION_UI']='1'
    if a.provider:child_env['REPLAY_TURN_PROVIDER']='1'
    child_env['N1_EXTERNAL_SERVICE']='1' if public_service_url else '0'
    if a.service_url:
        child_env.pop('N1_TLS_SPKI',None)
        if a.provider:child_env.pop('REPLAY_ICE_CONFIG',None)
    if tls:child_env['N1_TLS_SPKI']=a.certificate_spki
    external_ice_sha=None
    if a.ice_config:
        if a.ice_config.is_symlink() or a.ice_config.stat().st_size>8192:p.error('bounded regular private ICE file required')
        ice_config=json.loads(a.ice_config.read_text())
        if not isinstance(ice_config,dict) or not isinstance(ice_config.get('iceServers'),list):p.error('ICE configuration object required')
        ice=out/'private-ice.json';ice.write_text(json.dumps(ice_config));ice.chmod(0o600)
        child_env['REPLAY_ICE_CONFIG']=str(ice);external_ice_sha=shared.sha(a.ice_config)
    import_argv=None;imported_exit=None
    try:
        # A copied project without .godot needs the ordinary editor import to
        # register its extension/resource loader before its first runtime.
        if service is not None:
            import_argv=[a.godot,'--headless','--editor','--path',str(service),'--quit-after','120']
            with (out/'service-import.log').open('xb') as imported:
                imported_exit=subprocess.run(import_argv,env=service_env,stdout=imported,stderr=subprocess.STDOUT,timeout=120).returncode
            import_log=(out/'service-import.log').read_text()
            if imported_exit!=0 or any(v in import_log for v in ['SCRIPT ERROR','ERROR:','CONTRACT_REJECTED']):
                raise RuntimeError('ordinary service import failed; original log retained')
            with (out/'service-build-wait.log').open('xb') as waited:
                wait_exit=subprocess.run(['python3',str(ROOT/'tests/replay_comparison/wait_builds.py'),str(service),str(out/'service-build-wait.json')],env=service_env,stdout=waited,stderr=subprocess.STDOUT,timeout=150).returncode
            if wait_exit:raise RuntimeError('ordinary service background build did not complete')
        if a.turnserver:
            with socket.socket() as reservation:
                reservation.bind(('127.0.0.1',0));turn_port=reservation.getsockname()[1]
            password=secrets.token_hex(24);user='dockyard-fixture'
            cfg=[f'listening-ip={relay_address}',f'relay-ip={relay_address}',f'listening-port={turn_port}','min-port=55000','max-port=55080','realm=dockyard.invalid','fingerprint','lt-cred-mech',f'user={user}:{password}','no-tls','no-dtls','no-cli','cli-password='+secrets.token_hex(16),'allow-loopback-peers','no-multicast-peers','relay-threads=1','user-quota=8','total-quota=16','log-file=stdout','simple-log','verbose','pidfile='+str(out/'turn.pid')]
            if a.provider:
                secret=secrets.token_hex(32);secret_file=out/'private-provider-secret';secret_file.write_text(secret);secret_file.chmod(0o600)
                cfg=[v for v in cfg if v!='lt-cred-mech' and not v.startswith('user=')]+['use-auth-secret','static-auth-secret='+secret]
            config=out/'private-turn.conf';config.write_text('\n'.join(cfg)+'\n');config.chmod(0o600)
            ice=out/'private-ice.json';ice.write_text(json.dumps(dict(iceTransportPolicy='relay',iceServers=[dict(urls=[f'turn:{relay_address}:{turn_port}?transport=udp'],username=user,credential=secrets.token_hex(24) if a.case=='bad-turn' else password)])));ice.chmod(0o600)
            child_env['REPLAY_ICE_CONFIG']=str(ice)
            turn_stream=(out/'turn.log').open('xb');turn_child=subprocess.Popen([str(a.turnserver.resolve(strict=True)),'-c',str(config)],stdout=turn_stream,stderr=subprocess.STDOUT,start_new_session=True)
            start=time.monotonic()
            while not any(v in (out/'turn.log').read_text() for v in ['Total auth threads','Total General servers']):
                if turn_child.poll() is not None or time.monotonic()-start>15:raise RuntimeError('owned Coturn did not start')
                time.sleep(0.05)
        child=subprocess.Popen(argv,env=child_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
        deadline=time.monotonic()+case_timeout
        with (out/'driver.log').open('xb') as log:
            while child.poll() is None:
                if time.monotonic()>deadline:raise TimeoutError('bounded local functional case')
                if not select.select([child.stdout],[],[],0.2)[0]:continue
                line=child.stdout.readline();log.write(line);log.flush()
                if line.startswith(b'N1_COHORT '):
                    if a.service_url:
                        (out/'service.ready').write_text(line.decode().strip().split()[1]+'\n')
                        continue
                    if service_child is not None:raise ValueError('duplicate cohort announcement')
                    cohort=line.decode().strip().split()[1]
                    if len(cohort)!=16 or any(c not in '0123456789abcdef' for c in cohort):raise ValueError('invalid actual cohort')
                    env=service_env.copy();env.update(REPLAY_ROOM_CONTENT='0x'+cohort,REPLAY_ROOM_PORT=str(port),REPLAY_ROOM_BIND='127.0.0.1',REPLAY_ROOM_CHECKPOINT_MODEL='disabled',REPLAY_ROOM_DB=str(out/'private-service.sqlite3'),REPLAY_ROOM_CREATE_DB='1',REPLAY_ROOM_LOCAL_DEVELOPMENT='1',ODIN_SCRIPTS_DLL=str(service/'bin/libodinscripts.dylib'))
                    if tls:env.update(REPLAY_ROOM_CERT=str(a.certificate.resolve()),REPLAY_ROOM_KEY=str(a.key.resolve()),REPLAY_ROOM_LOCAL_DEVELOPMENT='0')
                    if a.provider:env.update(REPLAY_ROOM_TURN_SECRET_FILE=str(secret_file),REPLAY_ROOM_TURN_URLS=f'turn:{relay_address}:{turn_port}?transport=udp',REPLAY_ROOM_TURN_TTL='12',REPLAY_ROOM_TURN_RELAY_ONLY='1')
                    service_stream=(out/'service.log').open('xb')
                    service_child=subprocess.Popen(service_argv,env=env,stdout=service_stream,stderr=subprocess.STDOUT,start_new_session=True)
                    start=time.monotonic()
                    while b'REPLAY_ROOM_SERVICE_READY' not in (out/'service.log').read_bytes():
                        if service_child.poll() is not None or time.monotonic()-start>20:raise RuntimeError('actual room service did not start')
                        # Wait only for an owned local startup log, not a build/job retry.
                        time.sleep(0.05)
                    (out/'service.ready').write_text(cohort+'\n')
            log.write(child.stdout.read());code=child.wait()
    except Exception as e:error=repr(e)
    finally:
        for owned in [child,service_child,turn_child]:
            if owned is not None and owned.poll() is None:
                os.killpg(owned.pid,signal.SIGTERM)
                try:owned.wait(timeout=10)
                except subprocess.TimeoutExpired:os.killpg(owned.pid,signal.SIGKILL);owned.wait(timeout=5)
        if service_stream is not None:service_stream.close()
        if turn_stream is not None:turn_stream.close()
        server.shutdown();server.server_close()
    service_log=(out/'service.log').read_text() if (out/'service.log').exists() else ''
    service_clean=None if a.service_url else not any(x in service_log for x in ['SCRIPT ERROR','ERROR:','REPLAY_ROOM_SERVICE_FAIL','ODIN_SCRIPT_PANIC'])
    helper_after={str(p):shared.sha(p) for p in helper_sources}
    fence=dict(actual_exit=code,error=error,export_unchanged=before==mapping(export),export_record_sha256=shared.sha(a.export_record),export_files=before,
      helper_sources_before=helper_before,helper_sources_after=helper_after,helper_source_fence=helper_before==helper_after,
      service_clean=service_clean,service_pid=None if service_child is None else service_child.pid,service_argv=service_argv,
      argv=argv,driver_sha256=shared.sha(selected_driver),shared_browser_sha256=shared.sha(Path(__file__).with_name('drive.mjs')),runner_sha256=shared.sha(Path(__file__)),
      tls=tls,local_certificate_pin=bool(a.certificate_spki),turnserver_sha256=shared.sha(a.turnserver) if a.turnserver else None,
      case=a.case,
      relay_bind_address=str(relay_address),
      authenticated_relay_provider=a.provider,
      production_ui=a.production_ui,
      service_import_argv=import_argv,service_import_exit=imported_exit,
      external_service_url=public_service_url,private_loopback_service_url=a.loopback_service_url,external_ice_config_sha256=external_ice_sha,
      local_service_log_observed=not bool(a.service_url),
      scope='Configured endpoint functional evidence from this host; independent external-network and performance evidence remain separate')
    (out/'export-binding.json').write_text(json.dumps(fence,indent=2)+'\n')
    passed=code==0 and error is None and fence['export_unchanged'] and service_clean is not False and fence['helper_source_fence']
    print(json.dumps(dict(result='PASS' if passed else 'FAIL',error=error,report=str(out/'report.json'))))
    return 0 if passed else 1

if __name__=='__main__':raise SystemExit(main())

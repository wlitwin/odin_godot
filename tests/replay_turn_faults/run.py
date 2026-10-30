"""Run existing browser migration gates through a real UDP TURN proxy."""
import argparse,json,os,secrets,signal,socket,subprocess,sys,time
from pathlib import Path
from proxy import validate
ROOT=Path(__file__).resolve().parents[2]
def port():
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
def ready(path,needle,process):
    deadline=time.monotonic()+20
    while time.monotonic()<deadline:
        if path.exists() and needle in path.read_text():return
        if process.poll() is not None:raise RuntimeError(f'{path.name} process exited {process.returncode}')
        time.sleep(.1)
    raise TimeoutError(str(path))
def stop(p):
    if p.poll() is None:
        try:os.killpg(p.pid,signal.SIGTERM)
        except ProcessLookupError:return
        try:p.wait(timeout=10)
        except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);p.wait()
def main(a):
    os.umask(0o077);out=Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False)
    config=dict(loss=a.loss,duplicate=a.duplicate,latency_ms=a.latency_ms,jitter_ms=a.jitter_ms,queue_packets=1024,queue_bytes=1048576)
    validate(config)
    assert a.game=="loaded" or a.service,"Slopball requires --service"
    def interrupted(signum,frame):raise KeyboardInterrupt(f'signal {signum}')
    signal.signal(signal.SIGTERM,interrupted)
    (out/'faults.json').write_text(json.dumps(config,indent=2)+'\n')
    turn_port,proxy_port=port(),port()
    while proxy_port==turn_port:proxy_port=port()
    password=secrets.token_hex(24)
    values=['listening-ip=127.0.0.1','relay-ip=127.0.0.1',f'listening-port={turn_port}','min-port=53000','max-port=53100','realm=replay.invalid','fingerprint','lt-cred-mech',f'user=replay-fixture:{password}','no-tls','no-dtls','no-cli','cli-password='+secrets.token_hex(16),'allow-loopback-peers','no-multicast-peers','relay-threads=1','user-quota=32','total-quota=64','max-bps=2000000','log-file=stdout','simple-log','verbose','pidfile='+str(out/'turn.pid')]
    (out/'turn.conf').write_text('\n'.join(values)+'\n')
    (out/'ice.json').write_text(json.dumps({'iceTransportPolicy':'relay','iceServers':[{'urls':[f'turn:127.0.0.1:{proxy_port}?transport=udp'],'username':'replay-fixture','credential':password}]}))
    jobs=[];logs=[]
    def start(cmd,path,env=None):
        log=path.open('w');logs.append(log);p=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True);jobs.append(p);return p
    failure=None
    try:
        turn=start([str(Path(a.turnserver).resolve()),'-c',str(out/'turn.conf')],out/'turn.log');ready(out/'turn.log','Total General servers',turn)
        proxy=start([sys.executable,str(ROOT/'tests/replay_turn_faults/proxy.py'),'--listen',str(proxy_port),'--host',str(turn_port),'--seed',str(a.seed),'--config',str(out/'faults.json'),'--out',str(out/'proxy'),'--enable-file',str(out/'enable')],out/'proxy.log');ready(out/'proxy/ready.json','max_flows',proxy)
        env={**os.environ,'GODOT':a.godot,'REPLAY_ICE_CONFIG':str(out/'ice.json'),'REPLAY_TURN_PROTOCOL':'udp','REPLAY_TURN_PROVIDER':'0','REPLAY_TURN_ENABLE_FILE':str(out/'enable'),'RSL_ONLINE_LATENCY':'0','RSL_ONLINE_MODES':a.mode}
        if a.game=='loaded':
            env.update(REPLAY_LOADED_RAW_TURN='1',REPLAY_LOADED_MODE=a.mode,REPLAY_RELIABLE_HOLD='0',REPLAY_RELIABLE_HOLD_AT_KILL='0',REPLAY_RENDER_TRACE='1')
            command=['bash',str(ROOT/'tests/replay_loaded_migration/execute.sh'),str(Path(a.web).resolve()),str(out/'game')]
        else:command=['bash',str(ROOT/'tests/replay_slopball_online/execute_web.sh'),str(Path(a.web).resolve()),str(Path(a.service).resolve()),str(out/'game')]
        game=start(command,out/'game.log',env)
        code=game.wait(timeout=420)
        if code:raise RuntimeError(f'browser fixture exited {code}; see {out}/game/driver.log')
    except BaseException as error:failure=error
    finally:
        for p in reversed(jobs):stop(p)
        for log in logs:log.close()
        (out/'ice.json').unlink(missing_ok=True);(out/'turn.conf').unlink(missing_ok=True)
    if failure:raise failure
    subprocess.run([sys.executable,str(ROOT/'tests/replay_turn_faults/report.py'),str(out),'--game',a.game],check=True)
    print('REPLAY_TURN_UDP_FAULTS_OK',out)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--turnserver',required=True);p.add_argument('--web',required=True);p.add_argument('--service');p.add_argument('--game',choices=['slopball','loaded'],default='slopball');p.add_argument('--godot',default='/Applications/Godot.app/Contents/MacOS/Godot');p.add_argument('--mode',choices=['planned','crash'],default='crash');p.add_argument('--seed',type=int,default=901);p.add_argument('--loss',type=float,default=.005);p.add_argument('--duplicate',type=float,default=.002);p.add_argument('--latency-ms',type=float,default=5);p.add_argument('--jitter-ms',type=float,default=5);main(p.parse_args())

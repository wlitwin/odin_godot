#!/usr/bin/env python3
"""Bounded installed-browser automation prerequisites, without game execution."""
import argparse
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import time
from urllib.request import Request,urlopen

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--browser',choices=['firefox','safari'],required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=False,mode=0o700)
    with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
    if a.browser=='firefox':
        profile=out/'profile';profile.mkdir();argv=['/Applications/Firefox.app/Contents/MacOS/firefox','--new-instance','--headless','--profile',str(profile),'--remote-debugging-port',str(port),'about:blank']
    else:argv=['/usr/bin/safaridriver','--port',str(port)]
    env=os.environ.copy()
    if a.browser=='firefox':env.update(MOZ_LOG='RemoteAgent:5',MOZ_LOG_FILE=str(out/'remote-agent.log'))
    report=dict(result='AUTOMATION_PREREQUISITE_NOT_ESTABLISHED',browser=a.browser,argv=argv,settings_changed=False,game_executed=False,observations=[])
    session=None;child=None
    with (out/'process.log').open('xb') as log:
        try:
            child=subprocess.Popen(argv,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True);report['pid']=child.pid
            until=time.monotonic()+15
            while time.monotonic()<until and child.poll() is None:
                try:
                    with urlopen(f'http://127.0.0.1:{port}/status',timeout=1) as r:value=r.read().decode()
                    report['observations'].append(dict(endpoint='/status',body=value));break
                except Exception as e:report['last_connection_error']=repr(e)
                time.sleep(.1)
            if a.browser=='safari' and report['observations']:
                payload=json.dumps({'capabilities':{'alwaysMatch':{'browserName':'safari'}}}).encode()
                try:
                    with urlopen(Request(f'http://127.0.0.1:{port}/session',data=payload,headers={'Content-Type':'application/json'}),timeout=10) as r:reply=json.load(r)
                    session=reply.get('value',{}).get('sessionId');report['session_reply']=reply
                    if session:report['result']='AUTOMATION_SESSION_ESTABLISHED_NO_GAME'
                except Exception as e:
                    report['session_error']=repr(e)
                    if hasattr(e,'read'):report['session_error_body']=e.read().decode()
            elif a.browser=='firefox':
                for endpoint in ['/json/version','/json/list','/session']:
                    try:
                        with urlopen(f'http://127.0.0.1:{port}{endpoint}',timeout=1) as r:report['observations'].append(dict(endpoint=endpoint,body=r.read().decode()))
                    except Exception as e:report['observations'].append(dict(endpoint=endpoint,error=repr(e)))
                report['process_output']=(out/'process.log').read_text()[-12000:]
        finally:
            if session:
                try:urlopen(Request(f'http://127.0.0.1:{port}/session/{session}',method='DELETE'),timeout=5).close()
                except Exception:pass
            if child is not None and child.poll() is None:
                os.killpg(child.pid,signal.SIGTERM)
                try:child.wait(timeout=10)
                except subprocess.TimeoutExpired:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=5)
    report['actual_exit']=child.returncode if child else None
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(dict(result=report['result'],report=str(out/'report.json'),session_error=report.get('session_error'))))
    return 0
if __name__=='__main__':raise SystemExit(main())

"""Wait for observed build processes using an isolated project's paths."""
from pathlib import Path
import json,os,re,subprocess,sys,time
project=Path(sys.argv[1]).resolve();output=Path(sys.argv[2]);seen={}
def normalized(value):return value.replace('/private/tmp/','/tmp/').replace('/private/var/','/var/')
target=re.compile(re.escape(normalized(str(project)))+r'(?=/|\s|$)')
while True:
    rows=subprocess.check_output(['ps','-Ao','pid=,command='],text=True).splitlines()
    active=[]
    for row in rows:
        pid,_,command=row.strip().partition(' ')
        if not pid.isdigit() or int(pid)==os.getpid():continue
        command=normalized(command)
        if not target.search(command):continue
        if not re.search(r'(?:^|/|\s)(?:odin|clang|dsymutil)(?:\s|$)|/build_scripts\.sh\s',command):continue
        active.append(int(pid));seen.setdefault(pid,time.time())
    if not active:break
    output.write_text(json.dumps({'waiting_for':active,'observed_pids':seen},indent=2)+'\n')
    time.sleep(0.1)
output.write_text(json.dumps({'waiting_for':[],'observed_pids':seen,'completed_at':time.time()},indent=2)+'\n')

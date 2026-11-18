"""Wait for observed build processes using an isolated project's paths."""
from pathlib import Path
import json,os,re,subprocess,sys,time
project=Path(sys.argv[1]).resolve();output=Path(sys.argv[2]);seen={}
# A shell may include future build commands in its argv while it waits for us.
# Waiting on that ancestor would deadlock; only independent build jobs count.
ancestors={os.getpid()}
parent=os.getppid()
while parent>1 and parent not in ancestors:
    ancestors.add(parent)
    row=subprocess.run(['ps','-p',str(parent),'-o','ppid='],capture_output=True,text=True).stdout.strip()
    parent=int(row) if row.isdigit() else 0
def normalized(value):return value.replace('/private/tmp/','/tmp/').replace('/private/var/','/var/')
target=re.compile(re.escape(normalized(str(project)))+r'(?=/|\s|$)')
while True:
    rows=subprocess.check_output(['ps','-Ao','pid=,command='],text=True).splitlines()
    active=[]
    for row in rows:
        pid,_,command=row.strip().partition(' ')
        if not pid.isdigit() or int(pid) in ancestors:continue
        command=normalized(command)
        if not target.search(command):continue
        if not re.search(r'(?:^|/|\s)(?:odin|clang|dsymutil)(?:\s|$)|/build_scripts\.sh\s',command):continue
        active.append(int(pid));seen.setdefault(pid,time.time())
    if not active:break
    output.write_text(json.dumps({'waiting_for':active,'observed_pids':seen},indent=2)+'\n')
    time.sleep(0.1)
output.write_text(json.dumps({'waiting_for':[],'observed_pids':seen,'completed_at':time.time()},indent=2)+'\n')

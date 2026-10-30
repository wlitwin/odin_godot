"""Bounded, cancellable local authoring jobs. No shell command interpolation."""
from pathlib import Path
import json,os,signal,subprocess,time

class Cancelled(RuntimeError):pass
class Job:
    def __init__(self,result):
        self.result=Path(result).resolve();self.result.parent.mkdir(parents=True,exist_ok=True)
        self.cancel=self.result.with_suffix('.cancel');self.logs=[]
    def publish(self,**values):
        values['logs']=self.logs
        temp=self.result.with_suffix('.pending');temp.write_text(json.dumps(values,indent=2)+'\n');temp.replace(self.result)
    def progress(self,message):self.publish(ok=False,running=True,message=message,issues=[])
    def run(self,argv,*,cwd=None,env=None,timeout=120,check=True,label='job'):
        if self.cancel.exists():raise Cancelled('Cancelled')
        path=self.result.parent/f'{len(self.logs):02d}-{label}.log';self.logs.append(str(path))
        started=time.monotonic()
        with path.open('w') as log:
            process=subprocess.Popen([str(x) for x in argv],cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            try:
                while process.poll() is None:
                    if self.cancel.exists():raise Cancelled('Cancelled')
                    if time.monotonic()-started>timeout:raise TimeoutError(f'{label} exceeded {timeout}s; see {path}')
                    time.sleep(.1)
                code=process.returncode
            finally:
                # Own the entire process group, including children of an exited parent.
                try:os.killpg(process.pid,signal.SIGTERM)
                except (ProcessLookupError, PermissionError):
                    if process.poll() is None:process.terminate()
                try:process.wait(timeout=3)
                except subprocess.TimeoutExpired:pass
                try:os.killpg(process.pid,signal.SIGKILL)
                except (ProcessLookupError, PermissionError):
                    if process.poll() is None:process.kill()
                process.wait(timeout=3)
        text=path.read_text(errors='replace')
        if check and code:raise RuntimeError(f'{label} failed ({code})\n{text[-12000:]}')
        return code,text

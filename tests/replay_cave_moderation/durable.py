from pathlib import Path
import json,subprocess,sys,time
exe=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False);results=[]
for boundary in ['before','after']:
 database=out/(boundary+'.sqlite');log=out/(boundary+'.log')
 with log.open('w') as h:
  writer=subprocess.Popen([str(exe),boundary,str(database)],stdout=h,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+15
   while 'MODERATION_DURABLE_'+boundary.upper() not in log.read_text():assert writer.poll() is None and time.monotonic()<deadline,log.read_text();time.sleep(.03)
   writer.kill();writer.wait()
  finally:
   if writer.poll() is None:writer.kill();writer.wait()
 result=subprocess.run([str(exe),'verify-'+boundary,str(database)],capture_output=True,text=True,timeout=15)
 (out/('verify-'+boundary+'.log')).write_text(result.stdout+result.stderr);assert result.returncode==0,result.stdout+result.stderr
 results.append({'boundary':boundary,'pass':True,'removed':boundary=='after'})
(out/'result.json').write_text(json.dumps({'pass':True,'cases':results},indent=2)+'\n');print('REPLAY_MODERATION_DURABLE_ALL_OK')

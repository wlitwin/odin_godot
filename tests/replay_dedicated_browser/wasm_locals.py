from pathlib import Path
import json,sys
path=Path(sys.argv[1]);data=path.read_bytes()
assert data[:8]==b'\0asm\x01\0\0\0'
def leb(at):
 value=shift=0
 while True:
  byte=data[at];at+=1;value|=(byte&127)<<shift
  if byte<128:return value,at
  shift+=7
at=8;rows=[]
while at<len(data):
 section=data[at];size,start=leb(at+1);end=start+size
 if section==10:
  count,cursor=leb(start)
  for index in range(count):
   size,body=leb(cursor);after=body+size;groups,local=leb(body);total=0
   for _ in range(groups):number,local=leb(local);total+=number;local+=1
   rows.append({'defined_function':index,'declared_locals':total,'code_bytes':size});cursor=after
 at=end
print(json.dumps({'file':str(path),'bytes':len(data),'largest':sorted(rows,key=lambda r:r['declared_locals'],reverse=True)[:8]},indent=2))

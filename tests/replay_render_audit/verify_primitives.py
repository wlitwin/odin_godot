"""Compare captured PNG pixels without modifying the images."""
from pathlib import Path
import json,struct,zlib,sys
root=Path(sys.argv[1])
def png(path):
 data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';at=8;parts=[]
 while at<len(data):
  n=struct.unpack('>I',data[at:at+4])[0];kind=data[at+4:at+8];body=data[at+8:at+8+n];assert zlib.crc32(kind+body)==struct.unpack('>I',data[at+8+n:at+12+n])[0]
  if kind==b'IHDR':w,h,depth,color,compression,filtering,interlace=struct.unpack('>IIBBBBB',body);assert depth==8 and color in (2,6) and compression==filtering==interlace==0
  if kind==b'IDAT':parts.append(body)
  at+=12+n
 channels=3 if color==2 else 4;stride=w*channels;packed=zlib.decompress(b''.join(parts));assert len(packed)==h*(stride+1);previous=bytearray(stride);pixels=bytearray()
 def paeth(a,b,c):
  p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
  return a if pa<=pb and pa<=pc else b if pb<=pc else c
 for y in range(h):
  kind=packed[y*(stride+1)];assert kind<=4;row=bytearray(packed[y*(stride+1)+1:(y+1)*(stride+1)])
  for i in range(stride):
   a=row[i-channels] if i>=channels else 0;b=previous[i];c=previous[i-channels] if i>=channels else 0
   predictor=(0,a,b,(a+b)//2,paeth(a,b,c))[kind];row[i]=(row[i]+predictor)&255
  pixels.extend(row);previous=row
 return w,h,channels,pixels
reference=png(root/'polygon_color.png');comparisons=[]
for name in ['polygon_modulate','mesh_modulate']:
 value=png(root/(name+'.png'));assert value[:3]==reference[:3]
 delta=max(abs(a-b) for a,b in zip(value[3],reference[3]));changed=sum(a!=b for a,b in zip(value[3],reference[3]));assert delta<=1,(name,delta)
 comparisons.append({'mode':name,'max_channel_difference':delta,'changed_channels':changed})
for name in ['polygon_color','polygon_points']:
 assert json.loads((root/(name+'.json')).read_text())['trace']['conflicts']>0
for name in ['points','transform','polygon_modulate','mesh_modulate']:
 assert json.loads((root/(name+'.json')).read_text())['trace']['conflicts']==0
assert json.loads((root/'mesh_modulate-resized.json').read_text())['conflicts']==0
(root/'pixel-validation.json').write_text(json.dumps(comparisons,indent=2)+'\n');print('RENDER_PRIMITIVES_VERIFIED',comparisons)

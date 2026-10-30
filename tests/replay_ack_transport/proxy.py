"""Drop one armed application ACK datagram; keep ENet retransmission real."""
from pathlib import Path
import argparse,asyncio,hashlib,json,struct,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'replay_network_faults'))
import proxy as link

ACK_KIND=11
INPUT_KINDS={4,15} # Inputs and Inputs_Compact in gameplay protocol 7.

def digest(data,seed=0xcbf29ce484222325):
 for byte in data:seed=((seed^byte)*0x100000001b3)&0xffffffffffffffff
 return seed

def envelopes(data):
 result=[];at=0
 while True:
  at=data.find(b'RPLY',at)
  if at<0:break
  if at+52<=len(data):
   size=struct.unpack_from('<I',data,at+40)[0];end=at+52+size
   if end<=len(data) and struct.unpack_from('<H',data,at+4)[0]==1 and struct.unpack_from('<Q',data,at+8)[0]!=0 and digest(data[at+52:end],digest(data[at:at+44]))==struct.unpack_from('<Q',data,at+44)[0]:
    result.append({'kind':struct.unpack_from('<H',data,at+6)[0],'bytes':size,'tick':struct.unpack_from('<Q',data,at+16)[0]})
  at+=4
 return result

def ack_only(values):
 kinds={v['kind'] for v in values}
 return ACK_KIND in kinds and kinds<=INPUT_KINDS|{ACK_KIND}

original=link.Direction
class Targeted(original):
 def receive(self,data):
  if self.name=='up' and not dropped.exists() and armed.exists():
   values=envelopes(data);kinds={v['kind'] for v in values}
   # No action, heartbeat, feature negotiation or other application reliable
   # message may ride in the dropped datagram. Neutral input copies may drop.
   if ack_only(values):
    self.stats['received_packets']+=1;self.stats['received_bytes']+=len(data);self.stats['loss_dropped_packets']+=1
    h=hashlib.sha256(data).hexdigest();self.event('drop',id=self.stats['received_packets'],copy=0,bytes=len(data),reason='targeted_ack',sha256=h)
    dropped.write_text(json.dumps({'sha256':h,'bytes':len(data),'envelopes':values,'scope':'Exactly one raw datagram containing Snapshot_Ack and no other application reliable envelope.'},indent=2)+'\n')
    return
  super().receive(data)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--listen',type=int,required=True);p.add_argument('--host',type=int,required=True);p.add_argument('--config',required=True);p.add_argument('--out',required=True);p.add_argument('--seed',type=int,default=1337)
 a=p.parse_args();dropped=Path(a.out)/'dropped.json';armed=Path(a.out).parent/'armed.json'
 link.Direction=Targeted;asyncio.run(link.main(a))

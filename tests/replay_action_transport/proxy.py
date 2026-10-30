"""Drop one armed heartbeat/action datagram while ENet reliability remains real."""
from pathlib import Path
import argparse,asyncio,hashlib,importlib.util,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'replay_network_faults'))
import proxy as link
spec=importlib.util.spec_from_file_location('ack_selector',Path(__file__).resolve().parents[1]/'replay_ack_transport/proxy.py')
selector=importlib.util.module_from_spec(spec);spec.loader.exec_module(selector)

def selected(mode,values):
 kinds={v['kind'] for v in values}
 if mode=='heartbeat':return 9 in kinds and kinds<={4,9,11,15}
 return 5 in kinds and kinds<={4,5,9,11,15}

class Targeted(link.Direction):
 def receive(self,data):
  if self.name=='up' and not dropped.exists() and armed.exists():
   values=selector.envelopes(data)
   if selected(mode,values):
    self.stats['received_packets']+=1;self.stats['received_bytes']+=len(data);self.stats['loss_dropped_packets']+=1
    digest=hashlib.sha256(data).hexdigest();self.event('drop',id=self.stats['received_packets'],copy=0,bytes=len(data),reason='targeted_'+mode,sha256=digest)
    dropped.write_text(json.dumps({'mode':mode,'sha256':digest,'bytes':len(data),'envelopes':values,'scope':'One armed upstream datagram; action mode excludes copy bundles to avoid selecting their nested Action envelopes.'},indent=2)+'\n');return
  super().receive(data)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--listen',type=int,required=True);p.add_argument('--host',type=int,required=True);p.add_argument('--config',required=True);p.add_argument('--out',required=True);p.add_argument('--seed',type=int,default=1337);p.add_argument('--mode',choices=['heartbeat','action'],required=True)
 a=p.parse_args();mode=a.mode;dropped=Path(a.out)/'dropped.json';armed=Path(a.out).parent/'armed.json'
 link.Direction=Targeted;asyncio.run(link.main(a))

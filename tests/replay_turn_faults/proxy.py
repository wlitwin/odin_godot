"""Bounded loopback UDP fault proxy for real browser-to-TURN traffic.
No TURN/DTLS payload is changed. Each frontend tuple gets its own upstream socket.
"""
from __future__ import annotations
import argparse,asyncio,hashlib,heapq,json,random,signal,time
from pathlib import Path

def packet_kind(data):
    # RFC 8656 ChannelData: 0x4000..0x4fff, payload length excludes four-byte header.
    if len(data)>=4 and 0x4000<=int.from_bytes(data[:2],'big')<=0x4fff:
        count=int.from_bytes(data[2:4],'big')
        if count>len(data)-4:return 'other'
        body=data[4:4+count]
        # Diagnostic recognition only; ciphertext is neither decoded nor altered.
        if len(body)>=13 and body[0]==23 and body[1]==0xfe and body[2] in (0xfd,0xff) and int.from_bytes(body[11:13],'big')<=len(body)-13:return 'dtls_application'
        # RFC 9147: encrypted records use fixed 001 high bits. Their content
        # type is encrypted, so do not label these as application data.
        if len(body)>=3 and body[0]&0xe0==0x20:return 'dtls13_ciphertext'
        return 'channel_data'
    return 'other'

class Direction:
    def __init__(self,proxy,flow,name,seed):
        self.proxy,self.flow,self.name=proxy,flow,name;self.rng=random.Random(seed);self.queue=[];self.queued_bytes=0;self.serial=0;self.wake=asyncio.Event();self.closed=False;self.transport=None;self.target=None
        self.stats={k:0 for k in ['received','received_bytes','scheduled','forwarded','forwarded_bytes','loss','duplicated','capacity','shutdown','peak_packets','peak_bytes','socket_errors','dtls_received','dtls_loss','dtls_forwarded','channel_loss']}
        self.delay_total=0.0;self.delay_max=0.0
    def event(self,event,**values):self.proxy.log.write(json.dumps({'flow':self.flow,'direction':self.name,'event':event,'at_ns':time.monotonic_ns(),**values},separators=(',',':'))+'\n')
    def receive(self,data):
        now=time.monotonic();self.stats['received']+=1;self.stats['received_bytes']+=len(data);identity=self.stats['received'];kind=packet_kind(data);enabled=self.proxy.enabled;cfg=self.proxy.config
        if kind in ('dtls_application','dtls13_ciphertext'):self.stats['dtls_received']+=1
        self.event('receive',id=identity,bytes=len(data),kind=kind,enabled=enabled,sha256=hashlib.sha256(data).hexdigest())
        if enabled and self.rng.random()<cfg['loss']:
            self.stats['loss']+=1;self.stats['dtls_loss']+=kind in ('dtls_application','dtls13_ciphertext');self.stats['channel_loss']+=kind in ['channel_data','dtls_application','dtls13_ciphertext'];self.event('drop',id=identity,copy=0,reason='loss',bytes=len(data),kind=kind);return
        copies=2 if enabled and self.rng.random()<cfg['duplicate'] else 1
        for copy in range(copies):
            if len(self.queue)>=cfg['queue_packets'] or self.queued_bytes+len(data)>cfg['queue_bytes']:
                self.stats['capacity']+=1;self.event('drop',id=identity,copy=copy,reason='capacity',bytes=len(data),kind=kind);continue
            delay=(cfg['latency_ms']+self.rng.uniform(0,cfg['jitter_ms']))/1000 if enabled else 0
            self.serial+=1;due=now+delay;heapq.heappush(self.queue,(due,self.serial,now,identity,copy,bytes(data),kind));self.queued_bytes+=len(data)
            self.stats['scheduled']+=1;self.stats['duplicated']+=copy;self.stats['peak_packets']=max(self.stats['peak_packets'],len(self.queue));self.stats['peak_bytes']=max(self.stats['peak_bytes'],self.queued_bytes)
            self.event('schedule',id=identity,copy=copy,bytes=len(data),kind=kind,due_ns=int(due*1e9))
        self.wake.set()
    async def run(self):
        while not self.closed:
            self.wake.clear()
            if not self.queue or self.transport is None:await self.wake.wait();continue
            wait=self.queue[0][0]-time.monotonic()
            if wait>0:
                try:await asyncio.wait_for(self.wake.wait(),wait)
                except asyncio.TimeoutError:pass
                continue
            _,_,received,identity,copy,data,kind=heapq.heappop(self.queue);self.queued_bytes-=len(data)
            self.transport.sendto(data,self.target);delay=(time.monotonic()-received)*1000;self.delay_total+=delay;self.delay_max=max(self.delay_max,delay)
            self.stats['forwarded']+=1;self.stats['forwarded_bytes']+=len(data);self.stats['dtls_forwarded']+=kind in ('dtls_application','dtls13_ciphertext');self.event('forward',id=identity,copy=copy,bytes=len(data),kind=kind,delay_ms=delay)
    def close(self):
        self.closed=True
        for _,_,_,identity,copy,data,kind in self.queue:self.stats['shutdown']+=1;self.event('drop',id=identity,copy=copy,bytes=len(data),kind=kind,reason='shutdown')
        self.queue.clear();self.queued_bytes=0;self.wake.set()
    def receipt(self):return {**self.stats,'delay_mean_ms':self.delay_total/max(1,self.stats['forwarded']),'delay_max_ms':self.delay_max}

class Upstream(asyncio.DatagramProtocol):
    def __init__(self,flow):self.flow=flow
    def datagram_received(self,data,address):
        if address==self.flow.proxy.target:self.flow.down.receive(data)
    def error_received(self,error):self.flow.down.stats['socket_errors']+=1

class Flow:
    def __init__(self,proxy,address,index):
        self.proxy,self.address,self.index=proxy,address,index;self.back=None
        self.up=Direction(proxy,index,'up',proxy.seed+index*2);self.down=Direction(proxy,index,'down',proxy.seed+index*2+1)
        self.down.transport,self.down.target=proxy.front,address
        self.tasks=[asyncio.create_task(self.up.run()),asyncio.create_task(self.down.run())];self.opening=asyncio.create_task(self.open())
    async def open(self):
        try:
            self.back,_=await asyncio.get_running_loop().create_datagram_endpoint(lambda:Upstream(self),local_addr=('127.0.0.1',0))
            self.up.transport,self.up.target=self.back,self.proxy.target;self.up.wake.set()
        except Exception as error:self.proxy.errors.append(str(error));self.up.close();self.down.close()
    async def close(self):
        await self.opening;self.up.close();self.down.close();await asyncio.gather(*self.tasks)
        if self.back:self.back.close()

class Proxy(asyncio.DatagramProtocol):
    def __init__(self,config,target,seed,log,max_flows=32):
        self.config,self.target,self.seed,self.log,self.max_flows=config,target,seed,log,max_flows;self.flows={};self.front=None;self.enabled=False;self.closed=False;self.refused=0;self.errors=[]
    def connection_made(self,transport):self.front=transport
    def datagram_received(self,data,address):
        if self.closed or address[0]!='127.0.0.1':return
        flow=self.flows.get(address)
        if flow is None:
            if len(self.flows)>=self.max_flows:self.refused+=1;return
            flow=Flow(self,address,len(self.flows)+1);self.flows[address]=flow
        flow.up.receive(data)
    def error_received(self,error):self.errors.append(str(error))
    async def close(self):
        self.closed=True
        await asyncio.gather(*(flow.close() for flow in self.flows.values()))
        if self.front:self.front.close()
    def receipt(self):return {'enabled':self.enabled,'refused_flows':self.refused,'errors':self.errors,'flows':[{'id':f.index,'up':f.up.receipt(),'down':f.down.receipt()} for f in self.flows.values()]}

def validate(config):
    assert 0<=config['loss']<=1 and 0<=config['duplicate']<=1 and 0<=config['latency_ms']<=1000 and 0<=config['jitter_ms']<=1000
    assert type(config['queue_packets']) is int and 1<=config['queue_packets']<=4096 and type(config['queue_bytes']) is int and 65536<=config['queue_bytes']<=4*1024*1024

async def main(args):
    out=Path(args.out);out.mkdir(parents=True,exist_ok=False);config=json.loads(Path(args.config).read_text());validate(config);assert 1<=args.max_flows<=64
    log=(out/'packets.jsonl').open('w');proxy=Proxy(config,('127.0.0.1',args.host),args.seed,log,args.max_flows)
    await asyncio.get_running_loop().create_datagram_endpoint(lambda:proxy,local_addr=('127.0.0.1',args.listen))
    stopped=asyncio.Event()
    for sig in [signal.SIGTERM,signal.SIGINT]:asyncio.get_running_loop().add_signal_handler(sig,stopped.set)
    (out/'ready.json').write_text(json.dumps({'listen':args.listen,'host':args.host,'seed':args.seed,'config':config,'max_flows':args.max_flows})+'\n');print('TURN_UDP_PROXY_READY',flush=True)
    while not stopped.is_set():
        if not proxy.enabled and Path(args.enable_file).exists():proxy.enabled=True;log.write(json.dumps({'event':'enabled','at_ns':time.monotonic_ns()})+'\n')
        try:await asyncio.wait_for(stopped.wait(),.05)
        except asyncio.TimeoutError:pass
    await proxy.close();log.close();(out/'receipt.json').write_text(json.dumps(proxy.receipt(),indent=2)+'\n');print('TURN_UDP_PROXY_DONE',flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--listen',type=int,required=True);parser.add_argument('--host',type=int,required=True);parser.add_argument('--seed',type=int,default=901);parser.add_argument('--config',required=True);parser.add_argument('--out',required=True);parser.add_argument('--enable-file',required=True);parser.add_argument('--max-flows',type=int,default=32)
    asyncio.run(main(parser.parse_args()))

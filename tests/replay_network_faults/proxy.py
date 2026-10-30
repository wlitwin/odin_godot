"""One-client loopback UDP fault link, below ENet's reliability machinery."""
from __future__ import annotations
import argparse,asyncio,hashlib,heapq,json,random,signal,time
from pathlib import Path

class Direction:
    def __init__(self,name,config,seed,log):
        self.name,self.config,self.rng,self.log=name,config,random.Random(seed),log
        self.queue=[];self.queued_bytes=0;self.credit=float(config["rate_burst_bytes"]);self.credit_at=time.monotonic();self.order=0;self.transport=None;self.target=None
        self.stats={key:0 for key in ('received_packets','received_bytes','loss_dropped_packets','capacity_dropped_packets','scheduled_packets','scheduled_bytes','duplicated_packets','forwarded_packets','forwarded_bytes','shutdown_dropped_packets','max_queued_packets','max_queued_bytes','reordered_packets','socket_errors')}
        self.delays=[];self.last_forwarded=0;self.wake=asyncio.Event();self.closed=False
    def event(self,kind,**values):
        self.log.write(json.dumps({'direction':self.name,'event':kind,'at_ns':time.monotonic_ns(),**values},separators=(',',':'))+'\n')
    def receive(self,data):
        now=time.monotonic();self.stats['received_packets']+=1;self.stats['received_bytes']+=len(data)
        identity=self.stats['received_packets'];digest=hashlib.sha256(data).hexdigest()
        if self.rng.random()<self.config['loss']:
            self.stats['loss_dropped_packets']+=1;self.event('drop',id=identity,copy=0,bytes=len(data),reason='loss',sha256=digest);return
        copies=2 if self.rng.random()<self.config['duplicate'] else 1
        for copy in range(copies):
            if len(self.queue)>=self.config['queue_packets'] or len(data)>self.config['queue_bytes']-self.queued_bytes:
                self.stats['capacity_dropped_packets']+=1;self.event('drop',id=identity,copy=copy,bytes=len(data),reason='capacity',sha256=digest);continue
            due=now+(self.config['latency_ms']+self.rng.uniform(0,self.config['jitter_ms']))/1000
            self.order+=1;heapq.heappush(self.queue,(due,self.order,now,identity,copy,data));self.queued_bytes+=len(data)
            self.stats['scheduled_packets']+=1;self.stats['scheduled_bytes']+=len(data);self.stats['duplicated_packets']+=copy
            self.stats['max_queued_packets']=max(self.stats['max_queued_packets'],len(self.queue));self.stats['max_queued_bytes']=max(self.stats['max_queued_bytes'],self.queued_bytes)
            self.event('schedule',id=identity,copy=copy,bytes=len(data),due_ns=int(due*1e9),sha256=digest)
        self.wake.set()
    def rate_wait(self,size,now):
        rate=self.config['bytes_per_second']
        if not rate:return 0.0
        capacity=max(self.config['rate_burst_bytes'],size)
        self.credit=min(capacity,self.credit+max(0,now-self.credit_at)*rate);self.credit_at=now
        return max(0,(size-self.credit)/rate)
    async def run(self):
        while not self.closed:
            self.wake.clear()
            if not self.queue or self.target is None:
                await self.wake.wait();continue
            now=time.monotonic();delay=max(self.queue[0][0]-now,self.rate_wait(len(self.queue[0][-1]),now))
            if delay>0:
                try:await asyncio.wait_for(self.wake.wait(),delay)
                except asyncio.TimeoutError:pass
                continue
            _,_,received,identity,copy,data=heapq.heappop(self.queue);self.queued_bytes-=len(data)
            self.transport.sendto(data,self.target)
            now=time.monotonic()
            if self.config['bytes_per_second']:self.credit-=len(data)
            self.stats['forwarded_packets']+=1;self.stats['forwarded_bytes']+=len(data)
            if identity<self.last_forwarded:self.stats['reordered_packets']+=1
            self.last_forwarded=max(self.last_forwarded,identity);self.delays.append((now-received)*1000)
            self.event('forward',id=identity,copy=copy,bytes=len(data),delay_ms=self.delays[-1])
    def close(self):
        self.closed=True;self.stats['shutdown_dropped_packets']=len(self.queue)
        for _,_,_,identity,copy,data in self.queue:self.event('drop',id=identity,copy=copy,bytes=len(data),reason='shutdown')
        self.queue.clear();self.queued_bytes=0;self.wake.set()
    def receipt(self):
        delays=sorted(self.delays)
        return {**self.stats,'delay_p50_ms':delays[len(delays)//2] if delays else 0,'delay_max_ms':max(delays,default=0)}

class Endpoint(asyncio.DatagramProtocol):
    def __init__(self,direction,learn=None):self.direction,self.learn=direction,learn;self.allowed=None
    def datagram_received(self,data,address):
        if self.allowed is None:self.allowed=address
        if address!=self.allowed:return
        if self.learn is not None:self.learn.target=address;self.learn.wake.set()
        self.direction.receive(data)
    def error_received(self,error):self.direction.stats['socket_errors']+=1

async def main(args):
    out=Path(args.out);out.mkdir(parents=True,exist_ok=True);config=json.loads(Path(args.config).read_text())
    assert 0<=config['loss']<=1 and 0<=config['duplicate']<=1
    assert 0<=config['latency_ms']<=10000 and 0<=config['jitter_ms']<=10000
    assert 1<=config['queue_packets']<=4096 and 65536<=config['queue_bytes']<=16*1024*1024
    assert 0<=config['bytes_per_second']<=100*1024*1024 and 1<=config['rate_burst_bytes']<=65536
    log=(out/'packets.jsonl').open('w');up=Direction('up',config,args.seed,log);down=Direction('down',config,args.seed+1,log)
    loop=asyncio.get_running_loop();front,front_protocol=await loop.create_datagram_endpoint(lambda:Endpoint(up,down),local_addr=('127.0.0.1',args.listen))
    back,back_protocol=await loop.create_datagram_endpoint(lambda:Endpoint(down),local_addr=('127.0.0.1',0))
    back_protocol.allowed=('127.0.0.1',args.host);up.transport,up.target=back,back_protocol.allowed;down.transport=front
    stopped=asyncio.Event()
    for sig in (signal.SIGINT,signal.SIGTERM):loop.add_signal_handler(sig,stopped.set)
    tasks=[asyncio.create_task(up.run()),asyncio.create_task(down.run())]
    metadata={'config':config,'seed':args.seed,'listen':front.get_extra_info('sockname')[1],'host':args.host,'started_unix':time.time(),'scope':'Raw loopback UDP datagrams; ENet reliability/retransmission stays in the real endpoints.'}
    (out/'ready.json').write_text(json.dumps(metadata,indent=2)+'\n');print('UDP_FAULT_PROXY_READY',flush=True)
    await stopped.wait()
    for direction in (up,down):direction.close()
    await asyncio.gather(*tasks);front.close();back.close();log.close()
    (out/'receipt.json').write_text(json.dumps({**metadata,'finished_unix':time.time(),'directions':{'up':up.receipt(),'down':down.receipt()}},indent=2)+'\n')
    print('UDP_FAULT_PROXY_DONE',flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--listen',type=int,required=True);parser.add_argument('--host',type=int,required=True);parser.add_argument('--config',required=True);parser.add_argument('--out',required=True);parser.add_argument('--seed',type=int,default=1337)
    asyncio.run(main(parser.parse_args()))

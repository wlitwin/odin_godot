import asyncio,io,json,unittest
from proxy import Proxy,Direction,packet_kind,validate

BASE=dict(loss=0,duplicate=0,latency_ms=0,jitter_ms=0,queue_packets=16,queue_bytes=65536)
# Synthetic DTLS application record inside a TURN ChannelData datagram.
BODY=bytes([23,254,253])+bytes(8)+b'\x00\x03abc'
PACKET=b'\x40\x01'+len(BODY).to_bytes(2,'big')+BODY
class Echo(asyncio.DatagramProtocol):
    def connection_made(self,t):self.t=t;self.addresses=set()
    def datagram_received(self,data,addr):self.addresses.add(addr);self.t.sendto(data,addr)
class Client(asyncio.DatagramProtocol):
    def __init__(self):self.queue=asyncio.Queue()
    def datagram_received(self,data,addr):self.queue.put_nowait(data)
class Tests(unittest.IsolatedAsyncioTestCase):
    async def test_distinct_clients_and_new_connection(self):
        loop=asyncio.get_running_loop();echo_t,echo=await loop.create_datagram_endpoint(Echo,local_addr=('127.0.0.1',0))
        proxy=Proxy(BASE,echo_t.get_extra_info('sockname'),901,io.StringIO(),max_flows=3)
        front,_=await loop.create_datagram_endpoint(lambda:proxy,local_addr=('127.0.0.1',0));clients=[]
        try:
            for i in range(4):
                t,c=await loop.create_datagram_endpoint(Client,local_addr=('127.0.0.1',0));clients.append(t)
                data=PACKET+bytes([i]);t.sendto(data,front.get_extra_info('sockname'))
                if i<3:self.assertEqual(await asyncio.wait_for(c.queue.get(),1),data)
                else:
                    with self.assertRaises(asyncio.TimeoutError):await asyncio.wait_for(c.queue.get(),.05)
            self.assertEqual(len(echo.addresses),3);self.assertEqual(proxy.refused,1)
        finally:
            for t in clients:t.close()
            await proxy.close();echo_t.close()
        for flow in proxy.receipt()['flows']:
            for name in ['up','down']:
                stats=flow[name];self.assertEqual(stats['received'],1);self.assertEqual(stats['forwarded'],1);self.assertEqual(stats['dtls_forwarded'],1)
    async def test_fault_gate_loss_duplicate_and_shutdown(self):
        log=io.StringIO();p=Proxy({**BASE,'loss':1},('127.0.0.1',1),1,log);d=Direction(p,1,'up',1)
        d.receive(PACKET);self.assertEqual(d.stats['scheduled'],1)
        p.enabled=True;d.receive(PACKET);self.assertEqual(d.stats['dtls_loss'],1)
        p.config={**BASE,'duplicate':1};d.receive(PACKET);self.assertEqual(d.stats['scheduled'],3);self.assertEqual(d.stats['duplicated'],1)
        d.close();self.assertEqual(d.stats['shutdown'],3);self.assertFalse(d.queue);self.assertEqual(d.queued_bytes,0)
    async def test_queue_caps_and_measured_delay(self):
        p=Proxy({**BASE,'duplicate':1,'latency_ms':30,'queue_packets':2},('127.0.0.1',1),1,io.StringIO());p.enabled=True;d=Direction(p,1,'up',1)
        class Sink:
            def __init__(self):self.sent=[]
            def sendto(self,data,target):self.sent.append(data)
        sink=Sink();d.transport=sink;d.receive(PACKET);d.receive(PACKET)
        self.assertEqual(d.stats['capacity'],2);self.assertEqual(d.stats['peak_packets'],2)
        worker=asyncio.create_task(d.run());await asyncio.sleep(.07);d.close();await worker
        self.assertEqual(sink.sent,[PACKET,PACKET]);self.assertGreaterEqual(d.receipt()['delay_mean_ms'],29)
        d2=Direction(p,2,'up',2);d2.receive(bytes(40000));self.assertEqual(d2.stats['capacity'],1);self.assertLessEqual(d2.stats['peak_bytes'],65536);d2.close()
    def test_packet_recognition_and_config(self):
        self.assertEqual(packet_kind(PACKET),'dtls_application');self.assertEqual(packet_kind(PACKET[:10]),'other')
        self.assertEqual(packet_kind(b'\x40\x01\x00\x03\x23\x00\x00'),'dtls13_ciphertext')
        self.assertEqual(packet_kind(b'\x50\x00\x00\x00'),'other');self.assertEqual(packet_kind(b'\x40\x00\x00\x03abc'),'channel_data')
        validate(BASE)
        for key,value in [('loss',2),('queue_packets',0),('queue_bytes',2),('latency_ms',float('nan'))]:
            with self.assertRaises(AssertionError):validate({**BASE,key:value})
if __name__=='__main__':unittest.main()

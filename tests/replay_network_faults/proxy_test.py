import asyncio,io,json,signal,socket,subprocess,sys,tempfile,time,unittest
from pathlib import Path
from proxy import Direction
BASE={'latency_ms':0,'jitter_ms':0,'loss':0,'duplicate':0,'bytes_per_second':0,'queue_bytes':65536,'queue_packets':128,'rate_burst_bytes':1500}
class Sink:
 def __init__(self):self.sent=[]
 def sendto(self,data,target):self.sent.append((time.monotonic(),data))
class ProxyTests(unittest.IsolatedAsyncioTestCase):
 async def test_capacity_and_rate_limit_apply_to_real_sends(self):
  config={**BASE,'queue_packets':3,'bytes_per_second':10000,'rate_burst_bytes':1000};direction=Direction('up',config,1,io.StringIO());sink=Sink();direction.transport=sink;direction.target=('127.0.0.1',1)
  for i in range(10):direction.receive(bytes([i])*1000)
  self.assertEqual(direction.stats['capacity_dropped_packets'],7);self.assertEqual(direction.queued_bytes,3000)
  task=asyncio.create_task(direction.run());await asyncio.sleep(.35);direction.close();await task
  self.assertEqual(len(sink.sent),3);self.assertGreaterEqual(sink.sent[-1][0]-sink.sent[0][0],.19)
  self.assertEqual(direction.receipt()['scheduled_packets'],direction.receipt()['forwarded_packets'])
 async def test_rate_credit_survives_coarse_timer_wakeups(self):
  import math
  d=Direction('up',{**BASE,'bytes_per_second':262144},1,io.StringIO());d.credit_at=0;now=0;sent=0
  for _ in range(1000):
   delay=d.rate_wait(400,now)
   while delay>1e-12:
    now+=math.ceil(delay/.001)*.001;delay=d.rate_wait(400,now)
   d.credit-=400;sent+=400
   self.assertLessEqual(sent,now*262144+1500+1e-6)
  self.assertGreater(sent/now,250000)
 async def test_loss_duplication_and_shutdown_are_accounted(self):
  lost=Direction('up',{**BASE,'loss':1},1,io.StringIO());lost.receive(b'x');self.assertEqual(lost.stats['loss_dropped_packets'],1);self.assertEqual(lost.queue,[])
  duplicated=Direction('down',{**BASE,'duplicate':1},1,io.StringIO());duplicated.receive(b'abc');self.assertEqual(duplicated.stats['scheduled_packets'],2);self.assertEqual(duplicated.stats['duplicated_packets'],1)
  duplicated.close();self.assertEqual(duplicated.stats['shutdown_dropped_packets'],2);self.assertEqual(duplicated.queued_bytes,0)
 async def test_actual_udp_echo_crosses_both_faulted_directions(self):
  class Echo(asyncio.DatagramProtocol):
   def connection_made(self,transport):self.transport=transport
   def datagram_received(self,data,address):self.transport.sendto(data,address)
  loop=asyncio.get_running_loop();echo,_=await loop.create_datagram_endpoint(Echo,local_addr=('127.0.0.1',0))
  with tempfile.TemporaryDirectory(prefix='udp-fault-test-') as folder:
   root=Path(folder);config={**BASE,'latency_ms':10,'jitter_ms':15,'loss':.1,'duplicate':.2};(root/'config.json').write_text(json.dumps(config))
   process=subprocess.Popen([sys.executable,str(Path(__file__).with_name('proxy.py')),'--listen','0','--host',str(echo.get_extra_info('sockname')[1]),'--config',str(root/'config.json'),'--out',str(root/'run'),'--seed','99'],stdout=subprocess.DEVNULL)
   client=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);client.setblocking(False);client.bind(('127.0.0.1',0))
   try:
    deadline=loop.time()+5
    while not (root/'run/ready.json').exists() and loop.time()<deadline:await asyncio.sleep(.02)
    self.assertTrue((root/'run/ready.json').exists());port=json.loads((root/'run/ready.json').read_text())['listen']
    for i in range(100):client.sendto(i.to_bytes(4,'little'),('127.0.0.1',port));await asyncio.sleep(.001)
    received=[];deadline=loop.time()+2
    while loop.time()<deadline:
     try:
      data=await asyncio.wait_for(loop.sock_recv(client,100),.1);self.assertEqual(len(data),4);received.append(int.from_bytes(data,'little'))
     except asyncio.TimeoutError:pass
    self.assertGreater(len(set(received)),40);self.assertLess(len(set(received)),100);self.assertGreater(len(received),len(set(received)))
   finally:
    client.close();process.send_signal(signal.SIGTERM);await asyncio.to_thread(process.wait,5);echo.close()
   self.assertEqual(process.returncode,0)
   receipt=json.loads((root/'run/receipt.json').read_text())
   for stats in receipt['directions'].values():
    self.assertGreater(stats['loss_dropped_packets'],0);self.assertGreater(stats['duplicated_packets'],0);self.assertGreater(stats['reordered_packets'],0)
    self.assertGreaterEqual(stats['delay_p50_ms'],10);self.assertLessEqual(stats['max_queued_bytes'],65536)
if __name__=='__main__':unittest.main()

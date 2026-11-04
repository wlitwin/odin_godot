import pathlib,socket,struct,tempfile,time,unittest
from relay import Relay,HEADER,HELLO
class Receiver:
 def __init__(self,relay,role):
  self.socket=socket.create_connection(('127.0.0.1',relay.port));self.socket.settimeout(2);self.socket.sendall(HELLO.pack(b'B3NP',role,1));self.data=bytearray()
 def packet(self):
  while True:
   while len(self.data)<HEADER.size:self.data.extend(self.socket.recv(65536))
   magic,n,channel,round,seq=HEADER.unpack(self.data[:HEADER.size]);assert magic==b'B3PK'
   while len(self.data)<HEADER.size+n:self.data.extend(self.socket.recv(65536))
   body=bytes(self.data[HEADER.size:HEADER.size+n]);del self.data[:HEADER.size+n]
   if channel!=2:return channel,seq,body
 def send(self,channel,seq,body):self.socket.sendall(HEADER.pack(b'B3PK',len(body),channel,0,seq)+body)
class RelayTests(unittest.TestCase):
 def test_reliable_does_not_advance_ordered_stream_highwater(self):
  with tempfile.TemporaryDirectory() as tmp:
   relay=Relay(pathlib.Path(tmp)/'trace.jsonl',ordered=True)
   a=Receiver(relay,1);z=Receiver(relay,2)
   try:
    relay.configure(reorder=10000)
    a.send(1,1,b'older-stream-delayed');a.send(0,2,b'reliable-first')
    relay.wait_sent(1,2);relay.advance(0)
    self.assertEqual(z.packet(),(0,2,b'reliable-first'))
    relay.advance(3)
    self.assertEqual(z.packet(),(1,1,b'older-stream-delayed'))
    self.assertNotIn('drop_stale_ordered',relay.summary()['counts'])
   finally:a.socket.close();z.socket.close();relay.close()
if __name__=='__main__':unittest.main()

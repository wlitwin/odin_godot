from pathlib import Path
import importlib.util,json,struct,sys
spec=importlib.util.spec_from_file_location('ack_link',Path(__file__).with_name('proxy.py'));p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
def packet(kind,version=1,epoch=1):
 body=bytes(32);header=bytearray(52);header[:4]=b'RPLY';struct.pack_into('<HHQQQQI',header,4,version,kind,epoch,10,1,1,len(body));struct.pack_into('<Q',header,44,p.digest(body,p.digest(header[:44])));return bytes(header)+body
def selected(data):return p.ack_only(p.envelopes(data))
assert selected(b'ENET'+packet(11))
assert selected(packet(4)+packet(11)+packet(15))
for kind in (1,2,3,5,6,7,8,9,10,12,13,14,16,17,18,19,20,21):assert not selected(packet(11)+packet(kind)),kind
assert not selected(packet(4)) and not selected(packet(11,version=2)) and not selected(packet(11,epoch=0))
bad=bytearray(packet(11));bad[-1]^=1;assert not selected(bad)
assert not selected(packet(11)[:-1])
for path in sys.argv[1:]:
 dropped=json.loads((Path(path)/'proxy/dropped.json').read_text());assert p.ack_only(dropped['envelopes'])
print('REPLAY_ACK_PROXY_TEST_OK')

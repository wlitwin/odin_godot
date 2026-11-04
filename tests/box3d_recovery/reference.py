#!/usr/bin/env python3
"""Independent LE framing/hash/default checks on a real native fixture packet.
This intentionally is not a second native importer or proof of all graph rules.
"""
from pathlib import Path
import hashlib,json,struct,sys
p=Path(sys.argv[1]);data=p.read_bytes()
u32=lambda offset:struct.unpack_from('<I',data,offset)[0]
u64=lambda offset:struct.unpack_from('<Q',data,offset)[0]
assert data[:8]==b'OGB3REC\0'
assert [u32(i) for i in (8,12,16,20)]==[1,4,192,12]
assert u64(24)==1 and u64(32)==len(data)
assert all(any(data[o:o+32]) for o in (48,80,112))
assert data[144:176]==hashlib.sha256(data[192:]).digest()
assert data[184:192]==bytes(8)
assets=[(1,1,(5,.5,5),(0,0,0),0),(2,1,(.5,.5,.5),(0,0,0),0),(3,2,(0,0,0),(0,0,0),4)]
asset_desc=b'ogb3-primitives-assets-v1\0'+b''.join(struct.pack('<II7fI',i,k,*a,*b,r,0) for i,k,a,b,r in assets)
assert hashlib.sha256(asset_desc).digest()==data[80:112]
sections=[];offset=192
while offset<len(data):
 tag,version,records,length=struct.unpack_from('<HHIQ',data,offset)
 assert (tag,version,records)==(len(sections)+1,1,1)
 assert length<=len(data)-offset-16
 sections.append(data[offset+16:offset+16+length]);offset+=16+length
assert len(sections)==12 and offset==len(data)
config=struct.unpack('<10fiBfiiQi2fi5i4B',sections[0])
assert config[:3]==(0,-10,0)
assert config[10]==2 # restitutionIterations
assert config[11]==0 # pinned default restitution propagation disabled
assert struct.pack('<f',config[12])==struct.pack('<f',0.2) # isotropic inertia tolerance
assert config[13:15]==(0,4) # compound count and fixed admitted SIMD width
assert config[15]==3 # stepIndex
assert struct.pack('<f',config[17])==struct.pack('<f',1/struct.unpack('<f',struct.pack('<f',struct.unpack('<f',struct.pack('<f',1/60))[0]/4))[0])
assert config[-4:]==(1,1,1,1)
# ID pool free-list order is explicit and has no padding/alignment bytes.
offset=0
for _ in range(6):
 next_index,free_count=struct.unpack_from('<iI',sections[1],offset)
 assert 0<=free_count<=next_index<=512
 free=struct.unpack_from('<'+'i'*free_count,sections[1],offset+8)
 assert len(set(free))==len(free) and all(0<=i<next_index for i in free)
 offset+=8+free_count*4
assert offset==len(sections[1])
print(json.dumps({'recovery_format':1,'solver_format':4,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'section_payload_bytes':[len(s) for s in sections],'reference':'LE/header/section/hash/asset/default/pool checks passed'}))

#!/usr/bin/env python3
"""Pure parser controls. Mutated executable bytes are NEVER passed to dlopen."""
import argparse,hashlib,json,pathlib,random,struct,subprocess
p=argparse.ArgumentParser();p.add_argument('--probe',required=True);p.add_argument('--macho',required=True);p.add_argument('--elf',required=True);p.add_argument('--profile0');p.add_argument('--out',required=True);a=p.parse_args();out=pathlib.Path(a.out).resolve();out.mkdir(parents=True,exist_ok=False)
m=bytearray(pathlib.Path(a.macho).read_bytes());e=bytearray(pathlib.Path(a.elf).read_bytes());cases=[]
u16=lambda b,o:struct.unpack_from('<H',b,o)[0];u32=lambda b,o:struct.unpack_from('<I',b,o)[0];u64=lambda b,o:struct.unpack_from('<Q',b,o)[0]
def put(b,o,v,n=4):struct.pack_into('<'+{2:'H',4:'I',8:'Q'}[n],b,o,v)
def add(name,data,arch,good=False):cases.append((name,bytes(data),arch,good))
def patch(name,b,o,v,n=4,arch='arm64'):
 c=b.copy();put(c,o,v,n);add(name,c,arch)
def mc(b):
 pos=32;r=[]
 for _ in range(u32(b,16)):
  cmd,size=u32(b,pos),u32(b,pos+4);r.append((cmd,pos,size));pos+=size
 return r
cmds=mc(m);sym=next(o for c,o,s in cmds if c==2);deps=[(c,o,s) for c,o,s in cmds if c in [12,0x80000018]];exp=next(o for c,o,s in cmds if c==0x80000033);fix=next(o for c,o,s in cmds if c==0x80000034)
add('macho-good',m,'arm64',True);add('elf-good',e,'x64',True)
if a.profile0:add('profile0-good',pathlib.Path(a.profile0).read_bytes(),'arm64',True)
for cut in [0,1,3,4,16,31,32,len(m)//2,len(m)-1]:add('macho-truncated-'+str(cut),m[:cut],'arm64')
patch('macho-wrong-arch',m,4,0x1000007)
patch('macho-command-count-over',m,16,1025)
patch('macho-command-size-over',m,36,0xfffffff8)
patch('macho-sym-offset-over',m,sym+8,0xffffffff)
patch('macho-sym-count-over',m,sym+12,0xffffffff)
patch('macho-strsize-zero',m,sym+20,0)
patch('macho-export-range-over',m,exp+8,0xffffffff)
patch('macho-fixups-range-over',m,fix+8,0xffffffff)
# Import library ordinal must identify the canonical backend, not libSystem.
c=m.copy();so,n,st,sz=struct.unpack_from('<IIII',c,sym+8)
for i in range(n):
 at=so+16*i;idx=u32(c,at);name=bytes(c[st+idx:]).split(b'\0',1)[0]
 if name.startswith(b'_ogb3_') and c[at+4]&0x0e==0:
  put(c,at+6,0xfe00,2);break
else:raise AssertionError('native import absent')
add('macho-flat-native-ordinal',c,'arm64')
# Same-size symbol spelling hides definition from nlist; export trie remains a
# separately scanned source of runtime definitions in the next control below.
c=m.copy();so,n,st,sz=struct.unpack_from('<IIII',c,sym+8)
for i in range(n):
 at=so+16*i;idx=u32(c,at);name=bytes(c[st+idx:]).split(b'\0',1)[0]
 if name.startswith(b'_ogb3_'):
  c[at+4]=0x0f;break
add('macho-defined-native',c,'arm64')
# Unknown dependency is denied even while canonical libogb3 remains present.
c=m.copy();other=next(o for k,o,s in deps if b'libogb3' not in bytes(m[o:o+s]));start=other+u32(m,other+8);end=bytes(c).index(b'\0',start);c[start:end]=b'X'*(end-start);add('macho-canonical-plus-foreign-dep',c,'arm64')
c=m.copy();native=next((o,s) for k,o,s in deps if b'libogb3' in bytes(m[o:o+s]));start=native[0]+u32(m,native[0]+8);end=bytes(c).index(b'\0',start);c[start:end]=b'Y'*(end-start);add('macho-unrelated-renamed-native',c,'arm64')
# Standard big-endian fat32/fat64 wrapper with unchanged slice-relative offsets.
for wide in [False,True]:
 offset=4096;head=struct.pack('>II',0xcafebabf if wide else 0xcafebabe,1)
 arch=struct.pack('>IIQQII',0x100000c,0,offset,len(m),12,0) if wide else struct.pack('>IIIII',0x100000c,0,offset,len(m),12)
 fat=bytearray(head+arch);fat+=bytes(offset-len(fat));fat+=m;add('fat'+str(64 if wide else 32)+'-good',fat,'arm64',True)
 bad=fat.copy();struct.pack_into('>I',bad,4,65);add('fat'+str(wide)+'-count',bad,'arm64')
 bad=fat.copy();struct.pack_into('>Q' if wide else '>I',bad,16,0xffffffffffffffff if wide else 0xffffffff);add('fat'+str(wide)+'-offset',bad,'arm64')
sh=u64(e,40);shn=u16(e,60);secs=[sh+64*i for i in range(shn)];dynsym=next(o for o in secs if u32(e,o+4)==11);dynamic=next(o for o in secs if u32(e,o+4)==6);strsec=sh+64*u32(e,dynamic+40)
ph=u64(e,32);phn=u16(e,56);loads=[ph+56*i for i in range(phn) if u32(e,ph+56*i)==1];pdyn=next(ph+56*i for i in range(phn) if u32(e,ph+56*i)==2)
def dynset(b,tag,value):
 off,size=u64(b,dynamic+24),u64(b,dynamic+32)
 for at in range(off,off+size,16):
  if u64(b,at)==tag:put(b,at+8,value,8);return
 raise AssertionError(tag)
for cut in [0,1,4,63,64,len(e)//2,len(e)-1]:add('elf-truncated-'+str(cut),e[:cut],'x64')
patch('elf-sectionless',e,60,0,2,'x64')
patch('elf-section-offset-over',e,40,0xffffffffffffffff,8,'x64')
patch('elf-zero-dynstr',e,strsec+32,0,8,'x64')
# Exact early SYMTAB/zero-linked-string-table bypass reported by coordinator.
regular=next(o for o in secs if u32(e,o+4)==2);linked=sh+64*u32(e,regular+40);patch('elf-early-symtab-zero-strtab',e,linked+32,0,8,'x64')
c=e.copy();put(c,dynsym+16,u64(c,dynsym+16)+24,8);dynset(c,6,u64(c,dynsym+16));add('elf-dynsym-va-consistent-lie',c,'x64')
c=e.copy();put(c,strsec+16,u64(c,strsec+16)+1,8);dynset(c,5,u64(c,strsec+16));add('elf-dynstr-va-consistent-lie',c,'x64')
c=e.copy();put(c,dynamic+16,u64(c,dynamic+16)+16,8);put(c,pdyn+16,u64(c,pdyn+16)+16,8);add('elf-dynamic-va-consistent-lie',c,'x64')
patch('elf-dynsym-clean-file-offset-lie',e,dynsym+24,u64(e,dynsym+24)+24,8,'x64')
c=e.copy();first=loads[0];second=loads[1];put(c,second+16,u64(c,first+16),8);put(c,second+40,u64(c,first+40),8);add('elf-overlapping-va-translations',c,'x64')
# Rename libc to a foreign leaf while canonical backend remains present.
c=e.copy();st,sz=u64(c,strsec+24),u64(c,strsec+32);at=bytes(c).index(b'libc.so.6\0',st,st+sz);c[at:at+9]=b'foreignxx';add('elf-canonical-plus-foreign-dep',c,'x64')
c=e.copy();at=bytes(c).index(b'libogb3.so\0',st,st+sz);c[at:at+10]=b'unrelatedx';add('elf-unrelated-renamed-native',c,'x64')
# Malformed metadata fuzz is parser-only, never executed or OS-loaded.
rng=random.Random(0xB3A);fuzz=[]
for i in range(128):
 source=m if i%2==0 else e;data=source.copy()
 for _ in range(1+rng.randrange(3)):
  offset=rng.randrange(min(len(data),4096));data[offset]^=1<<rng.randrange(8)
 fuzz.append(('fuzz-'+str(i),bytes(data),'arm64' if i%2==0 else 'x64',None))
results=[]
for name,data,arch,expected in cases+fuzz:
 f=out/(name+'.bin');f.write_bytes(data);r=subprocess.run([a.probe,str(f),arch],capture_output=True,text=True,timeout=5)
 if r.returncode:raise AssertionError((name,r.returncode,r.stdout,r.stderr))
 value=json.loads(r.stdout);accepted=value['error']=='None'
 if expected is not None and accepted!=expected:raise AssertionError((name,expected,value))
 results.append({'name':name,'arch':arch,'expected':expected,'diagnostic':value,'sha256':hashlib.sha256(data).hexdigest()})
report={'result':'PASS','targeted':len(cases),'fuzz':len(fuzz),'fuzz_accepted':sum(x['diagnostic']['error']=='None' for x in results if x['expected'] is None),'never_dlopen_mutations':True,'results':results};(out/'results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='results'},indent=2))

#!/usr/bin/env python3
"""Public-ABI process-isolated malformed recovery protocol acceptance.

Mutations rehash payloads deliberately: a checksum is not a semantic validator.
Accepted finite scalar changes may be valid; every success must remain safely
step-able, leave the published world unchanged, and balance all native owners.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def rehash(data):
    data=bytearray(data)
    if len(data)>=192:
        data[144:176]=hashlib.sha256(data[192:]).digest()
    return data

def main():
    ap=argparse.ArgumentParser();ap.add_argument('archive',type=Path);ap.add_argument('output',type=Path)
    ap.add_argument('--cases',type=int,default=384);ap.add_argument('--cc',default=os.environ.get('CC','cc'))
    args=ap.parse_args();assert 0<=args.cases<=10000
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    archive=out/'libogb3.a';shutil.copyfile(args.archive.resolve(),archive)
    compiler=[args.cc,'-std=c17','-O1','-g','-UNDEBUG','-I'+str(ROOT/'box3d/native'),str(ROOT/'tests/box3d_protocol/recovery_wire_probe.c'),str(archive)]
    if sys.platform!='darwin':compiler+=['-lm','-pthread']
    compiler+=['-o',str(out/'probe')]
    build=subprocess.run(compiler,capture_output=True,text=True);(out/'build.log').write_text(build.stdout+build.stderr)
    assert build.returncode==0,build.stderr
    encoded=subprocess.run([str(out/'probe'),'encode',str(out/'baseline.bin')],capture_output=True,text=True)
    (out/'encode.log').write_text(encoded.stdout+encoded.stderr);assert encoded.returncode==0,encoded.stdout+encoded.stderr
    baseline=(out/'baseline.bin').read_bytes();assert baseline[:8]==b'OGB3REC\0'
    assert len(baseline)==struct.unpack_from('<Q',baseline,32)[0]
    section_offsets=[];pos=192
    while pos<len(baseline):
        tag,version,records,n=struct.unpack_from('<HHIQ',baseline,pos)
        assert version==1 and records==1 and tag==len(section_offsets)+1
        section_offsets.append((pos,n));pos+=16+n
    assert pos==len(baseline) and len(section_offsets)==12
    cases=[('valid',baseline)]
    for cut in (0,1,7,8,15,31,63,127,191,192,len(baseline)-1):cases.append((f'truncated-{cut}',baseline[:cut]))
    cases.append(('trailing',baseline+b'\0'))
    for i in (0,7,8,12,16,20,24,32,40,48,80,112,144,176,184):
        value=bytearray(baseline);value[i]^=128;cases.append((f'header-{i}',value))
    for section,(start,n) in enumerate(section_offsets,1):
        for name,offset,fmt,value in [('tag',0,'H',65535),('version',2,'H',2),('records',4,'I',0xffffffff),('length',8,'Q',0xffffffffffffffff)]:
            data=bytearray(baseline);struct.pack_into('<'+fmt,data,start+offset,value);cases.append((f'section-{section}-{name}',rehash(data)))
    rng=random.Random(0xB03D)
    for i in range(args.cases):
        data=bytearray(baseline);start=rng.randrange(192,len(data));width=min(rng.choice((1,2,4,8)),len(data)-start)
        operation=rng.randrange(4)
        if operation==0:data[start:start+width]=bytes(width)
        elif operation==1:data[start:start+width]=b'\xff'*width
        elif operation==2:data[start]^=1<<rng.randrange(8)
        else:data[start:start+width]=rng.randbytes(width)
        cases.append((f'mutation-{i}-at-{start}-width-{width}',rehash(data)))
    outcomes=Counter();records=[]
    for index,(label,data) in enumerate(cases):
        case=out/'current.bin';case.write_bytes(data)
        result=subprocess.run([str(out/'probe'),'read',str(case)],capture_output=True,text=True,timeout=10)
        if result.returncode:
            failure=out/(label+'.bin');failure.write_bytes(data)
            (out/(label+'.log')).write_text(result.stdout+result.stderr)
            raise AssertionError((label,'process failure',result.returncode,result.stdout,result.stderr))
        record=json.loads(result.stdout);record.update(case=label,sha256=hashlib.sha256(data).hexdigest());records.append(record)
        if not label.startswith('mutation') and label!='valid':assert record['status']!=0,(label,record)
        if label=='valid':assert record['status']==0,record
        outcomes[record['status']]+=1
    report={'status':'BOX3D_RECOVERY_PROTOCOL_FUZZ_OK','cases':len(cases),'outcomes':dict(outcomes),'archive':str(args.archive.resolve()),'archive_sha256':sha(archive),'compiler':compiler,'source_sha256':{str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'tests/box3d_protocol/recovery_wire_probe.c',Path(__file__).resolve()]},'records':records,'scope':'Public decoder in fresh process for each case. Accepted results restore/step8; every result preserves published solver and native+wrapper owners. Not exhaustive fuzzing or final integrated framework acceptance.'}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ['status','cases','outcomes','archive_sha256']}))

if __name__=='__main__':main()

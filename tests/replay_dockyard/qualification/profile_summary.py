#!/usr/bin/env python3
"""Summarize an owned raw Gecko diagnostic; never converts it to admission."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def summarize(case):
    result={'scope':'Sampling diagnosis only; no phase subtraction, profiler overhead correction or unprofiled budget qualification','actors':{}}
    for role in ['host','client']:
        file=case/role/'gecko-profile.json';profile=json.loads(file.read_text());threads=[]
        def visit(process):
            for thread in process.get('threads',[]):
                strings=thread.get('stringTable',[])
                if not any('dockyard_duo::qualification_frame' in s for s in strings):continue
                frame=thread['frameTable'];stack=thread['stackTable'];samples=thread['samples'];locations=frame['schema']['location']
                prefix=stack['schema']['prefix'];frame_index=stack['schema']['frame'];memo={None:()}
                def names(index):
                    if index not in memo:
                        row=stack['data'][index];memo[index]=names(row[prefix])+(strings[frame['data'][row[frame_index]][locations]],)
                    return memo[index]
                inclusive=Counter();leaf=Counter();count=0
                for row in samples['data']:
                    path=names(row[samples['schema']['stack']]);at=next((i for i,s in enumerate(path) if 'dockyard_duo::qualification_frame' in s),None)
                    if at is None:continue
                    count+=1
                    for name in set(path[at:]):inclusive[name]+=1
                    if path:leaf[path[-1]]+=1
                threads.append(dict(name=thread['name'],pid=thread['pid'],tid=thread['tid'],sample_count=len(samples['data']),inside_operation_samples=count,
                    retained_sample_range_ms=[samples['data'][0][samples['schema']['time']],samples['data'][-1][samples['schema']['time']]],
                    top_inclusive=inclusive.most_common(20),top_leaf=leaf.most_common(20)))
            for child in process.get('processes',[]):visit(child)
        visit(profile)
        slow=[]
        for line in (case/role/'console.ndjson').read_text().splitlines():
            row=json.loads(line)
            if row['text'].startswith('SAMPLE_OPERATION_SLOW '):slow.append(json.loads(row['text'].partition(' ')[2]))
        result['actors'][role]=dict(profile_sha256=sha(file),profile_bytes=file.stat().st_size,threads=threads,slow_operation_rows=slow,
            limitation='Ring buffer covers only the retained sample range; raw CPU sampling may fail to reproduce an unprofiled outlier. Unnamed wasm/native frames remain unresolved.')
    return result
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();result=summarize(a.case)
    with a.out.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
    for role,r in result['actors'].items():print(role,'operation_threads',len(r['threads']),'slow_rows',[(v['category'],v['elapsed_us']) for v in r['slow_operation_rows']])
if __name__=='__main__':main()

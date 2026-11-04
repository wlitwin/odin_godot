#!/usr/bin/env python3
"""Read a triggered Gecko profile; retain uncertainty and never admit timings."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

PHASE_SOURCE='https://github.com/firefox-devtools/profiler/blob/main/src/types/profile.ts'

def value(row,schema,key,default=None):
    index=schema.get(key)
    return row[index] if index is not None and index<len(row) else default

def symbol(text):
    return re.split(r' \(https?://',text,maxsplit=1)[0][:500]

def marker_intervals(thread):
    """Unused marker times are arbitrary; pair split intervals by name."""
    table=thread.get('markers',{});schema=table.get('schema',{});strings=thread.get('stringTable',[])
    pending={};result=[]
    for row in table.get('data',[]):
        name=strings[value(row,schema,'name')];phase=value(row,schema,'phase')
        data=value(row,schema,'data',{}) or {};kind=data.get('type')
        entry=dict(name=symbol(name),type=kind)
        if phase==0:
            at=value(row,schema,'startTime');result.append(dict(entry,start=at,end=at,boundary='instant'))
        elif phase==1:
            result.append(dict(entry,start=value(row,schema,'startTime'),end=value(row,schema,'endTime'),boundary='interval'))
        elif phase==2:
            pending.setdefault(name,[]).append((value(row,schema,'startTime'),entry))
        elif phase==3:
            end=value(row,schema,'endTime');stack=pending.get(name,[])
            if stack:
                start,entry=stack.pop();result.append(dict(entry,start=start,end=end,boundary='paired_interval'))
            else:result.append(dict(entry,start=end,end=end,boundary='unmatched_end'))
    for stack in pending.values():
        for start,entry in stack:result.append(dict(entry,start=start,end=start,boundary='unmatched_start'))
    return [r for r in result if r['start'] is not None and r['end'] is not None]

def summarize(case):
    report=json.loads((case/'report.json').read_text())
    if report.get('measurement_mode')!='CPU_PROFILER_DIAGNOSTIC_NOT_ADMISSION':raise ValueError('explicit profiler diagnostic required')
    trigger=report.get('trace_trigger');marker=report.get('trace_browser_marker')
    if not trigger or not marker:raise ValueError('actual trigger and browser correlation marker required')
    if trigger['row']!=marker['row']:raise ValueError('console and browser trigger differ')
    end=marker['browser_time_origin_ms']+marker['browser_now_ms'];start=end-trigger['row']['elapsed_us']/1000
    file=case/trigger['role']/'gecko-profile.json';profile=json.loads(file.read_text());threads=[]
    def visit(process):
        origin=process['meta']['startTime'];units=process['meta'].get('sampleUnits',profile['meta'].get('sampleUnits',{}))
        if units.get('time')!='ms':raise ValueError('unsupported profiler time unit')
        for thread in process.get('threads',[]):
            strings=thread.get('stringTable',[]);samples=thread['samples'];schema=samples['schema']
            selected=[r for r in samples['data'] if start-5<=origin+value(r,schema,'time')<=end+5]
            if not selected:continue
            operation_thread=any('dockyard_duo::qualification_frame' in s for s in strings)
            record=dict(name=thread['name'],pid=thread['pid'],tid=thread['tid'],operation_thread=operation_thread,
              sample_count=len(selected),cpu_delta_unit=units.get('threadCPUDelta'),
              sampled_cpu_delta_sum_raw=sum(value(r,schema,'threadCPUDelta',0) or 0 for r in selected))
            gaps=[dict(start_offset_ms=origin+value(a,schema,'time')-end,end_offset_ms=origin+value(b,schema,'time')-end,
                       wall_gap_ms=value(b,schema,'time')-value(a,schema,'time'),next_cpu_delta_raw=value(b,schema,'threadCPUDelta'))
                  for a,b in zip(selected,selected[1:])]
            record['largest_sample_gap']=max(gaps,key=lambda r:r['wall_gap_ms'],default=None)
            record['retained_range_epoch_ms']=[origin+value(samples['data'][0],schema,'time'),origin+value(samples['data'][-1],schema,'time')]
            if operation_thread:
                frame=thread['frameTable'];stack=thread['stackTable'];memo={None:()}
                def names(index):
                    if index not in memo:
                        row=stack['data'][index];memo[index]=names(value(row,stack['schema'],'prefix'))+(symbol(strings[value(frame['data'][value(row,stack['schema'],'frame')],frame['schema'],'location')]),)
                    return memo[index]
                leaf=Counter();near=[]
                for row in selected:
                    path=names(value(row,schema,'stack'));leaf.update(path[-1:])
                    near.append(dict(end_offset_ms=origin+value(row,schema,'time')-end,cpu_delta_raw=value(row,schema,'threadCPUDelta'),stack_tail=path[-8:]))
                record['nearby_samples']=near;record['top_leaf']=leaf.most_common(10)
                record['overlapping_markers']=[dict(name=r['name'],type=r['type'],boundary=r['boundary'],
                  start_offset_ms=origin+r['start']-end,end_offset_ms=origin+r['end']-end)
                  for r in marker_intervals(thread) if origin+r['start']<=end+5 and origin+r['end']>=start-5]
            threads.append(record)
        for child in process.get('processes',[]):visit(child)
    visit(profile)
    operation=[t for t in threads if t['operation_thread']]
    covered=any(t['retained_range_epoch_ms'][0]<=start and t['retained_range_epoch_ms'][1]>=end for t in operation)
    return dict(schema_version=1,result='TRIGGER_WINDOW_RETAINED_NOT_ADMISSION' if covered else 'TRIGGER_WINDOW_MISSING_NOT_ADMISSION',
      profile_sha256=hashlib.sha256(file.read_bytes()).hexdigest(),profile_bytes=file.stat().st_size,
      profile_format=profile['meta']['version'],trigger=trigger,
      estimated_operation_epoch_ms=[start,end],node_minus_browser_marker_ms=trigger['node_arrival_wall_ms']-end,
      threads=threads,marker_phase_source=PHASE_SOURCE,release_admission=False,
      limitations=['Window is estimated from a post-call console marker; console delivery adds unknown latency.',
       'Sampling gaps and thread CPU deltas do not identify an OS scheduling, browser wait or profiler cause.',
       'CPU sums cover the displayed sample window, not an exact accounting of the Room.frame operation.',
       'Profiler overhead can affect the observed call; no wall-time subtraction or unprofiled qualification is allowed.',
       'Split markers whose other boundary is outside the ring are kept as unmatched boundaries, not invented intervals.'])

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    result=summarize(a.case)
    with a.out.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
    print(json.dumps(dict(result=result['result'],operation_threads=sum(t['operation_thread'] for t in result['threads']),threads=len(result['threads']))))
if __name__=='__main__':main()

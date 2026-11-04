#!/usr/bin/env python3
"""Correlate bounded process observations without adjusting operation timings."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex


def brackets(rows,columns,start_ms,end_ms):
    if start_ms>end_ms:raise ValueError('inverted observation envelope')
    wall=columns.index('wall_ms');query=columns.index('query_ns')
    before=[r for r in rows if r[wall]+r[query]/1e6<=start_ms]
    after=[r for r in rows if r[wall]>=end_ms]
    return (max(before,key=lambda r:r[wall]+r[query]/1e6) if before else None,
            min(after,key=lambda r:r[wall]) if after else None)


def clock_discrepancy_ms(rows,columns):
    wall=columns.index('wall_ms');mono=columns.index('monotonic_since_start_ns')
    return max((abs((b[wall]-a[wall])-(b[mono]-a[mono])/1e6) for a,b in zip(rows,rows[1:])),default=0)


def summarize(case):
    report=json.loads((case/'report.json').read_text());file=case/'process-state.json'
    if file.stat().st_size>8*1024*1024:raise ValueError('process observations beyond declared8MiB')
    observations=json.loads(file.read_text());rows=observations['rows'];columns=observations['columns'];index={name:i for i,name in enumerate(columns)}
    if not rows or len(rows)>8192 or observations['error']:raise ValueError('absent/excess/failed process observations')
    if observations['target_pid']!=observations['metadata']['selected_target']['pid']:raise ValueError('target binding mismatch')
    timebase=observations['cpu_timebase'];calibration=observations['metadata']['calibration']
    if any(timebase[k]!=calibration['mach_timebase'][k] for k in ['numer','denom']):raise ValueError('CPU calibration mismatch')
    if not .95<=calibration['ratio']<=1.05:raise ValueError('CPU calibration unavailable')
    for a,b in zip(rows,rows[1:]):
        if b[index['monotonic_since_start_ns']]<=a[index['monotonic_since_start_ns']]:raise ValueError('observer monotonic clock regressed')
        if b[index['user_ticks']]+b[index['system_ticks']]<a[index['user_ticks']]+a[index['system_ticks']]:raise ValueError('CPU counter regressed')
    discrepancy=clock_discrepancy_ms(rows,columns)
    result=dict(schema_version=1,result='NO_TRIGGER_NOT_ADMISSION',release_admission=False,
      process_observations_sha256=hashlib.sha256(file.read_bytes()).hexdigest(),target_pid=observations['target_pid'],
      retained_rows=len(rows),observation_bytes=file.stat().st_size,clock_discrepancy_max_ms=discrepancy,
      observer_gap_max_ms=max(((b[index['monotonic_since_start_ns']]-a[index['monotonic_since_start_ns']])/1e6 for a,b in zip(rows,rows[1:])),default=0),
      query_max_ms=max(r[index['query_ns']]/1e6 for r in rows),cpu_timebase=timebase,
      limitations=['Process CPU includes every target thread and work outside the call; it is not exact call CPU.',
       'The envelope assumes the in-call paired wall read and observer clocks had no unobserved wall step.',
       'Post-call browser markers have unknown console-delivery latency; their union only broadens the envelope.',
       'Target ownership is checked; highest-CPU child selection does not independently prove tab identity.',
       'Snapshots and cumulative counters cannot identify a complete scheduling/wait history or a cause.',
       'No phase subtraction, adjusted budget, or unprofiled qualification is allowed.'])
    args=shlex.split(observations['metadata']['selected_target']['command'])
    result['recorded_process_role']=args[-1] if args else None
    if result['recorded_process_role']!='tab':
        result['result']='CONTENT_PROCESS_ROLE_NOT_VERIFIED_NOT_ADMISSION';return result
    trigger=report.get('trace_trigger');marker=report.get('trace_browser_marker')
    if not trigger:return result
    if not marker or marker['row']!=trigger['row']:raise ValueError('trigger/browser marker mismatch')
    row=trigger['row'];elapsed=row['elapsed_us']/1000;anchor=row['after']['last_wall']
    if not row['clock_valid'] or row['after']['clock_poisoned']:raise ValueError('operation clock invalid')
    browser_end=marker['browser_time_origin_ms']+marker['browser_now_ms']
    start=min(anchor-elapsed-2,browser_end-elapsed);end=max(anchor+elapsed+2,browser_end)
    result.update(result='TRIGGER_ENVELOPE_MISSING_BRACKETS_NOT_ADMISSION',trigger=trigger,
      original_whole_call_ms=elapsed,paired_wall_anchor_ms=anchor,browser_post_call_marker_ms=browser_end,
      envelope_epoch_ms=[start,end])
    before,after=brackets(rows,columns,start,end)
    if before is None or after is None:return result
    if before[index['monotonic_since_start_ns']]>=after[index['monotonic_since_start_ns']]:
        result['result']='CLOCK_CORRELATION_UNCERTAIN_NOT_ADMISSION';return result
    raw=(after[index['user_ticks']]+after[index['system_ticks']])-(before[index['user_ticks']]+before[index['system_ticks']])
    cpu_ns=raw*timebase['numer']//timebase['denom']
    result.update(result='TRIGGER_BRACKETED_DIAGNOSTIC_NOT_ADMISSION' if discrepancy<=2 else 'CLOCK_CORRELATION_UNCERTAIN_NOT_ADMISSION',
      before_query=before,after_query=after,columns=columns,process_cpu_delta_raw_ticks=raw,
      process_cpu_bracket_ms=cpu_ns/1e6,process_cpu_below_original_call_wall=cpu_ns/1e6<elapsed if discrepancy<=2 else None,
      counters_delta={name:after[index[name]]-before[index[name]] for name in ['faults','pageins','cow_faults','context_switches']})
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();result=summarize(a.case)
    with a.out.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print(json.dumps({k:result.get(k) for k in ['result','original_whole_call_ms','process_cpu_bracket_ms','clock_discrepancy_max_ms']}))
if __name__=='__main__':main()

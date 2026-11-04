#!/usr/bin/env python3
"""Read retained samples without starting any process or changing raw evidence."""
import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def distribution(values):
    ordered=sorted(values)
    if not ordered:return dict(count=0,p95_ms=None,p99_ms=None,max_ms=None)
    return dict(count=len(ordered),p95_ms=ordered[math.ceil(.95*len(ordered))-1],p99_ms=ordered[math.ceil(.99*len(ordered))-1],max_ms=ordered[-1])
def assess(case):
    report=json.loads((case/'report.json').read_text());contract=json.loads((ROOT/'tests/box3d_web/contract.json').read_text())['budgets']
    observations={};violations=[];missing=[]
    if report.get('measurement_mode')=='CPU_PROFILER_DIAGNOSTIC_NOT_ADMISSION':missing.append('CPU profiler attached; diagnostic measurements cannot qualify the unprofiled contract')
    if report.get('measurement_mode')=='SYSTEM_TRACE_DIAGNOSTIC_NOT_ADMISSION':missing.append('System tracer attached; diagnostic measurements cannot qualify the unprofiled contract')
    if report.get('measurement_mode') in ['THREAD_STATE_DIAGNOSTIC_NOT_ADMISSION','THREAD_STATE_TRACE_DIAGNOSTIC_NOT_ADMISSION']:missing.append('Thread observer active; diagnostic measurements cannot qualify the unprofiled contract')
    if report.get('measurement_mode')=='PROCESS_STATE_DIAGNOSTIC_NOT_ADMISSION':missing.append('Process observer active; diagnostic measurements cannot qualify the unprofiled contract')
    if report.get('measurement_mode')=='INTERNAL_PHASE_DIAGNOSTIC_NOT_ADMISSION':missing.append('Internal phase clocks enabled; diagnostic measurements cannot qualify the unprofiled contract')
    if report.get('measurement_mode')=='COUNTER_DIAGNOSTIC_NOT_ADMISSION':missing.append('Counter diagnostic selected; this case cannot qualify the uninstrumented contract')
    if report.get('measurement_mode')=='NETWORK_FAULT_FUNCTIONAL_NOT_BASELINE':missing.append('network fault case; baseline timing admission is separate')
    for role in ['host','client']:
        rows=[];statuses=[];transfers=[];go=[];result_times=[];operation_ends=[]
        for line in (case/role/'console.ndjson').read_text().splitlines():
            entry=json.loads(line);tag,_,text=entry['text'].partition(' ')
            if tag=='SAMPLE_OPERATION':rows.extend(json.loads(text)['rows'])
            elif tag=='SAMPLE_STATUS':
                value=json.loads(text);statuses.append(value)
                if value.get('go'):go.append(entry['arrival_ms'])
            elif tag=='SAMPLE_QUALIFICATION_TRANSFER':transfers.append(json.loads(text))
            elif tag=='SAMPLE_RESULT':result_times.append(entry['arrival_ms'])
            elif tag=='SAMPLE_OPERATION_END':operation_ends.append(dict(json.loads(text),arrival_ms=entry['arrival_ms']))
        for sequence,row in enumerate(rows,1):
            if row['sequence']!=sequence or not row['clock_valid']:violations.append(role+': invalid operation sequence/clock')
            if row['error'] not in ['None',0]:violations.append(role+': operation error '+str(row['error']))
        normal=[r['elapsed_us']/1000 for r in rows if r['category']=='advance1' and r['after']['repairs']==r['before']['repairs']]
        repair=[r['elapsed_us']/1000 for r in rows if r['category']=='repair' and r['after']['repairs']-r['before']['repairs']==1 and r['planned_depth']==8 and r['executed_steps']==8]
        normal_d=distribution(normal);repair_d=distribution(repair)
        browser=json.loads((case/role/'browser-samples.json').read_text())
        end_ms=browser.get('operation_end_ms')
        intervals=[r for r in browser['intervals'] if end_ms is None or r[0]<=end_ms]
        frames=distribution([r[1] for r in intervals])
        buffered=report.get('operation_sampler')=='buffered_until_checked_close'
        if buffered and (len(operation_ends)!=1 or end_ms is None):missing.append(role+': buffered sampler end boundary')
        if operation_ends and (len(operation_ends)!=1 or operation_ends[0]['rows']!=len(rows)):violations.append(role+': incomplete/duplicate operation emission')
        renderer=(browser.get('gl') or {}).get('renderer','')
        if not renderer or any(v in renderer.lower() for v in ['swiftshader','llvmpipe','software']):violations.append(role+': hardware renderer not established')
        if not browser.get('isolation') or browser.get('viewport')!=[1280,720] or browser.get('dpr')!=1:violations.append(role+': isolation/reference viewport mismatch')
        if not browser.get('timer_positive_deltas_ms'):missing.append(role+': observed positive browser timer resolution')
        linear=max([r[1] for r in browser['memory']]+([browser['terminal_wasm_linear_bytes']] if browser.get('terminal_wasm_linear_bytes') is not None else []),default=None)
        admitted=max((r['admitted_bytes'] for r in statuses if r.get('native_observed') and r.get('admitted_bytes') is not None),default=None)
        if len(normal)<contract['normal_whole_entry_ms']['minimum_samples']:missing.append(role+': normal sample count')
        else:
            for metric,limit in [('p95_ms','p95_max'),('p99_ms','p99_max'),('max_ms','max')]:
                if normal_d[metric]>contract['normal_whole_entry_ms'][limit]:violations.append(role+': normal '+metric)
        if role=='client':
            if len(repair)<contract['correction8_whole_entry_ms']['minimum_samples']:missing.append('client: actual repair8 sample count')
            else:
                for metric,limit in [('p95_ms','p95_max'),('max_ms','max')]:
                    if repair_d[metric]>contract['correction8_whole_entry_ms'][limit]:violations.append('client: correction8 '+metric)
        for metric,limit in [('p95_ms','p95_max'),('p99_ms','p99_max')]:
            if frames[metric] is None:missing.append(role+': frame intervals')
            elif frames[metric]>contract['presentation_frame_interval_ms'][limit]:violations.append(role+': presentation '+metric)
        if browser['overflow'] or any(r[2]!='visible' for r in intervals):violations.append(role+': overflow/background samples')
        if not rows or len(rows)>65536:violations.append(role+': absent/excess operation rows')
        pairs=report[role].get('selected_pairs',[])
        if not pairs or any(v.get('bytesSent',0)<=0 or v.get('bytesReceived',0)<=0 for v in pairs):missing.append(role+': actual selected ICE traffic')
        if any(v.get('policy')!='relay' or v.get('local')!='relay' or v.get('remote')!='relay' or v.get('credentialExpires',0)<=0 for v in pairs):violations.append(role+': authenticated forced relay not established')
        for actual,cap,label in [(linear,contract['wasm_linear_memory_bytes_max'],'Wasm linear'),(admitted,contract['backend_admitted_bytes_max'],'Native admission')]:
            if actual is None:missing.append(role+': '+label)
            elif actual>cap:violations.append(role+': '+label)
        if report[role].get('cold_usable_menu_ms') is None:missing.append(role+': cold usable-menu timer')
        elif report[role]['cold_usable_menu_ms']>contract['cold_local_load_seconds_max']*1000:violations.append(role+': cold load')
        end_arrival=operation_ends[0]['arrival_ms'] if operation_ends else result_times[-1] if result_times else None
        duration=(end_arrival-go[0])/1000 if end_arrival is not None and go else None
        if duration is None or duration<contract['sustained_foreground_pair_seconds_min']:missing.append(role+': sustained foreground duration')
        observations[role]=dict(operation_rows=len(rows),categories=dict(Counter(r['category'] for r in rows)),normal=normal_d,repair8=repair_d,presentation=frames,
          sampled_wasm_linear_peak_bytes=linear,sampled_admitted_peak_bytes=admitted,transfers=transfers,cold_lobby_ms=report[role].get('cold_lobby_ms'),cold_usable_menu_ms=report[role].get('cold_usable_menu_ms'),go_to_checked_result_seconds=duration,
          duration_boundary='operation_end_before_close' if operation_ends else 'historical_checked_result',operation_ends=operation_ends,
          raw_presentation_intervals=len(browser['intervals']),measured_presentation_intervals=len(intervals),teardown_intervals_retained=len(browser['intervals'])-len(intervals),
          raw_sha256={f:digest(case/role/f) for f in ['console.ndjson','browser-samples.json']})
    if report['result']!='FUNCTIONAL_SAMPLES_COLLECTED':violations.append('actual pair failed')
    binding=json.loads((case/'export-binding.json').read_text())
    if binding['actual_exit']!=0 or not all(binding[k] for k in ['export_unchanged','helper_source_fence','service_clean']):violations.append('actual export/helper/service binding failed')
    wire=max((x['complete_wire_bytes'] for v in observations.values() for x in v['transfers']),default=None)
    if wire is None:missing.append('actual producer transfer bound')
    elif wire>contract['complete_frame_wire_bytes_max']:violations.append('complete wire bound')
    if wire is None or wire>contract['native_canonical_payload_bytes_max']:missing.append('Native canonical bound not established by conservative complete-wire upper bound')
    return dict(schema_version=1,result='BUDGET_REJECTED' if violations else 'MEASUREMENTS_INCOMPLETE' if missing else 'MEASURED_BUDGETS_PASS',
      observations=observations,violations=violations,missing=missing,quantiles='nearest rank ceil(p*N), milliseconds; no samples removed and no overhead subtraction',
      sampled_complete_wire_peak_bytes=wire,conservative_native_payload_upper_bound_bytes=wire,
      plan_sha256=digest(Path(__file__).with_name('plan.json')),contract_sha256=digest(ROOT/'tests/box3d_web/contract.json'),source_report_sha256=digest(case/'report.json'),
      buffered_plan_sha256=digest(Path(__file__).with_name('buffered-plan.json')) if report.get('operation_sampler')=='buffered_until_checked_close' else None,
      release_admission=False,scope='This case only. Matrix, faults, regressions, external Internet and human review remain separate requirements.')
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('case',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    result=assess(a.case)
    with a.out.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
    print(json.dumps(dict(result=result['result'],violations=result['violations'],missing=result['missing'])))
if __name__=='__main__':main()

#!/usr/bin/env python3
"""Versioned readonly hard-recovery eligibility audit; never reruns physics."""
import argparse
from pathlib import Path
from evidence import EndpointEvidence,strict_json,verify_pair,verify_observer_cohort,verify_dedicated_cohort,verify_32_pair_envelope,require,json_bytes,digest

VERSION='hard-recovery-observed-interval-v1'
p=argparse.ArgumentParser();p.add_argument('--case',required=True,type=Path);p.add_argument('--out',required=True,type=Path);p.add_argument('--auditor-version',default=VERSION);a=p.parse_args()
case=a.case.resolve();out=a.out.resolve();require(not out.exists(),'reaudit output already exists');out.mkdir(parents=True)
source=case/'result.json';old=strict_json(source.read_text());require(old['source_fence_unchanged'] is True,'original source fence failed')
report=dict(auditor=a.auditor_version,result='FAIL',scope='readonly same actual immutable processes; declared diagnostic contract/eligibility audit, no runtime changes',original_result=old['result'],original_report=str(source),original_sha256=digest(source.read_bytes()),processes=[],physics_rerun=False)
try:
 nodes=[]
 for record in old['processes']:
  role=record['role'];root=case/role;log=root/'godot.log'
  require(digest(log.read_bytes())==record['log_sha256'],'original endpoint log changed')
  endpoint=EndpointEvidence(old['framework'],role,root);endpoint.app_role=record.get('app_role',role);endpoint.require_go=old.get('cohort') in ('observer','dedicated')
  for line in log.read_text().splitlines():
   if line.startswith('{'):value=strict_json(line);endpoint.receive(value['event'].upper(),value)
   elif line.startswith('BOX3D_SLICE_'):
    mark,_,raw=line.partition(' ');kind=mark.removeprefix('BOX3D_SLICE_')
    if raw.startswith('{'):endpoint.receive(kind,strict_json(raw))
    elif kind in ('WAIT','ERROR'):endpoint.receive(kind,{'message':raw})
    else:raise ValueError(('malformed retained observation',line[:200]))
  require(not endpoint.errors,'endpoint had actual failure')
  clean=endpoint.teardown(record['exit_code'])
  report['processes'].append(dict(role=role,pid=record['pid'],exit_code=record['exit_code'],log_sha256=record['log_sha256'],cleanup=clean))
  nodes.append(endpoint)
 authority=nodes[0];pairs={}
 for follower in nodes[1:]:
  keys=authority.frames.keys()&follower.frames.keys()
  for key in keys:require(authority.frames[key].sig==follower.frames[key].sig and authority.frames[key].parts()==follower.frames[key].parts(),('retained full-state mismatch',follower.role,key))
  pairs[follower.role]=verify_pair(authority,follower,old['required_ticks'],keys)
 report['agreement_by_follower']=pairs
 if old.get('initial_dynamic_bodies')==32:
  report['envelope32']=verify_32_pair_envelope(nodes)
 if len(nodes)==3:
  validator=verify_dedicated_cohort if old.get('cohort')=='dedicated' else verify_observer_cohort
  report['cohort_contract']=validator(nodes,old['required_ticks'],300)
 report['auditor_sources']={f.name:digest(f.read_bytes()) for f in (Path(__file__).resolve(),Path(__file__).with_name('evidence.py'))}
 report['result']='PASS'
finally:(out/'report.json').write_bytes(json_bytes(report)+b'\n')
print(out/'report.json')

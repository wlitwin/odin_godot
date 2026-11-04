#!/usr/bin/env python3
"""Bounded actual Godot/ENet slice gate; no simulation or protocol implementation."""
from pathlib import Path
import argparse
import json
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent/'harness'))
from runner import Run

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',required=True,type=Path,help='new immutable evidence directory')
    parser.add_argument('--native',required=True,type=Path,help='verified P4 shared Native .dylib/.so')
    parser.add_argument('--godot',default='godot',help='official supported Godot binary')
    parser.add_argument('--odin',default='odin')
    parser.add_argument('--framework',choices=('kit','replay','both'),default='both')
    parser.add_argument('--cohort',choices=('pair','observer','dedicated'),default='pair',help='bounded pair or host+client+observer only')
    parser.add_argument('--end-tick',type=int,default=300,help='observer cohort stop-only shared tick')
    parser.add_argument('--configuration',choices=('Debug','Release'),default='Release')
    parser.add_argument('--ticks',type=int,default=240)
    parser.add_argument('--bodies',type=int,choices=(4,32),default=4,help='initial dynamic bodies;32 is pair-only')
    parser.add_argument('--seed',type=int,default=1)
    parser.add_argument('--timeout',type=float,default=90,help='observation timeout; never an admission clock')
    args=parser.parse_args()
    parser.error('ticks must be >=240') if args.ticks<240 else None
    parser.error('seed must be positive') if args.seed<=0 else None
    parser.error('32-body scope is pair only') if args.bodies==32 and args.cohort!='pair' else None
    parser.error('observer end tick must be >= required ticks') if args.cohort!='pair' and args.end_tick<args.ticks else None
    args.out=args.out.resolve()
    if args.out.exists():
        parser.error('output already exists; use a fresh immutable path')
    args.out.mkdir(parents=True)
    frameworks=('kit','replay') if args.framework=='both' else (args.framework,)
    results=[Run(args,ROOT,framework).run() for framework in frameworks]
    state='PASS' if all(x['result']=='PASS' for x in results) else ('NOT_READY' if all(x['result']=='NOT_READY' for x in results) else ('PARTIAL' if all(x['result'] in ('PASS','NOT_READY') for x in results) else 'FAIL'))
    summary=dict(result=state,scope=f'initial{args.bodies} independent actual Godot ENet '+{'pair':'Host+Client','observer':'Host+Client+Observer','dedicated':'DedicatedServer+Client1+Client2'}[args.cohort],frameworks=results,gate_b_4ms='UNMET/separate',control_truth_injection=False)
    (args.out/'report.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(dict(result=state,report=str(args.out/'report.json'),frameworks={x['framework']:x['result'] for x in results})))
    return 0 if state=='PASS' else (2 if state in ('NOT_READY','PARTIAL') else 1)

if __name__=='__main__':
    raise SystemExit(main())

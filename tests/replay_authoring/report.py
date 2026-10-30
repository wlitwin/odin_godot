"""Verify exact feature/source evidence and every planned peer receipt."""
from pathlib import Path
import difflib,hashlib,itertools,json,re,sys

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def changed_lines(before,after):
    diff=list(difflib.unified_diff(before.splitlines(),after.splitlines(),lineterm=''))
    a=[x[1:] for x in diff if x.startswith('+') and not x.startswith('+++')]
    b=[x[1:] for x in diff if x.startswith('-') and not x.startswith('---')]
    return {'added_physical':len(a),'removed_physical':len(b),'added_nonblank':sum(bool(x.strip()) for x in a),'removed_nonblank':sum(bool(x.strip()) for x in b)}

def report(root,allow_partial=False):
    root=Path(root);plan=json.loads((root/'run-plan.json').read_text());contract=json.loads((root/'contract.json').read_text());build=json.loads((root/'build.json').read_text())
    assert contract==json.loads((Path(__file__).parent/'contract.json').read_text()),'contract differs from the specified experiment'
    assert plan['cases'] and set(plan['cases'])<=set(contract['cases'])
    assert plan['conditions'] and set(plan['conditions'])<=set(contract['conditions'])
    assert isinstance(plan['repetitions'],int) and 1<=plan['repetitions']<=contract['repetitions']
    full=plan['cases']==contract['cases'] and plan['conditions']==contract['conditions'] and plan['repetitions']==contract['repetitions']
    assert full or allow_partial,'incomplete plan'
    assert len(plan['cases'])==len(set(plan['cases'])) and len(plan['conditions'])==len(set(plan['conditions']))
    for name,expected in build['binaries'].items():assert digest(root/name)==expected,('binary',name)
    features={}
    for impl in ('kit','replay'):
        source=json.loads((root/impl/'source.json').read_text())
        for name,expected in source.items():assert digest(root/impl/'project'/name)==expected,('source',impl,name)
        feature=json.loads((root/impl/'feature/changes.json').read_text());assert feature['implementation']==impl
        seen=set();counts={};patch=[];calls={};removed_calls={}
        for row in feature['files']:
            name=row['path'];assert name not in seen;seen.add(name)
            before=root/impl/'feature/before'/name;after=root/impl/'feature/after'/name
            assert digest(before)==row['before_sha256'] and digest(after)==row['after_sha256'] and digest(after)==digest(root/impl/'project'/name)
            delta=list(difflib.unified_diff(before.read_text().splitlines(),after.read_text().splitlines(),fromfile='a/'+name,tofile='b/'+name,lineterm=''));patch+=delta
            aliases='ksess' if impl=='kit' else 'r|p|net|rgd'
            for line in delta:
                if line[:1] in ('+','-') and not line.startswith(('+++','---')):
                    target=calls if line[0]=='+' else removed_calls
                    for call in re.findall(r'\b(?:'+aliases+r')\.[A-Za-z_][A-Za-z_0-9]*(?=\s*\()',line[1:]):target[call]=target.get(call,0)+1
            actual=changed_lines(before.read_text(),after.read_text())
            assert all(row[k]==v for k,v in actual.items()),('counts',impl,name)
            category=counts.setdefault(row['category'],{'files':0,**dict.fromkeys(actual,0)});category['files']+=1
            for k,v in actual.items():category[k]+=v
        assert seen
        for side in ('before','after'):
            base=root/impl/'feature'/side
            assert {str(p.relative_to(base)) for p in base.rglob('*') if p.is_file()}==seen,('unreported feature file',impl,side)
        assert (root/impl/'feature/feature.patch').read_text()=='\n'.join(patch)+'\n','patch differs from snapshots'
        features[impl]={'changed_files':len(seen),'categories':counts,'files':feature['files'],'library_call_occurrences':{'added':calls,'removed':removed_calls,'net_added':{k:v-removed_calls.get(k,0) for k,v in calls.items() if v>removed_calls.get(k,0)}}}
    runs=[];expected_receipts=set()
    for pair,condition,case,impl in itertools.product(range(1,plan['repetitions']+1),plan['conditions'],plan['cases'],('kit','replay')):
        folder=root/'runs'/str(pair)/condition/case/impl;final=None
        for seat,role in enumerate(('host','guest','helper'),1):
            path=folder/('success-'+role+'.json');expected_receipts.add(path)
            receipt=json.loads(path.read_text());assert receipt['role']==role and receipt['seat']==seat and receipt['implementation']==impl and receipt['scenario']==case
            cash=receipt['cash'];hp=receipt['hp'];assert len(cash)==3 and len(hp)==3 and hp==[10,4,10]
            assert all(type(v)==int and 0<=v<=0xffffffff for v in cash)
            allowed=[[3,3,0]] if case=='funded' else [[0,3,0]] if case=='funding_while_held' else [[0,3,3],[3,3,0]]
            assert cash in allowed and sum(cash)==receipt['conserved_total']
            if final is None:final=cash
            assert cash==final,('peer agreement',folder)
            trace=receipt['trace'];assert len(trace)>=20
            times=[x['ms'] for x in trace];assert times==sorted(times)
            if role=='host':
                for row in trace:
                    if row['phase'] in ('hold','unfunded','funding','result','continued_hold'):
                        total=sum(row['cash'])
                        if case=='funding_while_held':
                            allowed_totals=[0] if row['phase'] in ('hold','unfunded') else [0,3] if row['phase']=='funding' else [3]
                        else:allowed_totals=[6]
                        assert total in allowed_totals,('authority conservation trace',folder,row)
                        if row['hp'][1]==4:assert row['cash'] in allowed,('authority transfer trace',folder,row)

            held=[x for x in trace if x['phase']=='continued_hold'];assert held and held[-1]['ms']-held[0]['ms']>=2300
            assert all(x['cash']==cash and x['hp'][1]==4 for x in held)
            donor=(role=='host' if case=='funded' else role=='helper' if case=='funding_while_held' else role!='guest')
            assert [x['held'] for x in receipt['inputs']]==([True,False] if donor else [])
            if case=='funding_while_held':
                samples=[x for x in trace if x['phase']=='unfunded'];assert samples and samples[-1]['ms']-samples[0]['ms']>=2800
                assert all(x['cash']==[0,0,0] and x['hp'][1]==0 for x in samples) and receipt['unfunded_verified']
                if role=='helper':assert any('3 scrap' in x['prompt'] for x in samples)
        assert not list(folder.glob('failure-*.json'))
        for role in ('host','guest','helper'):assert json.loads((folder/('quiesced-'+role+'.json')).read_text())=={'ready':True}
        runs.append({'pair':pair,'condition':condition,'case':case,'implementation':impl,'cash':final,'winner':1 if case=='funded' or case=='contended' and final[0]==0 else 3})
    assert set((root/'runs').glob('*/*/*/*/success-*.json'))==expected_receipts
    full=plan['cases']==contract['cases'] and plan['conditions']==contract['conditions'] and plan['repetitions']==contract['repetitions']
    result={'feature':contract['feature'],'full_plan':full,'plan':plan,'feature_changes':features,'runs':runs,'peer_receipts':len(expected_receipts),'interpretation':'Changed source plus runtime acceptance. Not human authoring time, productivity, perceived responsiveness or full-framework superiority.'}
    temporary=root/'summary.json.pending';temporary.write_text(json.dumps(result,indent=2)+'\n');temporary.replace(root/'summary.json')
    return result
if __name__=='__main__':
    value=report(sys.argv[1],allow_partial=sys.argv[2:]==["--allow-partial"]);print('REPLAY_AUTHORING_REPORT_OK full_plan='+str(value['full_plan']).lower()+' peer_receipts='+str(value['peer_receipts']))

from pathlib import Path
import json,sys
out=Path(sys.argv[1]);mode=sys.argv[2]
assert mode in ('planned','crash','save')
if mode=='save':
    summary=json.loads((out/'browser/summary.json').read_text())
    for key in ['identity_creation_agreed','identity_preserved','stale_writer_preserved_archive','corrupt_archive_preserved','corrupt_identity_preserved']:assert summary[key],key
    isolation=json.loads((out/'browser/isolation.json').read_text())
    assert isolation['server_records_preserved'] and isolation['owner_namespace']=='replay-cavecrawl-owned' and isolation['server_namespace']=='replay-cavecrawl'
    first=next(e for e in summary['events'] if e['mode']=='create' and e['event']=='saved')
    resumed=next(e for e in summary['events'] if e['mode']=='resume' and e['event']=='saved')
    assert resumed['restored_hash']==first['hash'] and resumed['restored_tick']==first['tick'] and resumed['epoch']==2
    result={'pass':True,'mode':mode,'saved_tick':first['tick'],'saved_hash':first['hash'],'resume_epoch':2,'isolation':isolation,'checks':{k:v for k,v in summary.items() if k!='events'}}
else:
    events=json.loads((out/'browser/events.json').read_text())
    def one(name):
        found=[e for e in events if e['event']==name];assert len(found)==1,name
        return found[0]
    before,after,released=[one(name)['states'] for name in ['carrier_before','carrier_after','carrier_released']]
    expected=3 if mode=='planned' else 2
    assert len(before)==3 and len(after)==len(released)==expected
    for s in before:
        assert s['compact_authority'] or s['compact_sent']>0
        assert not s['compact_authority'] or s['compact_facts_sent']>0
        assert s['owner_profile']==1 and s['owner_epoch']==1 and s['carrier']==s['prop_owner']==3 and s['prop_sequence']>0
    for s in after:
        assert s['compact_authority'] or s['compact_sent']>0
        assert not s['compact_authority'] or s['compact_facts_sent']>0
        assert s['epoch']==s['owner_epoch']==2 and s['carrier']==s['prop_owner']==3 and s['carrier_attached'] and s['prop_sequence']>0
        assert s['carrier_version']==before[0]['carrier_version'] and s['prop_revision']>before[0]['prop_revision']
        assert all(new>old for new,old in zip(s['avatar_revisions'],before[0]['avatar_revisions']))
    for s in released:assert s['carrier']==s['prop_owner']==s['prop_sequence']==0 and s['carrier_version']==before[0]['carrier_version']+1 and s['prop_revision']>after[0]['prop_revision']
    rtc=one('rtc')['peers'];assert [p['member'] for p in rtc]==([1,2,3] if mode=='planned' else [2,3])
    for p in rtc:assert any(s['state']=='connected' and s['tx']>0 and s['rx']>0 for s in p['stats'])
    if mode=='crash':assert one('kill')['member']==1
    one('complete')
    result={'pass':True,'mode':mode,'carrier_before':before,'carrier_after':after,'released':released,'rtc':rtc}
(out/'verified.json').write_text(json.dumps(result,indent=2)+'\n')
print('REPLAY_CAVE_OWNER_BROWSER_VERIFIED',mode)

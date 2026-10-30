"""Reconstruct proxy accounting and bounds from its packet event log."""
from pathlib import Path
import json

def verify(folder,expected):
    folder=Path(folder);receipt=json.loads((folder/'receipt.json').read_text());assert receipt['config']==expected
    states={name:{'pending':{},'scheduled':set(),'originals':set(),'loss':set(),'capacity':0,'forwarded':0,'forwarded_bytes':0,'scheduled_bytes':0,'duplicates':0,'shutdown':0,'bytes':0,'peak_bytes':0,'peak_packets':0,'last_forward':None,'last_id':0,'reordered':0,'last_event':0,'credit':float(expected['rate_burst_bytes']),'credit_at':None} for name in ('up','down')}
    for line in (folder/'packets.jsonl').read_text().splitlines():
        event=json.loads(line);s=states[event['direction']];key=(event['id'],event['copy']);size=event['bytes'];now=event['at_ns']
        assert type(size)==int and 0<size<=65536 and event['copy'] in (0,1) and event['id']>0
        assert now>=s['last_event'];s['last_event']=now
        if event['copy']==0:s['originals'].add(event['id'])
        if event['event']=='schedule':
            assert key not in s['scheduled'] and event['id'] not in s['loss'] and len(event['sha256'])==64
            s['scheduled'].add(key);s['pending'][key]=(size,event['due_ns']);s['bytes']+=size;s['scheduled_bytes']+=size;s['duplicates']+=event['copy']
            s['peak_bytes']=max(s['peak_bytes'],s['bytes']);s['peak_packets']=max(s['peak_packets'],len(s['pending']))
            assert s['bytes']<=expected['queue_bytes'] and len(s['pending'])<=expected['queue_packets']
        elif event['event']=='forward':
            assert key in s['pending'];count,due=s['pending'].pop(key);assert count==size and now>=due
            assert event['delay_ms']>=expected['latency_ms']-.1
            if expected['bytes_per_second']:
                if s['credit_at'] is not None:s['credit']=min(max(expected['rate_burst_bytes'],size),s['credit']+(now-s['credit_at'])/1e9*expected['bytes_per_second'])
                assert size<=s['credit']+expected['bytes_per_second']*.001
                s['credit']-=size;s['credit_at']=now
            s['last_forward']=(now,size);s['forwarded']+=1;s['forwarded_bytes']+=size;s['bytes']-=size
            s['reordered']+=event['id']<s['last_id'];s['last_id']=max(s['last_id'],event['id'])
        elif event['event']=='drop':
            if event['reason']=='shutdown':
                assert key in s['pending'];count,_=s['pending'].pop(key);assert count==size;s['bytes']-=size;s['shutdown']+=1
            elif event['reason']=='loss':
                assert event['copy']==0 and event['id'] not in s['loss'] and key not in s['scheduled'];s['loss'].add(event['id'])
            else:
                assert event['reason']=='capacity' and key not in s['scheduled'];s['capacity']+=1
        else:assert False,event
    for name,s in states.items():
        got=receipt['directions'][name];assert not s['pending'] and s['bytes']==0
        expected_counts={'received_packets':len(s['originals']),'loss_dropped_packets':len(s['loss']),'capacity_dropped_packets':s['capacity'],'scheduled_packets':len(s['scheduled']),'scheduled_bytes':s['scheduled_bytes'],'duplicated_packets':s['duplicates'],'forwarded_packets':s['forwarded'],'forwarded_bytes':s['forwarded_bytes'],'shutdown_dropped_packets':s['shutdown'],'max_queued_packets':s['peak_packets'],'max_queued_bytes':s['peak_bytes'],'reordered_packets':s['reordered']}
        for key,value in expected_counts.items():assert got[key]==value,(name,key,got[key],value)
        assert got['socket_errors']==0 and got['received_packets']>100 and got['loss_dropped_packets']>0 and got['duplicated_packets']>0
    return receipt

"""Independently reconcile proxy events, real relay selection and game assertions."""
import argparse,json,subprocess,sys
from pathlib import Path

def report(root,game_kind="slopball"):
    config=json.loads((root/'faults.json').read_text());ready=json.loads((root/'proxy/ready.json').read_text());receipt=json.loads((root/'proxy/receipt.json').read_text())
    assert ready['config']==config and receipt['enabled'] and not receipt['errors'] and receipt['refused_flows']==0
    received={};scheduled={};resolved=set();dropped=set();totals={k:0 for k in ['received','forwarded','loss','dtls_loss','duplicated','shutdown','capacity']};delays=[];enabled_at=None;fault_receives=0;lost_kinds={}
    with (root/'proxy/packets.jsonl').open() as packet_log:
        for line in packet_log:
            e=json.loads(line)
            if e['event']=='enabled':assert enabled_at is None;enabled_at=e['at_ns'];continue
            key=(e['flow'],e['direction'],e['id']);copy=(*key,e.get('copy',0))
            if e['event']=='receive':
                assert key not in received;received[key]=e;totals['received']+=1
                if e['enabled']:assert enabled_at is not None and e['at_ns']>=enabled_at;fault_receives+=1
            else:
                r=received[key];assert r['bytes']==e['bytes'] and r['kind']==e['kind']
                if e['event']=='schedule':
                    assert copy not in scheduled;scheduled[copy]=e
                    if e['copy']:totals['duplicated']+=1
                elif e['event']=='forward' or e.get('reason')=='shutdown':
                    assert copy in scheduled and copy not in resolved;resolved.add(copy)
                    if e['event']=='forward':
                        assert e['at_ns']>=scheduled[copy]['due_ns']-1000
                        totals['forwarded']+=1
                        if r['enabled']:delays.append(e['delay_ms']);assert e['delay_ms']>=config['latency_ms']-.01
                    else:totals['shutdown']+=1
                elif e['event']=='drop':
                    assert e['reason'] in ['loss','capacity'] and copy not in dropped and copy not in scheduled;dropped.add(copy);totals[e['reason']]+=1
                    if e['reason']=='loss':
                        assert r['enabled'] and copy not in scheduled
                        totals['dtls_loss']+=e['kind'] in ('dtls_application','dtls13_ciphertext');lost_kinds[e['kind']]=lost_kinds.get(e['kind'],0)+1
                else:raise AssertionError('unknown packet event')
    assert scheduled.keys()==resolved and fault_receives>0 and delays
    assert all((*key,0) in scheduled or (*key,0) in dropped for key in received)
    for k in totals:assert totals[k]==sum(f[d][k] for f in receipt['flows'] for d in ['up','down']),(k,totals[k])
    for f in receipt['flows']:
        for name in ['up','down']:
            s=f[name];assert s['scheduled']==s['forwarded']+s['shutdown'] and s['socket_errors']==0
            assert s['peak_packets']<=config['queue_packets'] and s['peak_bytes']<=config['queue_bytes']
    assert totals['capacity']==0
    if config['loss']>0:assert totals['dtls_loss']>0,'no observed encrypted DTLS record loss'
    if config['duplicate']>0:assert totals['duplicated']>0
    relay=json.loads((root/'game/browser/relay.json').read_text());assert len(relay)>=(6 if game_kind=='loaded' else 12)
    for e in relay:
        assert e['rows']
        for r in e['rows']:assert r['policy']==r['local']==r['remote']=='relay' and r['relayProtocol']=='udp' and r['bytesSent']>0 and r['bytesReceived']>0
    turn=(root/'turn.log').read_text();allocations=turn.count('ALLOCATE processed, success');channels=turn.count('CHANNEL_BIND processed, success');assert allocations>=(2 if game_kind=="loaded" else 6) and channels>=(2 if game_kind=="loaded" else 6)
    delays.sort();result={'pass':True,'config':config,'seed':ready['seed'],'flows':len(receipt['flows']),'fault_receives':fault_receives,'totals':totals,'lost_kinds':lost_kinds,'fault_forward_delay_ms':{'min':delays[0],'median':delays[len(delays)//2],'p95':delays[int(len(delays)*.95)],'max':delays[-1]},'turn_allocations':allocations,'turn_channel_binds':channels,'relay_observations':len(relay)}
    if game_kind=='loaded':
        (root/'game/browser/turn-network.json').write_text(json.dumps(result,indent=2)+'\n')
        subprocess.run([sys.executable,str(Path(__file__).resolve().parents[1]/'replay_loaded_migration/report.py'),str(root/'game')],check=True)
        game=json.loads((root/'game/summary.json').read_text())
    else:
        game_paths=list((root/'game/browser').glob('*-result.json'));assert len(game_paths)==1
        game=json.loads(game_paths[0].read_text());assert game['pass'] and game['exact'] and game['solver_seeded'] and game['continued_kicks_and_goal'] and game['host_returned'] and game['observer_rejoined']
    result['game']=game
    (root/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('out');p.add_argument('--game',choices=['slopball','loaded'],default='slopball');args=p.parse_args();report(Path(args.out),args.game)

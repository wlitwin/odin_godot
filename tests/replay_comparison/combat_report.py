"""Validate a recorded combat encounter before deriving observed workload costs."""
import math,statistics

def summarize(data,workload,trace,samples,role,contract):
    end=workload['combat']
    assert end['unique_enemies']==4 and end['hurt_seen'] and end['living']==end['drops']==0,end
    assert sum(end['damage'])==12 and sum(end['kills'])==4 and sum(end['scrap'])==12,end
    ids=set();previous={};travel={};first={};living=[];hp_lost=False
    for sample in trace:
        c=sample['combat'];enemies=c['enemies'];assert len(enemies)<=4 and 0<=c['drops']<=4 and 0<=c['loot']<=12
        assert len({e['id'] for e in enemies})==len(enemies)
        assert all(0<h<=10 for h in c['hp']);hp_lost |= min(c['hp'])<10
        assert c['living']==sum(e['hp']>0 for e in enemies)
        for key,limit in [('damage',12),('kills',4),('scrap',12)]:
            assert all(isinstance(v,(int,float)) and 0<=v<=limit for v in c[key]) and sum(c[key])<=limit
        for e in enemies:
            assert e['id']!='0' and e['kind']==0 and 0<=e['hp']<=3
            assert all(math.isfinite(e[k]) for k in ['x','y','hp'])
            ids.add(e['id']);first.setdefault(e['id'],[e['x'],e['y']])
            if e['id'] in previous:
                old=previous[e['id']];assert e['hp']<=old['hp']
                travel[e['id']]=travel.get(e['id'],0)+math.hypot(e['x']-old['x'],e['y']-old['y'])
            previous[e['id']]=e
        if role=='host' and len(ids)==4:
            assert sum(c['damage'])+sum(e['hp'] for e in enemies)==12,(sample['us'],c)
        living.append(c['living'])
    assert len(ids)==4 and max(living)==4 and hp_lost
    assert all(travel.get(i,0)>=10 for i in ids),travel
    assert min(sum(s['combat']['hp']) for s in trace)<20
    if role=='host':
        assert all(min(math.dist(point,expected) for expected in contract['expected_spawn_positions'])<=32 for point in first.values()),first
    times=data.pop('frame_at_us');census=data.pop('census_us');observations=data.pop('observation_us')
    assert len(times)==len(samples) and all(0<=t<=data['elapsed_us']+100000 for t in times)
    assert all(times[i]<=times[i+1] for i in range(len(times)-1))
    assert len(census)==len(observations)==len(trace) and all(0<=v<1000000 for v in census+observations)
    active=[];at=0
    for elapsed,cost in zip(times,samples):
        while at+1<len(trace) and trace[at+1]['us']<=elapsed:at+=1
        if trace[at]['combat']['living']>0:active.append(cost)
    assert len(active)>=10,('too few active-encounter samples',len(active))
    quantile=lambda values,p:sorted(values)[max(0,math.ceil(len(values)*p)-1)]
    duration=trace[-1]['us']-trace[0]['us']
    return {'active_observed_frame_samples':len(active),'active_observed_frame_p50_us':quantile(active,.5),
            'active_observed_frame_p95_us':quantile(active,.95),'active_observed_frame_p99_us':quantile(active,.99),
            'living_time_mean':sum(living[i]*(trace[i+1]['us']-trace[i]['us']) for i in range(len(trace)-1))/duration,
            'sampled_travel_px':travel,'first_observed_positions':first,'minimum_team_hp':min(sum(s['combat']['hp']) for s in trace),
            'last_living_observation_us':max(s['us'] for s in trace if s['combat']['living']>0),
            'census_p50_us':quantile(census,.5),'census_p95_us':quantile(census,.95),'observation_p50_us':quantile(observations,.5),'observation_p95_us':quantile(observations,.95),
            'meaning':'game callback samples whose latest preceding census contained a living enemy; sampled workload, not exact phase boundaries'}

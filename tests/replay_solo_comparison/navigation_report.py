"""Independent geometry/trajectory checks for the movement-only finale."""
import math

def covers_for(seed=1337,floor=1):
    widths=[(66,46),(30,44),(26,58),(38,48),(44,40),(20,32),(20,32),(46,46),(28,26),(20,22)]
    state=seed^((floor*0x9e3779b9)&0xffffffff)
    def random():
        nonlocal state
        state=(state+0x9e3779b9)&0xffffffff;z=state
        z=((z^(z>>16))*0x21f0aaad)&0xffffffff;z=((z^(z>>15))*0x735a2d97)&0xffffffff
        return z^(z>>15)
    result=[]
    for _ in range(30):
        kind=random()%10;x=80+random()%1640;y=80+random()%808;result.append([x,y,*widths[kind]])
    return result

def blocked(a,b,covers,pad):
    for x,y,w,h in covers:
        lo=[x-pad,y-pad];hi=[x+w+pad,y+h+pad]
        if all(lo[i]<a[i]<hi[i] for i in [0,1]):continue
        enter,leave=0.,1.
        for i in [0,1]:
            d=b[i]-a[i]
            if abs(d)<1e-8:
                if not lo[i]<a[i]<hi[i]:leave=-1;break
            else:
                t=sorted([(lo[i]-a[i])/d,(hi[i]-a[i])/d]);enter=max(enter,t[0]);leave=min(leave,t[1])
        if enter<leave and enter<1 and leave>0:return True
    return False

def check(data):
    mode=data.get('finale_mode','stationary')
    if mode=='stationary':return {'mode':mode}
    assert mode=='navigate','unknown finale mode'
    covers=data['covers'];assert covers==covers_for(),'actual cover layout'
    rows=data['trace'];assert all(len(r['position'])==2 and all(math.isfinite(v) for v in r['position']) for r in rows),'position records'
    for a,b in zip(rows,rows[1:]):
        elapsed=max((b['ms']-a['ms'])/1000,(b['tick']-a['tick'])/60)
        assert math.dist(a['position'],b['position'])<=350*elapsed+12,'ordinary movement, no teleport'
    receipt=data['barrel_receipt'];origin=receipt['origin'];props=receipt['props'];assert len(props)==2 and all(p[2]>0 for p in props),'barrel health at admission'
    expected=sorted([[min(1880,max(40,origin[0]+150)),min(1048,max(40,origin[1]+dy))] for dy in [0,50]])
    assert all(math.dist(p[:2],e)<=2 for p,e in zip(props,expected)),'fixed barrel offsets'
    plans=data['navigation'];assert len(plans)<=8,'bounded replanning'
    for plan in plans:
        assert plan['found'] and 1<=plan['nodes']<=192 and len(plan['path'])<192,'bounded successful plan'
        prior=plan['from']
        for point in plan['path']:
            assert 24<=point[0]<=1896 and 24<=point[1]<=1064 and not blocked(prior,point,covers,20),'safe path segment'
            prior=point
        if plan['destination'] is not None:assert math.dist(prior,plan['destination'])<1,'positioning endpoint'
        else:
            assert plan['targets'] and all(100<=math.dist(prior,t)<=400 and not blocked(prior,t,covers,2) for t in plan['targets']),'visible safe firing endpoint'
    if data['forced_obstruction']:
        proof=data['blocked_proof'];assert math.dist(proof['position'],[788,588])<=6,'historical obstruction position'
        finale=next(r for r in rows if r['phase']=='barrels')
        assert proof['ms']-finale['ms']>=1500,'full blocked firing interval'
        assert proof['props']==2 and proof['booms']==0 and proof['shots']>0 and proof['health_before']==proof['health_after'],'stationary shots cannot bypass cover'
        assert all(blocked(proof['position'],p[:2],covers,2) for p in props),'both initial shots occluded'
        assert any(p['phase']=='barrels' and p['path'] for p in plans),'move to unblock the real finale'
        positions=[r['position'] for r in rows if r['phase']=='barrels' and r['ms']>=proof['ms']]
        assert positions and max(math.dist(x,proof['position']) for x in positions)>20,'observed movement after obstruction'
    return {'mode':mode,'plans':len(plans),'forced_obstruction':data['forced_obstruction'],'unchanged_cover_and_spawns':True}

from pathlib import Path
import json,re,sys
out=Path(sys.argv[1]);text=(out/'observer.log').read_text()
requests=re.findall(r'RCB_TRACE_REFRESH target=(\d+) seat=(\d+) serial=(\d+) confirmed=(\d+) watched=(\d+)',text)
assert len(requests)==1,requests
tick,seat,serial,confirmed,watched=map(int,requests[0]);assert watched<tick<=confirmed
assert len(re.findall(rf'RCB_KICK seat={seat} tick={tick} local=false confirmed=true',text))==1,text
resets=[int(x) for x in re.findall(r'RCB_SEATED seat=0 reset=(\d+)',text)];assert len(resets)>=2 and resets[-1]>resets[0]
assert text.index('RCB_TRACE_REFRESH')<text.index(f'RCB_KICK seat={seat} tick={tick} local=false confirmed=true')
(out/'refresh-result.json').write_text(json.dumps({'target_tick':tick,'seat':seat,'serial_before':serial,'confirmed':confirmed,'watched':watched,'view_resets':resets,'confirmed_effect_once':True},indent=2)+'\n')
print('REPLAY_CLAIMBALL_REFRESH_EFFECT_ONCE_OK')

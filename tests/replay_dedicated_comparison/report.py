from pathlib import Path
import json,sys
out=Path(sys.argv[1]).resolve();label=sys.argv[2] if len(sys.argv)>2 else 'first';rows=[]
for impl in ['kit','replay']:
 records={role:json.loads((out/impl/label/(role+'.json')).read_text()) for role in ['server','client1','client2']}
 assert all(record['pass'] for record in records.values())
 samples={role:{e['label']:e for e in record['trace'] if e['label']} for role,record in records.items()}
 server=records['server'];assert all(e['seat']==0 and e['hp']==-1 and e['authority']==1 for e in server['trace'])
 cleared=samples['server']['floor cleared'];assert cleared['spawned']==6 and cleared['wave']==1 and cleared['living']==0 and cleared['run']==0
 clients=[samples[role]['floor cleared'] for role in ['client1','client2']]
 assert sum(c['kills'] for c in clients)==6 and all(c['cores']==1 and c['iron']==0 and c['hp']>0 for c in clients)
 assert all(samples[role]['floor two']['floor']==2 and samples[role]['floor two']['avatars']==2 for role in records)
 rows.append({'implementation':impl,'server_clear_tick':cleared['clock'],'server_floor2_tick':samples['server']['floor two']['clock'],'kills':[c['kills'] for c in clients],'health':[c['hp'] for c in clients],'cores':[c['cores'] for c in clients],'seats':[c['seat'] for c in clients]})
report={'pass':True,'scope':'One dedicated authority and two clients; original server-act wave/magazine overrides and explicit bolter choices; shared control driver. This is not a timing, damage-distribution or movement-equivalence claim.','rows':rows}
(out/(label+'-comparison.json')).write_text(json.dumps(report,indent=2)+'\n');print('REPLAY_DEDICATED_COMPARISON_REPORT_OK')

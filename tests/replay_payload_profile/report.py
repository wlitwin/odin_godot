"""Summarize the measured byte ownership; preserve every profile row."""
from pathlib import Path
import json,re,sys
root=Path(sys.argv[1]);text=(root/'profile.log').read_text()
widths={m[0]:int(m[1]) for m in re.findall(r'^WIRE group=(\w+) bytes=(\d+)$',text,re.M)}
rows={}
for lag,group,changed,headers in re.findall(r'^DELTA lag=(\d+) group=(\w+) changed_mean=([\d.]+) headers_mean=([\d.]+)$',text,re.M):
 rows.setdefault(lag,{'groups':{}})['groups'][group]={'changed_mean':float(changed),'headers_mean':float(headers)}
for lag,raw,selected,compressed in re.findall(r'^TOTAL lag=(\d+) raw_mean=([\d.]+) selected_mean=([\d.]+) lz4_selected_mean=([\d.]+)$',text,re.M):
 rows[lag].update(raw_mean=float(raw),selected_mean=float(selected),lz4_selected_mean=float(compressed))
for lag,sparse,compressed in re.findall(r'^COST lag=(\d+) sparse_ns=([\d.]+) lz4_ns=([\d.]+)$',text,re.M):
 rows[lag].update(sparse_encode_ns=float(sparse),lz4_encode_ns=float(compressed))
end=re.search(r'^PAYLOAD_PROFILE_OK bytes=(\d+) samples=(\d+) kills=(\d+) shots=(\d+) hash=(\d+)$',text,re.M);assert end
size,samples,kills,shots,fingerprint=map(int,end.groups());assert samples==1200 and kills>=20 and 90<=shots<=150
assert sum(widths.values())==size and set(rows)=={'1','4','8','16','32'}
for row in rows.values():
 assert set(row['groups'])==set(widths)
 assert abs(2+sum(g['changed_mean']+g['headers_mean'] for g in row['groups'].values())-row['raw_mean'])<.02
 assert row['lz4_selected_mean']<=row['selected_mean'] and row['sparse_encode_ns']>0 and row['lz4_encode_ns']>0
for lag,old,bounded,sparse,lz4 in re.findall(r'^SELECTION lag=(\d+) old_ns=([\d.]+) bounded_ns=([\d.]+) sparse=(\d+) lz4=(\d+)$',text,re.M):
 rows[lag]['selection']={'legacy_ns':float(old),'bounded_ns':float(bounded),'sparse_wins':int(sparse),'lz4_wins':int(lz4)}
 assert float(old)>0 and float(bounded)>0 and int(sparse)+int(lz4)<=samples
for lag,arrays,selected,extra,attempts,wins in re.findall(r'^SHUFFLE lag=(\d+) arrays=(\d+) selected_mean=([\d.]+) extra_ns=([\d.]+) attempts=(\d+) wins=(\d+)$',text,re.M):
 rows[lag]['shuffle']={'array_spans':int(arrays),'selected_mean':float(selected),'extra_ns_per_snapshot':float(extra),'attempts':int(attempts),'wins':int(wins)}
 assert float(selected)<=rows[lag]['lz4_selected_mean']+.001 and 0<=int(wins)<=int(attempts)<=samples
history=rows['16']['groups']['History'];share=(history['changed_mean']+history['headers_mean'])/rows['16']['raw_mean']
result={'wire_bytes':size,'wire_groups':widths,'samples':samples,'kills':kills,'shots':shots,'world_hash':str(fingerprint),'history_delta_share_lag16':share,'rows':rows,'scope':'Offline actual-game offensive workload; exact sparse byte attribution and lossless compression verification. Timings are descriptive, not network measurements.'}
(root/'profile-summary.json').write_text(json.dumps(result,indent=2)+'\n');print('REPLAY_PAYLOAD_PROFILE_REPORT_OK')

from pathlib import Path
import csv,json,re,math,sys,statistics
root=Path(sys.argv[1]); result={}
def fields(line): return dict(re.findall(r'(\w+)=([^ ]+)',line))
def quantile(values,p):return sorted(values)[max(0,math.ceil(len(values)*p)-1)]
for role in ['host','client']:
 log=(root/(role+'.log')).read_text();assert 'REPLAY_SCRAPYARD_COMBAT_PEER_OK' in log
 meter=fields(re.search(r'^RSY_BENCH .+$',log,re.M)[0]);end=fields(re.search(r'^RSY_STRESS_RESULT .+$',log,re.M)[0])
 assert int(end['peak'])>=30 and (int(end['status_mask'])&6)==6 and (int(end['sampled_status_mask'])&6)==6 and int(meter['dropped'])==0
 assert int(meter['shots'])>0 and int(meter['tx'])>0 and int(meter['rx'])>0
 groups={}
 for row in csv.DictReader((root/('timing-'+role+'.csv')).open()):groups.setdefault(row['metric'],[]).append(int(row['us']))
 summary={k:{'samples':len(v),'p50_us':quantile(v,.5),'p95_us':quantile(v,.95),'p99_us':quantile(v,.99),'max_us':max(v),'mean_us':statistics.mean(v)} for k,v in groups.items()}
 for required in ['advance','pump','snapshot','paint','frame']:assert required in summary
 if role=='client':assert 'replay' in summary
 rate=int(meter['tx'])*1e6/int(meter['us'])
 rss=[]
 for line in (root/'rss.csv').read_text().splitlines()[1:]:
  label,measuring,value=line.split(',')
  if label==role and measuring=='1':rss.append(int(value))
 result[role]={'meter':meter,'scenario':end,'timings':summary,'application_tx_bytes_per_second':rate,'sample_window_rss_kib_max':max(rss) if rss else None}
print(json.dumps(result,indent=2));(root/'summary.json').write_text(json.dumps(result,indent=2)+'\n')

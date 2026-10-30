from pathlib import Path
import hashlib,json,math,re,statistics,sys
root=Path(sys.argv[1]);build=json.loads((root/'build.json').read_text())
for name,digest in build['binaries'].items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest
assert 'current' in build['binaries'] and set(build['binaries'])<=set(['current','reference'])
expected={f'{pair}-{version}.log' for pair in (1,2,3) for version in build['binaries']}
actual={p.name for p in root.iterdir() if re.fullmatch(r'\d+-.+\.log',p.name)}
assert actual==expected,('timing files',actual,expected)
runs=[];hashes=set();shapes=set()
for path in sorted(root.glob('[123]-*.log')):
 text=path.read_text();shape=re.search(r'SCHEMA_META bytes=(\d+) fields=(\d+) checks=(\d+) spans=(\d+)',text);assert shape;shapes.add(shape.groups())
 rows=[tuple(map(int,m)) for m in re.findall(r'SCHEMA_TIMING trial=(\d+) encode_ns_per_call=(\d+) decode_ns_per_call=(\d+) hash=(\d+)',text)]
 assert len(rows)==7 and [r[0] for r in rows]==list(range(7)) and all(r[1]>0 and r[2]>0 for r in rows)
 hashes.update(row[3] for row in rows)
 pair,version=path.stem.split('-',1);runs.append({'pair':int(pair),'version':version,'encode_median_ns':statistics.median(row[1] for row in rows),'decode_median_ns':statistics.median(row[2] for row in rows)})
assert len(hashes)==1 and len(shapes)==1
summary={'build':build,'shape':list(next(iter(shapes))),'canonical_hash':str(next(iter(hashes))),'runs':runs,'aggregate':{}}
for version in build['binaries']:
 selected=[r for r in runs if r['version']==version];assert len(selected)==3
 summary['aggregate'][version]={kind:statistics.median(r[kind] for r in selected) for kind in ['encode_median_ns','decode_median_ns']}
cases={}
for label in ['zero','dense','sparse','alternating']:
 entries=[];proof=set();case_shapes=set()
 for path in sorted(root.glob('[123]-*.log')):
  text=path.read_text();shape=re.search(r'SCHEMA_CASE_META case='+label+r' bytes=(\d+) fields=(\d+) checks=(\d+) spans=(\d+)',text);assert shape;case_shapes.add(shape.groups())
  rows=[tuple(map(int,m)) for m in re.findall(r'SCHEMA_CASE_TIMING case='+label+r' trial=(\d+) encode_ns_per_call=(\d+) decode_ns_per_call=(\d+) hash=(\d+)',text)]
  assert len(rows)==7 and [r[0] for r in rows]==list(range(7)) and all(r[1]>0 and r[2]>0 for r in rows)
  proof.update(row[3] for row in rows)
  pair,version=path.stem.split('-',1);entries.append({'pair':int(pair),'version':version,'encode_median_ns':statistics.median(row[1] for row in rows),'decode_median_ns':statistics.median(row[2] for row in rows)})
 assert len(proof)==1 and len(case_shapes)==1
 cases[label]={'shape':list(next(iter(case_shapes))),'canonical_hash':str(next(iter(proof))),'runs':entries,'aggregate':{}}
 for version in build['binaries']:
  selected=[r for r in entries if r['version']==version];assert len(selected)==3
  cases[label]['aggregate'][version]={kind:statistics.median(r[kind] for r in selected) for kind in ['encode_median_ns','decode_median_ns']}
summary['validation_cases']=cases
summary['scope']='Warm in-process codec calls over a fixed Scrapyard-shaped value; not whole-game timing or a statistical confidence estimate.'
temporary=root/'summary.json.pending';temporary.write_text(json.dumps(summary,indent=2)+'\n');temporary.replace(root/'summary.json');print(json.dumps(summary['aggregate']))

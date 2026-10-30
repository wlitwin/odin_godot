"""Verify prepared sources and exact binaries, with optional archived framework proof."""
from pathlib import Path
import hashlib,json,sys,tarfile,os
root,out=map(Path,sys.argv[1:3]);evidence=Path(sys.argv[3]) if len(sys.argv)>3 else None
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
framework=json.loads((root/'framework-source.json').read_text())
build=json.loads((root/'build-manifest.json').read_text())
for name,digest in build['binaries'].items():assert sha(root/name)==digest,('binary changed',name)
for line in (root/'source-sha256.txt').read_text().splitlines():
 digest,name=line.split('  ',1);assert sha(root/name)==digest,('prepared source changed',name)
proof={'build':build,'framework_manifest_sha256':sha(root/'framework-source.json'),'prepared_manifest_sha256':sha(root/'source-sha256.txt')}
prefs={key:os.environ.get(key,'1') for key in ('RSY_SHUFFLE','RSY_FEC','RSY_LZ4')}
assert all(value in ('0','1') for value in prefs.values())
proof['local_delivery_preferences']=prefs
interval=int(os.environ.get('RSY_SNAPSHOT_EVERY','1'));assert 1<=interval<=30
proof['snapshot_every']=interval
if evidence:
 checks=json.loads((evidence/'checksums.json').read_text())
 for name in ('source.tar.gz','source-manifest.json','cohort-manifest.json'):
  assert sha(evidence/name)==checks[name],('archive checksum',name)
 sources=json.loads((evidence/'source-manifest.json').read_text())
 receipts=json.loads((evidence/'cohort-manifest.json').read_text())
 labels=[name.removesuffix('/build-manifest.json') for name,digest in receipts.items() if name.endswith('/build-manifest.json') and digest==sha(root/'build-manifest.json')]
 assert len(labels)==1,labels
 for name in ('framework-source.json','source-sha256.txt','summary.json'):
  assert receipts[labels[0]+'/'+name]==sha(root/name),('archived receipt',name)
 needed=framework['sha256'];seen=set()
 with tarfile.open(evidence/'source.tar.gz') as archive:
  for member in archive:
   if member.name in needed:
    assert member.isfile() and sources[member.name]==needed[member.name]
    assert hashlib.sha256(archive.extractfile(member).read()).hexdigest()==needed[member.name]
    seen.add(member.name)
 assert seen==set(needed)
 proof['framework_proof']={'archive':str(evidence),'sha256':checks['source.tar.gz'],'cohort_label':labels[0]}
else:
 for name,digest in framework['sha256'].items():assert sha(Path(framework['root'])/name)==digest,('live framework changed',name)
 proof['framework_proof']={'live_root':framework['root']}
if (root/'summary.json').exists():
 assert json.loads((root/'summary.json').read_text())['full_plan']
else:
 # A failed full cohort remains failed. This runner executes only delay/Replay;
 # profiling that accepted scope is a distinct diagnostic, recorded explicitly.
 assert evidence is None, 'archived rejected cohorts need explicit receipt support'
 plan=json.loads((root/'run-plan.json').read_text());assessment=json.loads((root/'assessment.json').read_text())
 assert plan['repetitions']==3 and plan['conditions']==['delay','lossy']
 assert assessment['by_implementation']['delay-replay']['accepted']
 assert len([r for r in assessment['observations'] if r['implementation']=='replay'])==12
 proof['acceptance']={'scope':'Delay/Replay diagnostic from a rejected full cohort','raw_loss_replay_accepted':assessment['by_implementation']['lossy-replay']['accepted'],'assessment_sha256':sha(root/'assessment.json'),'full_matrix_accepted':assessment['full_matrix_accepted']}

out.write_text(json.dumps(proof,indent=2)+'\n')
print('JAM_PROFILE_PROVENANCE_OK')

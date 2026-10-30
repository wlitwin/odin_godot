from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2];tools=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=[]
sources=[('cave',p) for p in sorted((root/'tests/replay_cave/fixtures').glob('*/*.replay'))]
sources += [('cave',root/'tests/replay_cave_impact/fixtures/c8.checkpoint'),('owner',root/'tests/replay_cave_owner/fixtures/owner1/pending.checkpoint'),('owner',root/'tests/replay_cave_impact/fixtures/o2.checkpoint')]
for i,(profile,source) in enumerate(sources):
 name=f'{i:02d}-{profile}-{source.parent.name}-{source.stem}';target=out/(name+'.checkpoint');before=sha(source)
 result=subprocess.run([str(tools/('upgrade-'+profile)),str(source),str(target)],capture_output=True,text=True,timeout=30)
 (out/(name+'.log')).write_text(result.stdout+result.stderr);assert result.returncode==0,result.stdout+result.stderr
 assert sha(source)==before
 saved=target.read_bytes()
 reject=subprocess.run([str(tools/('upgrade-'+profile)),str(source),str(target)],capture_output=True,text=True,timeout=30)
 assert reject.returncode!=0 and target.read_bytes()==saved
 rows.append({'profile':profile,'source':str(source.relative_to(root)),'source_sha256':before,'target':target.name,'target_sha256':sha(target),'log':result.stdout.strip()})
for profile,name in [('cave','c8'),('owner','o2')]:
 source=root/f'tests/replay_cave_impact/fixtures/{name}.checkpoint';bad=out/(name+'-corrupt.checkpoint');data=bytearray(source.read_bytes());data[-1]^=1;bad.write_bytes(data)
 target=out/(name+'-corrupt-output.checkpoint');p=subprocess.run([str(tools/('upgrade-'+profile)),str(bad),str(target)],capture_output=True,text=True,timeout=30)
 (out/(name+'-corrupt.log')).write_text(p.stdout+p.stderr);assert p.returncode!=0 and not target.exists()
(out/'result.json').write_text(json.dumps({'pass':True,'rows':rows,'existing_and_corrupt_preserved':True},indent=2)+'\n')
print('REPLAY_CAVE_IMPACT_UPGRADES_OK',len(rows))

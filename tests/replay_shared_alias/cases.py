from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2];generator=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
cases=[
 ('plain','Plain :: struct {x:i32,y:f32}\n','data.Plain',True),
 ('alias-chain','Plain :: struct {x:i32}\nOne :: Plain\nTwo :: One\n','data.Two',True),
 ('generic','Box :: struct($T:typeid) {value:T}\nPlain :: struct {x:i32}\nAlias :: Box(Plain)\n','data.Alias',True),
 ('nested-generic','Box :: struct($T:typeid) {value:T}\nPlain :: struct {x:i32}\nAlias :: Box(Box(Plain))\n','data.Alias',True),
 ('timeline','import r "godot:replay"\nState :: struct {x:i32}\nInput :: struct {x:i8}\nEvent :: struct {x:u8}\nAlias :: r.Timeline(State,Input,Event)\n','data.Alias',True),
 ('tagged','Tagged :: struct {hp:i32 `gd:"replicate"`}\n','data.Tagged',False),
 ('tagged-alias','Tagged :: struct {hp:i32 `gd:"replicate"`}\nAlias :: Tagged\n','data.Alias',False),
 ('nested-tag','Tagged :: struct {hp:i32 `gd:"replicate"`}\nOuter :: struct {inner:Tagged}\n','data.Outer',False),
 ('generic-tag','Box :: struct($T:typeid) {value:T}\nTagged :: struct {hp:i32 `gd:"replicate"`}\nAlias :: Box(Tagged)\n','data.Alias',False),
 ('method','Block :: struct {x:i32}\n@(gd_method)\nblock_ping :: proc(self:^Block) {}\n','data.Block',False),
 ('signal','import gd "godot:godot"\nBlock :: struct {done:gd.Signal0}\n','data.Block',False),
 ('signal-alias','import gd "godot:godot"\nSignal :: gd.Signal0\nBlock :: struct {done:Signal}\n','data.Block',False),
 ('cycle','A :: B\nB :: A\n','data.A',False),
 ('missing','Alias :: Missing\n','data.Alias',False),
]
cases += [
 ('engine-alias','import engine "godot:godot"\nPlain :: struct {node:engine.Node2d}\n','data.Plain',True),
 ('using-plain','Plain :: struct {x:i32}\nOuter :: struct {using item:Plain}\n','data.Outer',True),
 ('distinct','Count :: distinct u32\nPlain :: struct {count:Count}\n','data.Plain',True),
 ('std-bare','import "core:mem"\nPlain :: struct {allocator:mem.Allocator}\n','data.Plain',True),
 ('tick','Block :: struct {x:i32}\n@(gd_tick)\nblock_tick :: proc(self:^Block) {}\n','data.Block',False),
 ('signal-renamed','import engine "godot:godot"\nBlock :: struct {done:engine.Signal0}\n','data.Block',False),
 ('signal-generic','import gd "godot:godot"\nBlock :: struct {done:gd.SignalN(struct {x:i32})}\n','data.Block',False),
 ('generic-forward','Inner :: struct($T:typeid) {value:T}\nOuter :: struct($U:typeid) {inner:Inner(U)}\nPlain :: struct {x:i32}\nAlias :: Outer(Plain)\n','data.Alias',True),
 ('generic-forward-tag','Inner :: struct($T:typeid) {value:T}\nOuter :: struct($U:typeid) {inner:Inner(U)}\nTagged :: struct {x:i32 `gd:"replicate"`}\nAlias :: Outer(Tagged)\n','data.Alias',False),
 ('wrong-arity','Box :: struct($T:typeid) {value:T}\nAlias :: Box()\n','data.Alias',False),
]
results=[]
for name,body,field,accepted in cases:
 case=out/name;scripts=case/'scripts';shared=case/'shared/data';scripts.mkdir(parents=True);shared.mkdir(parents=True)
 (shared/'types.odin').write_text('package shared_data\n'+body)
 (scripts/'probe.odin').write_text('//gd:extends Node\n//gd:class AliasProbe\npackage alias_probe\nimport gd "godot:godot"\nimport data "../shared/data"\nAliasProbe :: struct {owner:gd.Node,value:'+field+'}\n')
 result=subprocess.run([str(generator),str(scripts),'-godot:'+str(root)],capture_output=True,text=True,timeout=20)
 (case/'generator.log').write_text(result.stdout+result.stderr)
 assert (result.returncode==0)==accepted,(name,result.stdout,result.stderr)
 if accepted:
  compiled=subprocess.run(['odin','check',str(scripts),'-collection:godot='+str(root),'-no-entry-point','-custom-attribute:gd_method'],capture_output=True,text=True,timeout=30)
  (case/'check.log').write_text(compiled.stdout+compiled.stderr);assert compiled.returncode==0,(name,compiled.stdout,compiled.stderr)
 else:
  assert 'comes from the SHARED package' in result.stderr+result.stdout,name
  assert not list(scripts.glob('*.gen.odin')),name
 results.append({'name':name,'accepted':accepted,'pass':True});print('SHARED_ALIAS_CASE_OK',name,flush=True)
# Generic binding resolves Caller.State, not Library.State with the same name.
for tagged in [False,True]:
 case=out/('shadow-tagged' if tagged else 'shadow-plain');scripts=case/'scripts';caller=case/'shared/caller';library=case/'shared/library'
 for p in [scripts,caller,library]:p.mkdir(parents=True)
 (library/'types.odin').write_text('package generic_library\nState :: struct {secret:i32 `gd:"replicate"`}\nBox :: struct($T:typeid) {value:T}\n')
 (caller/'types.odin').write_text('package generic_caller\nimport lib "../library"\nState :: struct {x:i32'+(' `gd:"replicate"`' if tagged else '')+'}\nAlias :: lib.Box(State)\n')
 (scripts/'probe.odin').write_text('//gd:extends Node\n//gd:class AliasProbe\npackage alias_probe\nimport gd "godot:godot"\nimport data "../shared/caller"\nAliasProbe :: struct {owner:gd.Node,value:data.Alias}\n')
 result=subprocess.run([str(generator),str(scripts),'-godot:'+str(root)],capture_output=True,text=True,timeout=20);(case/'generator.log').write_text(result.stdout+result.stderr)
 assert (result.returncode==0)==(not tagged),(case,result.stdout,result.stderr)
 results.append({'name':case.name,'accepted':not tagged,'pass':True})
case=out/'fake-engine-alias';scripts=case/'scripts';a=case/'shared/a';b=case/'shared/b'
for p in [scripts,a,b]:p.mkdir(parents=True)
(b/'types.odin').write_text('package fake_engine\nBlock :: struct {x:i32 `gd:"replicate"`}\n')
(a/'types.odin').write_text('package shared_a\nimport gd "../b"\nPlain :: struct {block:gd.Block}\n')
(scripts/'probe.odin').write_text('//gd:extends Node\n//gd:class AliasProbe\npackage alias_probe\nimport gd "godot:godot"\nimport data "../shared/a"\nAliasProbe :: struct {owner:gd.Node,value:data.Plain}\n')
result=subprocess.run([str(generator),str(scripts),'-godot:'+str(root)],capture_output=True,text=True,timeout=20);(case/'generator.log').write_text(result.stdout+result.stderr)
assert result.returncode!=0 and 'comes from the SHARED package' in result.stderr+result.stdout
results.append({'name':case.name,'accepted':False,'pass':True})
for name,declaration,field,accepted in [
 ('bare-import','Plain :: struct {x:i32}\n','shared_data.Plain',True),
 ('bare-tagged','Plain :: struct {x:i32 `gd:"replicate"`}\n','shared_data.Plain',False),
 ('bounded-cycle','A :: B\nB :: A\n','shared_data.A',False),
]:
 case=out/name;scripts=case/'scripts';shared=case/'shared/data';scripts.mkdir(parents=True);shared.mkdir(parents=True)
 (shared/'types.odin').write_text('package shared_data\n'+declaration)
 (scripts/'probe.odin').write_text('//gd:extends Node\n//gd:class AliasProbe\npackage alias_probe\nimport gd "godot:godot"\nimport "../shared/data"\nAliasProbe :: struct {owner:gd.Node,value:'+field+'}\n')
 result=subprocess.run([str(generator),str(scripts),'-godot:'+str(root)],capture_output=True,text=True,timeout=20);(case/'generator.log').write_text(result.stdout+result.stderr)
 assert (result.returncode==0)==accepted,(name,result.stdout,result.stderr)
 results.append({'name':name,'accepted':accepted,'pass':True})
case=out/'engine-import-plus-fake-gd';scripts=case/'scripts';a=case/'shared/a';b=case/'shared/b'
for p in [scripts,a,b]:p.mkdir(parents=True)
(b/'types.odin').write_text('package tagged_user\nBlock :: struct {x:i32 `gd:"replicate"`}\n')
(a/'types.odin').write_text('package shared_a\nimport engine "godot:godot"\nimport gd "../b"\nPlain :: struct {node:engine.Node2d,block:gd.Block}\n')
(scripts/'probe.odin').write_text('//gd:extends Node\n//gd:class AliasProbe\npackage alias_probe\nimport gd "godot:godot"\nimport data "../shared/a"\nAliasProbe :: struct {owner:gd.Node,value:data.Plain}\n')
result=subprocess.run([str(generator),str(scripts),'-godot:'+str(root)],capture_output=True,text=True,timeout=20);(case/'generator.log').write_text(result.stdout+result.stderr)
assert result.returncode!=0 and 'comes from the SHARED package' in result.stderr+result.stdout,('engine alias collision',result.stdout,result.stderr)
results.append({'name':case.name,'accepted':False,'pass':True})
(out/'result.json').write_text(json.dumps({'pass':True,'cases':results,'generator_sha256':hashlib.sha256(generator.read_bytes()).hexdigest()},indent=2)+'\n')
print('REPLAY_SHARED_ALIAS_CASES_OK',len(results))

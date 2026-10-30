from pathlib import Path
import hashlib,importlib.util,json,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('owner_profile',root/'examples/replay_cavecrawl_owned/prepare.py');owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for variant in ['kit','server','owner']:
 project=out/variant/'project';source=root/('examples/cavecrawl' if variant=='kit' else 'examples/replay_cavecrawl')
 shutil.copytree(source,project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
 if variant=='owner':owner.apply_profile(project)
 p=project/'project.godot';s=p.read_text();s=re.sub(r'config/name="[^"]+"',f'config/name="Cave comparison {out.name} {variant}"',s)
 s=re.sub(r'^config/(use_custom_user_dir|custom_user_dir_name)=.*\n','',s,flags=re.M)
 s=s.replace('[application]',f'[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ReplayCaveComparison/{out.name}/{variant}"')
 if 'renderer/rendering_method=' not in s:s=s.replace('[rendering]','[rendering]\nrenderer/rendering_method="gl_compatibility"')
 p.write_text(s)
 for floor in [1,2]:
  p=project/f'levels/level_{floor}.tres';s,n=re.subn(r'^wave_counts = .*$', 'wave_counts = PackedInt32Array(0, 0)',p.read_text(),flags=re.M);assert n==1;p.write_text(s)
 if variant=='kit':
  p=project/'scripts/world.odin';s=p.read_text();needle='lv.seed = u32(i64(now_s() * 1000)) | 1';assert needle in s;p.write_text(s.replace(needle,'lv.seed = u32(1337)'))
  p=project/'scripts/host.odin';before=p.read_text();old='nav_map := knav.map_2d(self.owner)';assert before.count(old)==1
  after=before.replace(old,'nav_world := gd.viewport_find_world_2d(gd.node_get_viewport(self.owner))\n\tdefer gd.release_ref(nav_world)\n\tnav_map := gd.world2d_get_navigation_map(nav_world)');p.write_text(after)
  (out/variant/'ownership-overlay.json').write_text(json.dumps({'reason':'release the owned World2D reference returned by the same viewport lookup','path':'scripts/host.odin','before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':sha(p),'changes_gameplay':False},indent=2)+'\n')
  p=project/'scripts/cavecrawl.odin';s=p.read_text().replace('gd.print_str("CAVE_UI_READY")','bench_install(self);gd.print_str("CAVE_UI_READY")')
  hook=s.index(') {',s.index('cave_lobby_command_confirmed :: proc('))+3
  s=s[:hook]+'\n if bench_active {bench_confirmed+=1}'+s[hook:]
  marker='cave_lobby_process :: proc(self: ^CaveLobby, delta: f64) {'
 else:
  p=project/'scripts/cave.odin';s=p.read_text().replace('opts.network.content = game.CONTENT','opts.network.content = game.CONTENT\n opts.disable_compact_observations=gd.env_int("CAVE_COMPARE_RAW_OBSERVATIONS",0)==1\n opts.disable_compact_recent_facts=gd.env_int("CAVE_COMPARE_RAW_RECENT_FACTS",0)==1');marker='replay_cave_process :: proc(self: ^ReplayCave, dt: f64) {'
 assert marker in s
 s=s.replace(marker,marker+'\n bench_start:=bench_active ? gd.time_get_ticks_usec(gd.singleton_time()) : u64(0)\n defer if bench_start!=0 {bench_note(bench_start)}',1);p.write_text(s)
 adapter=(root/'tests/replay_cave_comparison'/('kit.odin' if variant=='kit' else 'replay.odin')).read_text()
 if variant=='owner':adapter=adapter.replace('"../shared/cave"','"godot:examples/replay_cavecrawl/shared/owner_cave"')
 (project/'scripts/comparison.odin').write_text(adapter)
 if variant!='kit':shutil.copy2(root/'tests/replay_cave_comparison/packets.odin',project/'scripts/packet_meter.odin')
 (out/variant/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
paths=subprocess.check_output(['rg','--files','kit','play','replay','godot','gdext','runtime','core','build','scriptgen','examples/replay_cavecrawl/shared'],cwd=root,text=True).splitlines()
(out/'framework.json').write_text(json.dumps({n:sha(root/n) for n in paths if Path(n).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
shutil.copy2(root/'tests/replay_cave_comparison/contract.json',out/'contract.json')
(out/'baseline.json').write_text(json.dumps({'revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'original_status':subprocess.check_output(['git','status','--porcelain','--','examples/cavecrawl'],cwd=root,text=True),'original_sources':{str(p.relative_to(root)):sha(p) for p in (root/'examples/cavecrawl').rglob('*') if p.is_file() and p.suffix in {'.odin','.tscn','.tres','.gd'} and not p.name.endswith('.gen.odin') and not any(x in {'.godot','bin','addons','node_modules','out'} for x in p.relative_to(root/'examples/cavecrawl').parts)}},indent=2)+'\n')

"""Apply an explicit ownership-only overlay to an already isolated baseline.

The original project is never modified. Gameplay source changes and before/after
hashes are retained so cleaned-baseline results cannot be mistaken for pristine.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

project=Path(sys.argv[1]).resolve()
assert 'config/name="replay_baseline_stress_' in (project/'project.godot').read_text()
marker=project/'scripts/baseline_lifetime.odin'
assert not marker.exists(), 'cleanup overlay already installed'
originals={p:p.read_text() for p in (project/'scripts').glob('*.odin') if not p.name.endswith('.gen.odin')}
originals[project/'scrapyard_test.gd']=(project/'scrapyard_test.gd').read_text()
changed=dict(originals)
p=project/'scripts/defs.odin';s=changed[p]
replacements={
 '\tds := gd.new_string_odin(dir)':'\tds := gd.new_string_odin(dir)\n\tdefer gd.free_string(ds)',
 '\tda := gd.dir_access_open(ds)':'\tda := gd.dir_access_open(ds)\n\tdefer gd.release_ref(da)',
 '\tfiles := gd.dir_access_get_files(da)':'\tfiles := gd.dir_access_get_files(da)\n\tdefer gd.free_packed_string_array(files)',
 '\t\tf := gd.packed_string_array_get(&files, gd.Int(i))':'\t\tf := gd.packed_string_array_get(&files, gd.Int(i))\n\t\tdefer gd.free_string(f)',
}
for old,new in replacements.items():assert s.count(old)==2,(old,s.count(old));s=s.replace(old,new)
s,count=re.subn(r'(\tfor res in defs_scan\([^\n]+\) \{)',r'\1\n\t\tdefer gd.release_ref(res)',s)
assert count==5,count
changed[p]=s
for p,s in list(changed.items()):
 if p.name!='defs.odin':changed[p]=s.replace('gd.load(', 'baseline_load(')
p=project/'scripts/scrapyard.odin';s=changed[p]
ready='scrapyard_ready :: proc(self: ^Scrapyard) {';assert s.count(ready)==1
s=s.replace(ready,ready+'\n\tbaseline_scope_enter(self)')
assert 'scrapyard_exit_tree ::' not in s
s+='\n// Ownership-only isolated baseline overlay.\nscrapyard_exit_tree :: proc(self:^Scrapyard) {baseline_cleanup(self)}\n'
changed[p]=s
p=project/'scripts/skins.odin'
changed[p]+='''
// Called only when the final isolated game instance exits.
baseline_skins_reset :: proc() {
 g_loaded=false;g_skins={};g_zombies={};g_weapons=nil;g_objects=nil;g_floor=nil;g_ui=nil
}
'''
p=project/'scrapyard_test.gd';s=changed[p]
s=s.replace('func _initialize() -> void:\n','func _initialize() -> void:\n\tbaseline_resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))\n')
s=s.replace('func _process(_delta: float) -> bool:\n','func _process(_delta: float) -> bool:\n\tif baseline_finishing: return false\n')
s=re.sub(r'quit\(([01])\); return true',r'baseline_finish(\1); return false',s)
s+='''
# Drain scene-owned deletion/tween work before engine shutdown reports resources.
var baseline_finishing:=false
var baseline_resource_floor:=0
func baseline_finish(code:int) -> void:
	if baseline_finishing:return
	baseline_finishing=true
	if is_instance_valid(yard):
		yard.set_process(false)
		yard.queue_free()
	await process_frame
	await process_frame
	var deadline:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>baseline_resource_floor and Time.get_ticks_msec()<deadline:
		await process_frame
	var remaining:=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))-baseline_resource_floor
	print("BASELINE_RESOURCE_DRAIN remaining=",remaining)
	quit(code if remaining==0 else 1)
'''
changed[p]=s
overlay=r'''package scrapyard_scripts
import gd "godot:godot"
import kboot "godot:kit/boot"
import ks "godot:kit/session"
import fx "godot:kit/fx"
import xfer "godot:kit/xfer"
import mem "base:runtime"

baseline_resources:[dynamic]gd.Resource
baseline_roots:map[u64]bool
baseline_scope_enter :: proc(self:^Scrapyard) {
 context.allocator=mem.heap_allocator()
 if baseline_roots==nil {baseline_roots=make(map[u64]bool)}
 baseline_roots[gd.object_get_instance_id(self.owner)]=true
}
baseline_load :: proc(path:cstring)->gd.Resource {
 context.allocator=mem.heap_allocator()
 resource:=gd.load(path)
 if resource!=nil {append(&baseline_resources,resource)}
 return resource
}
baseline_cleanup :: proc(self:^Scrapyard) {
 id:=gd.object_get_instance_id(self.owner)
 if !baseline_roots[id] {return}
 xfer.album_destroy(&self.album)
 fx.bursts_destroy(&self.bursts);fx.floats_destroy(&self.floats);fx.tracers_destroy(&self.tracers)
 kboot.boot_net_detach(&self.boot);ks.session_destroy(&self.ses)
 delete(self.runners);delete(self.mobs);delete(self.scraps);delete(self.zones);delete(self.covers)
 delete(self.st_credit);delete(self.spray_tex);delete(self.spray_node);delete(self.spray_pend)
 delete(self.flying);delete(self.lobs);delete(self.spit);delete(self.nades);delete(self.puffs);delete(self.rings);delete(self.beams)
 delete(self.glob_views);delete(self.marks);delete(self.wounds);delete(self.wall_due);delete(self.sparks)
 context.allocator=mem.heap_allocator()
 delete_key(&baseline_roots,id)
 if len(baseline_roots)==0 {
  gd.input_set_custom_mouse_cursor(gd.singleton_input(),nil,.Cursor_Arrow,{})
  for resource in baseline_resources {gd.release_ref(resource)}
  delete(baseline_resources);baseline_resources={};delete(baseline_roots);baseline_roots=nil
  baseline_skins_reset()
 }
}
'''
backups=project.parent/'cleanup-originals';backups.mkdir(exist_ok=False)
report=[]
for p,s in changed.items():
 if s==originals[p]:continue
 (backups/p.name).write_text(originals[p]);p.write_text(s)
 report.append({'file':str(p.relative_to(project)),'before':hashlib.sha256(originals[p].encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
marker.write_text(overlay)
(project.parent/'cleanup-overlay.json').write_text(json.dumps({'gameplay_rules_changed':False,'files':report,'added':str(marker.relative_to(project))},indent=2)+'\n')
print('Applied ownership-only overlay:',project)

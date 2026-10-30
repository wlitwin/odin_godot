"""Diagnostic copies only: follow dash requests, capture, delivery and execution."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
profile=os.environ.get('REPLAY_INPUT_AUDIT_PROFILE','endurance');assert profile in ('endurance','jam')
if (root/'examples/replay_scrapyard/scripts/dash.odin').exists():
 subprocess.run([sys.executable,str(Path(__file__).with_name('action_prepare.py')),str(out)],check=True)
 sys.exit(0)
subprocess.run([sys.executable,str(root/f'tests/replay_{profile}_comparison/prepare.py'),str(out)],check=True)
framework=out/'framework';framework.mkdir()
for p in root.iterdir():
 if p.name.startswith('.') or p.name=='replay':continue
 (framework/p.name).symlink_to(p,target_is_directory=p.is_dir())
shutil.copytree(root/'replay',framework/'replay');changes={}
def edit(p,before,after):
 assert before!=after;changes[str(p.relative_to(out))]={'before':hashlib.sha256(before.encode()).hexdigest(),'after':hashlib.sha256(after.encode()).hexdigest()};p.write_text(after)
p=framework/'replay/net/client.odin';before=p.read_text();s=before.replace('import "core:math"','import "core:math"\nimport "core:fmt"\nimport "base:intrinsics"')
needle='client_step :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), control: Control) -> Error {'
s=s.replace(needle,needle+'\n when intrinsics.type_has_field(Control,"dash") {if control.dash {fmt.printf("INPUT_SAMPLE seat=%d tick=%d now=%d phase=%v depth=%d limit=%d\\n",c.seat,c.timeline.head+1,c.now,c.phase,c.timeline.head-c.timeline.confirmed,c.cfg.max_prediction)}}')
s=s.replace('\tclient_send_inputs(c)\n\treturn .None','\twhen intrinsics.type_has_field(Control,"dash") {if control.dash {fmt.printf("INPUT_CAPTURE seat=%d tick=%d now=%d\\n",c.seat,tick,c.now)}}\n\tclient_send_inputs(c)\n\treturn .None',1)
s=s.replace('c.stats.tx_packets+=1;c.stats.tx_bytes+=u64(len(bytes))','c.stats.tx_packets+=1;c.stats.tx_bytes+=u64(len(bytes))\n  when intrinsics.type_has_field(C,"dash") {for i in 0..<int(packet.count) {sample:=packet.samples[i];if sample.value.dash {fmt.printf("INPUT_SENT seat=%d tick=%d now=%d\\n",c.seat,sample.tick,c.now)}}}',1)
edit(p,before,s)
p=framework/'replay/net/server.odin';before=p.read_text();s=before.replace('package replay_net','package replay_net\nimport "core:fmt"\nimport "base:intrinsics"',1)
needle='for sample, i in packet.samples[:packet.count] {';s=s.replace(needle,needle+'\n\t\t\twhen intrinsics.type_has_field(Control,"dash") {if sample.value.dash {fmt.printf("INPUT_RECEIVED seat=%d tick=%d now=%d head=%d future_limit=%d\\n",peer.seat,sample.tick,s.now,s.timeline.head,s.cfg.max_future)}}',1)
s=s.replace('slot^ = {sample.tick, sample.value, server_view(s, index, sample.view)}','slot^ = {sample.tick, sample.value, server_view(s, index, sample.view)}\n\t\t\twhen intrinsics.type_has_field(Control,"dash") {if sample.value.dash {fmt.printf("INPUT_ACCEPTED seat=%d tick=%d now=%d head=%d\\n",peer.seat,sample.tick,s.now,s.timeline.head)}}',1)
edit(p,before,s)
p=out/'replay/project/scripts/comparison_mixed.odin';before=p.read_text();s=before.replace('package replay_scrapyard','package replay_scrapyard\nimport "core:fmt"',1).replace('replay_scrapyard_compare_dash :: proc(self:^ReplayScrapyard) {compare_dash_pending=true}', 'replay_scrapyard_compare_dash :: proc(self:^ReplayScrapyard) {compare_dash_pending=true;fmt.printf("INPUT_REQUEST now=%d\\n",gd.time_get_ticks_msec(gd.singleton_time()))}')
edit(p,before,s)
p=out/'replay/project/scripts/scrapyard.odin';before=p.read_text();s=before
marker='if err := frame_session(self, dt, control); err != .None {'
s=s.replace(marker,'before := self.session.authority ? self.session.server.timeline.head : self.session.client.timeline.head\n\t'+marker,1)
marker='if self.session.control_consumed {r.buttons_consume(&self.buttons); self.dash_next = false}'
s=s.replace(marker,'after := self.session.authority ? self.session.server.timeline.head : self.session.client.timeline.head\n\tif control.dash {fmt.printf("INPUT_FRAME before=%d after=%d pending=%t now=%d\\n",before,after,self.dash_next,gd.time_get_ticks_msec(gd.singleton_time()))}\n\t'+marker,1)
edit(p,before,s)
p=out/'replay/project/shared/game/game.odin';before=p.read_text();s=before.replace('package scrapyard_game','package scrapyard_game\nimport "core:fmt"',1).replace('if input.dash && ctx.tick >= player.dash_ready {','if input.dash {fmt.printf("INPUT_MODEL seat=%d tick=%d ready=%d dashes=%d\\n",i+1,ctx.tick,player.dash_ready,player.dashes)}\n\t\tif input.dash && ctx.tick >= player.dash_ready {').replace('player.dashes += 1','player.dashes += 1\n\t\t\t\tfmt.printf("INPUT_EXECUTED seat=%d tick=%d dashes=%d\\n",i+1,ctx.tick,player.dashes)')
edit(p,before,s)

# Buffer records instead of printing in the timing-sensitive input/replay path.
replacements={
 'framework/replay/net/client.odin':[
 ('fmt.printf("INPUT_SAMPLE seat=%d tick=%d now=%d phase=%v depth=%d limit=%d\\n",c.seat,c.timeline.head+1,c.now,c.phase,c.timeline.head-c.timeline.confirmed,c.cfg.max_prediction)', 'input_audit_note(.Sample,c.seat,c.timeline.head+1,c.now,u64(c.phase),c.timeline.head-c.timeline.confirmed,u64(c.cfg.max_prediction))'),
 ('fmt.printf("INPUT_CAPTURE seat=%d tick=%d now=%d\\n",c.seat,tick,c.now)', 'input_audit_note(.Capture,c.seat,tick,c.now)'),
 ('fmt.printf("INPUT_SENT seat=%d tick=%d now=%d\\n",c.seat,sample.tick,c.now)', 'input_audit_note(.Sent,c.seat,sample.tick,c.now)')],
 'framework/replay/net/server.odin':[
 ('fmt.printf("INPUT_RECEIVED seat=%d tick=%d now=%d head=%d future_limit=%d\\n",peer.seat,sample.tick,s.now,s.timeline.head,s.cfg.max_future)', 'input_audit_note(.Received,peer.seat,sample.tick,s.now,s.timeline.head,u64(s.cfg.max_future))'),
 ('fmt.printf("INPUT_ACCEPTED seat=%d tick=%d now=%d head=%d\\n",peer.seat,sample.tick,s.now,s.timeline.head)', 'input_audit_note(.Accepted,peer.seat,sample.tick,s.now,s.timeline.head)')],
 'replay/project/scripts/comparison_mixed.odin':[
 ('fmt.printf("INPUT_REQUEST now=%d\\n",gd.time_get_ticks_msec(gd.singleton_time()))', 'net.input_audit_note(.Request,0,0,gd.time_get_ticks_msec(gd.singleton_time()))')],
 'replay/project/scripts/scrapyard.odin':[
 ('fmt.printf("INPUT_FRAME before=%d after=%d pending=%t now=%d\\n",before,after,self.dash_next,gd.time_get_ticks_msec(gd.singleton_time()))', 'net.input_audit_note(.Frame,0,before,gd.time_get_ticks_msec(gd.singleton_time()),after,u64(self.dash_next))')],
 'replay/project/shared/game/game.odin':[
 ('fmt.printf("INPUT_MODEL seat=%d tick=%d ready=%d dashes=%d\\n",i+1,ctx.tick,player.dash_ready,player.dashes)', 'net.input_audit_note(.Model,u16(i+1),ctx.tick,0,player.dash_ready,u64(player.dashes))'),
 ('fmt.printf("INPUT_EXECUTED seat=%d tick=%d dashes=%d\\n",i+1,ctx.tick,player.dashes)', 'net.input_audit_note(.Executed,u16(i+1),ctx.tick,0,u64(player.dashes))')]
}
for name,items in replacements.items():
 p=out/name;text=p.read_text()
 for old,new in items:
  old=old.replace(chr(92)*2+'n',chr(92)+'n');assert text.count(old)==1,(name,old);text=text.replace(old,new)
 if name.endswith('comparison_mixed.odin'):text=text.replace('import "core:fmt"','import "core:fmt"\nimport net "godot:replay/net"',1)
 if name.endswith('scripts/scrapyard.odin'):
  marker='replay_scrapyard_exit_tree :: proc(self: ^ReplayScrapyard) {';assert marker in text;text=text.replace(marker,marker+'\n net.input_audit_dump();',1)
 p.write_text(text);changes[name]['after']=hashlib.sha256(text.encode()).hexdigest()
helper=framework/'replay/net/input_audit.odin';shutil.copy2(Path(__file__).with_name('buffer.odin'),helper)
changes[str(helper.relative_to(out))]={'before':None,'after':hashlib.sha256(helper.read_bytes()).hexdigest()}

(out/'audit-manifest.json').write_text(json.dumps({'profile':profile,'original_root':str(root),'collection':str(framework),'changes':changes,'scope':'Bounded read-only diagnostic records, dumped after gameplay, in copied framework/game; excluded from performance comparison.'},indent=2)+'\n')
print('REPLAY_INPUT_AUDIT_PREPARED')

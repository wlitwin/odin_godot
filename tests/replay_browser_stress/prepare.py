from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).parent;out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_jam_comparison/prepare.py'),str(out)],check=True)
project=out/'replay/project'
s=(root/'tests/replay_jam_comparison/driver.gd').read_text().replace('extends SceneTree','extends Node',1)
a=s.index('func write(');b=s.index('func fail(',a)
s=s[:a]+'''func write(name:String,value:Dictionary):
 JavaScriptBridge.eval("globalThis.stressReceipts["+JSON.stringify(name)+"]="+JSON.stringify(value)+";0",true)
func both(name:String)->bool:
 return bool(JavaScriptBridge.eval("Boolean(globalThis.stressBarriers["+JSON.stringify(name)+"])",true))
'''+s[b:]
a=s.index('func finish(');b=s.index('func census():',a)
s=s[:a]+'''func finish(code:int):
 if finished:return
 finished=true
 JavaScriptBridge.eval("globalThis.stressExit="+str(code)+";0",true)
'''+s[b:]
a=s.index('func _initialize():');b=s.index(' if implementation=="kit":game.call',a)
s=s[:a]+'''func _ready():
 if not OS.has_feature("web"):set_process(false);return
 game=get_parent();implementation="replay";condition="delay"
 role=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('role')",true))
 JavaScriptBridge.eval("globalThis.stressReceipts={};globalThis.stressBarriers={};globalThis.stressExit=null;globalThis.stressHashes={};0",true)
 started=Time.get_ticks_msec();run.call_deferred()
func run():
'''+s[b:]
s=s.replace('await process_frame','await get_tree().process_frame').replace('multiplayer_poll=false;','')
s+='''
var stress_command_handled:=0
var stress_query_handled:=0
var stress_hashing:=false
var stress_hashed:=0
func _process(_dt:float):
 var raw:=str(JavaScriptBridge.eval("JSON.stringify(globalThis.stressCommand||null)",true))
 if raw!="null":
  var command:Dictionary=JSON.parse_string(raw)
  if int(command.id)>stress_command_handled:
   match str(command.kind):
    "resume":game.set_process(true)
    "dash":game.dev_drive(0,1,true)
    "stop":game.dev_drive(0,0,false)
    "hashes":stress_hashing=true;stress_hashed=int(game.probe("head",1));JavaScriptBridge.eval("globalThis.stressHashes={};0",true)
   stress_command_handled=int(command.id)
   JavaScriptBridge.eval("globalThis.stressAck="+str(stress_command_handled)+";0",true)
 if stress_hashing and bool(game.probe("ready",1)):
  var head:=int(game.probe("head",1));var through:=mini(head,stress_hashed+8);var hashes:={}
  for tick in range(maxi(stress_hashed+1,head-127),through+1):
   var value=game.probe_hash(tick)
   if value!=-1:hashes[str(tick)]=str(value)
  stress_hashed=through
  JavaScriptBridge.eval("Object.assign(globalThis.stressHashes,"+JSON.stringify(hashes)+");Object.keys(globalThis.stressHashes).slice(0,-512).forEach(k=>delete globalThis.stressHashes[k]);0",true)
 var query:=int(JavaScriptBridge.eval("globalThis.stressQuery||0",true))
 if query>stress_query_handled:
  stress_query_handled=query;var value={"query":query,"ready":game.probe("ready",1),"head":game.probe("head",1),"dashes":game.probe("dashes",2),"dash_pending":game.dash_probe("pending"),"dash_confirmed":game.dash_probe("confirmed")}
  for key in ["credit_r","credit_u","assembly_bytes","assembly_limit","rtc_failed","tx_r","tx_u","tx_bytes","rx_bytes","fragment_deferred","queue_limited","queue_limit","backup_tick"]:value[key]=game.browser_network_probe(key)
  for key in ["resyncs","resync_reason","facts","confirmed","predhead","fullsnaps","deltasnaps","large_snapshots","shuffled_snapshots","snapshot_parity_received","snapshot_shards_recovered","action_copy_batches","snapshot_every"]:value[key]=game.probe(key,1)
  JavaScriptBridge.eval("globalThis.stressState="+JSON.stringify(value)+";0",true)
'''
(project/'web_stress.gd').write_text(s)
p=project/'main.tscn';s=p.read_text().replace('[gd_scene format=3]','[gd_scene format=3]\n[ext_resource type="Script" path="res://web_stress.gd" id="browser_stress"]',1);s+='\n[node name="BrowserStress" type="Node" parent="."]\nscript = ExtResource("browser_stress")\n';p.write_text(s)
(project/'scripts/browser_stress.odin').write_text('''package replay_scrapyard
import gd "godot:godot"
import tr "godot:replay/transport"
import net "godot:replay/net"
import rgd "godot:replay/godot"
@(gd_method)
replay_scrapyard_browser_network_probe :: proc(self:^ReplayScrapyard,key:string)->gd.Int {
 if self.session==nil {return -1}
 if key=="rtc_failed" {return gd.Int(self.session.rtc.failed_peers)}
 if key=="queue_limited" {return gd.Int(self.session.rtc.fragments.stats.queue_limited)}
 if key=="queue_limit" {return gd.Int(self.session.rtc.fragments.unreliable_queue_packets)}
 if key=="backup_tick" {receipt,valid:=rgd.session_backup_receipt(self.session);return valid ? gd.Int(receipt.archive.tick) : -1}
 if key=="tx_bytes" {return gd.Int(self.session.rtc.fragments.tx_bytes)}
 if key=="rx_bytes" {return gd.Int(self.session.rtc.fragments.rx_bytes)}
 if key=="fragment_deferred" {return gd.Int(self.session.rtc.fragments.stats.deferred)}
 if key=="tx_r" || key=="tx_u" {n:=0;for item in self.session.rtc.fragments.tx {if item.id!=0 && (item.channel==.Reliable)==(key=="tx_r") {n+=1}};return gd.Int(n)}
 if key=="credit_r" || key=="credit_u" {
  highest:=u64(0);channel:=key=="credit_r" ? tr.Channel.Reliable : .Unreliable
  for peer in self.session.rtc.slots {if peer.id!=0 {highest=max(highest,peer.tx[channel]-peer.acked[channel])}}
  return gd.Int(highest)
 }
 if key=="assembly_bytes" {total:=0;for slot in self.session.client.snapshot_parts {total+=len(slot.data)+len(slot.parity)};return gd.Int(total)}
 if key=="assembly_limit" {return gd.Int(net.SNAPSHOT_ASSEMBLIES*(tr.MAX_PACKET_BYTES+2*((tr.MAX_PACKET_BYTES+7)/8+net.SNAPSHOT_PART_BYTES)))}
 return -1
}
''')
files=[p for p in out.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
(out/'source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(out))+'\n' for p in sorted(files)))
(out/'browser-contract.json').write_text(json.dumps({'workload':'Existing jam driver and gameplay gates; browser transport evidence is separate from native ENet comparison.','simulation_hz':60,'snapshot_every':3,'message_delay_ms':40,'message_jitter_ms':10,'unreliable_loss_permyriad':500,'unreliable_duplicate_permyriad':500,'queue_bytes':65536,'queue_packets':128,'credit_blackout_ms':400,'source_driver_sha256':hashlib.sha256((root/'tests/replay_jam_comparison/driver.gd').read_bytes()).hexdigest()},indent=2)+'\n')
print('REPLAY_BROWSER_STRESS_PREPARED')

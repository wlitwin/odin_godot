"""Opt-in receive/baseline diagnostics for a prepared project, before building."""
from pathlib import Path
import hashlib,json,sys
out=Path(sys.argv[1]).resolve();p=out/'project/scripts/claimball.odin'
s=p.read_text();assert 'diagnostic_second' not in s,'already instrumented'
needle='\tif !self.session.authority && self.session.client.resync_notice.serial > self.resync_seen {'
block='\tif gd.env_int("RCB_DIAGNOSTIC",0)==1 && now/1000!=self.diagnostic_second {\n self.diagnostic_second=now/1000\n\t\tif self.session.authority {\n\t\t\tfor peer,i in self.session.server.peers {if peer.spectator && peer.connection!=0 {\n\t\t\t\ttx:=self.session.server.snapshot_tx[i]\n\t\t\t\tgd.print_str(fmt.tprintf("RCB_SNAPSHOT_TX tick=%d base=%d next=%d pending=%d force=%v parts=%v size=%d rejected=%d misses=%d",self.session.server.timeline.head,tx.baseline_id,tx.next_id,tx.reliable_pending,tx.force_full,tx.parts_enabled,tx.part_size,self.session.server.stats.rejected_acks,self.session.server.stats.baseline_misses))\n\t\t\t}}\n\t\t} else if self.session.client.spectator {\n\t\t\tc:=&self.session.client\n\t\t\tgd.print_str(fmt.tprintf("RCB_SNAPSHOT_RX head=%d confirmed=%d facts=%d latest=%d pending=%d has=%v rejected=%d misses=%d full=%d delta=%d",c.timeline.head,c.journal.confirmed,c.facts_contiguous,c.snapshot_latest,c.pending.frame.tick,c.has_pending,c.stats.rejected_packets,c.stats.baseline_misses,c.stats.full_snapshots,c.stats.delta_snapshots))\n\t\t}\n\t}\n'
assert s.count(needle)==1
s=s.replace(needle,block+needle).replace('local_kicks, remote_kicks,','diagnostic_second:u64,\n local_kicks, remote_kicks,')
p.write_text(s)
manifest=json.loads((out/'prepared.json').read_text());manifest['scripts/claimball.odin']=hashlib.sha256(p.read_bytes()).hexdigest();(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')

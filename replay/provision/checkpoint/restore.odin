package replay_checkpoint

import auth "godot:replay/authority"
import net "godot:replay/net"
import tf "godot:replay/transfer"

// Own the validated downloaded checkpoint before releasing Client's transfer
// buffers. Game-specific asset preparation must finish before client_restore.
client_prepare :: proc(c:^Client,p:^auth.Prepared,model:net.Model($S,$C,$A,$E,$N),allocator:=context.allocator,codec:^net.Checkpoint_Codec=nil)->Error {
	if p.ready {return .Busy}
	cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
	if client_decode(c,&cp,model,allocator,codec)!=.None {return .Schema}
	bytes:=make([]u8,len(c.saved.bytes),allocator);copy(bytes,c.saved.bytes)
	p^={allocator=allocator,ready=true,point=c.saved.publication.point,bytes=bytes}
	return .None
}

// Uses the authority Lease's request sequence, so no ordinary RPC may be pending
// concurrently. A correlated reply establishes the lease; retained bytes alone
// never authorize a simulation. Caller keeps Prepared until restore completes.
client_restore :: proc(c:^Client,lease:^auth.Lease,publication:Publication,prepared:^auth.Prepared)->Error {
	if !c.ready || lease==nil || !lease.ready || !prepared.ready || !publication_valid(publication) || publication.point!=prepared.point ||
	   tf.hash(prepared.bytes)!=publication.point.archive.hash || len(prepared.bytes)!=int(publication.point.archive.bytes) ||
	   c.lane.request.identity!=lease.identity || c.lane.request.room!=lease.room || c.lane.request.content!=lease.content {return .Invalid}
	if c.phase==.Requesting || c.phase==.Transferring || lease.pending {return .Busy}
	sequence,error:=auth.lease_request(lease);if error!=.None {return .Busy}
	q:=c.lane.request;q.verb,q.sequence,q.generation,q.authority_epoch=.Restore,sequence,lease.view.coordinator_generation,lease.view.epoch
	q.payload={}
	q.revision,q.point,q.contract=publication.revision,publication.point,publication.contract
	if e:=client_begin(c,q);e!=.None {auth.lease_cancel_request(lease);return e}
	c.restore_lease=lease
	return .None
}

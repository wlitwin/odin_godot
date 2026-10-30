#+build darwin, linux
package replay_provision_sqlite

import "core:mem"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"
import tr "godot:replay/transport"

Checkpoint_Backend :: struct($S,$C,$A,$E:typeid,$N:int) {store: ^Store, model: net.Model(S,C,A,E,N),assets:ck.Asset_Policy}
checkpoint_backend :: proc(b:^Checkpoint_Backend($S,$C,$A,$E,$N))->ck.Backend {
	return {user=b,
		load=proc(user:rawptr,room,content:u64,allocator:mem.Allocator)->(ck.Saved,bool,ck.Error) {
			b:=cast(^Checkpoint_Backend(S,C,A,E,N))user
			value,found,error:=checkpoint_load(b.store,room,content,b.model,allocator,assets=b.assets)
			return value,found,checkpoint_error(error)
		},
		publish=proc(user:rawptr,expected:auth.Record,revision,contract:u64,point:auth.Point,bytes:[]u8,guard:ck.Commit_Guard,payload:[]u8)->(ck.Publication,ck.Error) {
			b:=cast(^Checkpoint_Backend(S,C,A,E,N))user
			contract:=contract
			value,error:=checkpoint_publish(b.store,expected,revision,point,bytes,b.model,&contract,guard,payload,b.assets)
			return value,checkpoint_error(error)
		},
		recover=proc(user:rawptr,service:^auth.Service,from:tr.Peer_Id,actor:auth.Identity,nonce:auth.Nonce,sequence:u64,digest:[32]u8,epoch:u64,publication:ck.Publication)->(auth.Error,bool) {
			b:=cast(^Checkpoint_Backend(S,C,A,E,N))user
			if service==nil || !service.ready || b.store.recovery_publication!=nil || b.store.connection.transaction {return .Invalid,false}
			saved,found,error:=checkpoint_load(b.store,service.coordinator.record.room,service.coordinator.record.content,b.model,assets=b.assets)
			defer stored_checkpoint_destroy(&saved)
			if error!=.None {return .Storage,false};if !found || saved.publication!=publication {return .No_Checkpoint,false}
			// A cooperative restore must have an existing playable reservation for
			// this stable token. An enrolled peer absent from the save cannot assume
			// another player's local seat. Dedicated infrastructure uses local seat 0.
			if service.coordinator.record.policy.mode==.Cooperative {
				cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
				if net.checkpoint_decode(&cp,saved.bytes,b.model,service.coordinator.record.content)!=.None {return .Invalid,false}
				hash:[32]u8;for m in service.coordinator.record.members {if m.identity==actor {hash=m.game_token_hash;break}}
				present:=false;for peer in cp.peers {if !peer.spectator && peer.seat!=0 && peer.token_hash==hash {present=true;break}}
				for banned in cp.banned {if banned==hash {present=false}}
				if !present {return .Denied,false}
			}
			publication:=publication;payload:=ck.payload_for(publication.point,saved.payload)
			b.store.recovery_publication,b.store.recovery_payload=&publication,&payload
			defer {b.store.recovery_publication,b.store.recovery_payload=nil,nil}
			return auth.service_recover_published(service,from,actor,nonce,sequence,digest,epoch,publication.point)
		}}
}
@(private)
checkpoint_error :: proc(e:Error)->ck.Error {
	switch e {case .None:return .None;case .Invalid:return .Invalid;case .Schema:return .Schema;case .Conflict:return .Stale;case .Open,.Configuration,.Read,.Write:return .Storage}
	return .Storage
}

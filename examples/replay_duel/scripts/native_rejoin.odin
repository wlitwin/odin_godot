package replay_duel

import "core:fmt"
import gd "godot:godot"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"

// Fixed loopback test provider: the creator returns at the configured address.
// Closing the old owner retires its receive/delay buffers even though the new
// remote ENet server again has physical ID 1. The player runner is untouched.
duel_native_rejoin_transport :: proc(self:^ReplayDuel,now:u64) {
	when !gd.IS_WEB {
		if self.listening || self.spectator || (!self.native_rejoining && self.peer.phase!=.Disconnected) {return}
		tr.poll(&self.delay.base)
		if self.native_rejoining && (tr.status(&self.delay.base)!=.Disconnected || now<self.native_retry_at) {return}
		tr.close(&self.wire)
		if !rgd.enet_join(&self.enet,"127.0.0.1",u16(duel_int("RDP_PORT",49520))) {duel_fail(self,"native rejoin connection");return}
		base:=rgd.enet_transport(&self.enet)
		if !tr.delay_init(&self.delay,base,u32(duel_int("RDP_LATENCY",0))) {tr.close(&base);duel_fail(self,"native rejoin delay");return}
		tr.delay_faults(&self.delay,u32(duel_int("RDP_JITTER",0)),u32(duel_int("RDP_LOSS",0)),u32(duel_int("RDP_DUPLICATE",0)),42)
		tr.delay_time(&self.delay,now);self.wire=tr.delay_transport(&self.delay)
		self.native_rejoining=true;self.native_retry_at=now+1000;self.native_rejoin_attempts+=1
		gd.print_str(fmt.tprintf("RDP_NATIVE_TRANSPORT_REOPEN attempt=%d head=%d confirmed=%d",self.native_rejoin_attempts,self.peer.timeline.head,self.peer.timeline.confirmed))
	}
}

package replay_duel

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import game "../shared/duel"

duel_direct_options :: proc() -> (rgd.P2P_Direct_Options, bool) {
    address := duel_param("RDP_BIND_ADDRESS", "")
    port := duel_int("RDP_BIND_PORT", 0)

    if address == "" && port == 0 {
        return {}, true
    }

    if address == "" {
        address = duel_param("RDP_ADDRESS", "127.0.0.1")
    }

    if port == 0 {
        port = duel_int("RDP_PORT", 49520)
    }

    if port < 1 || port > 65535 {
        return {}, false
    }

    endpoint, valid := auth.endpoint(address, u16(port))
    return {listen = endpoint}, valid
}

duel_online_ready :: proc(self: ^ReplayDuel) -> bool {
    mode := duel_param("RDP_PARTY", "")

    if mode == "" {
        return false
    }

    self.online_enabled = true

    if (mode != "create" && mode != "join" && mode != "rejoin") || self.spectator || self.watch_enabled {
        duel_fail(self, "invalid participant enrollment mode")
        return true
    }

    local := duel_int("RDP_LOCAL", 0) == 1
    storage, storage_ok := duel_online_storage_open(self, local)

    if !storage_ok {
        duel_fail(self, "native enrollment storage")
        return true
    }

    endpoint, _ := auth.endpoint("rtc", 1)

    when !gd.IS_WEB {
        if self.archive_path == "" {
            self.archive_path = strings.clone("user://duel-participant.rply")
        }

        port := duel_int("RDP_PORT", 49520)
        valid: bool

        if port < 1 || port > 65535 {
            duel_fail(self, "native endpoint port")
            return true
        }

        endpoint, valid = auth.endpoint(duel_param("RDP_ADDRESS", "127.0.0.1"), u16(port))

        if !valid {
            duel_fail(self, "native endpoint")
            return true
        }
    }

    cfg := rgd.Party_Config {
        service           = duel_param("RDP_SERVICE", ""),
        namespace         = "replay-duel-rooms",
        content           = game.CONTENT,
        endpoint          = endpoint,
        invite_role       = .Player,
        invite_uses       = 1,
        local_development = local,
        storage           = storage,
        tls               = self.online_tls,
        ice_json          = duel_param("RDP_ICE", ""),
    }

    if !rgd.p2p_party_open(&self.online, cfg, 2) {
        duel_fail(self, "party enrollment configuration")
        return true
    }

    gd.set_string(self.status, "text", "Opening match enrollment…")
    return true
}

duel_online_frame :: proc(self: ^ReplayDuel) {
    o := &self.online
    rgd.p2p_party_frame(o)

    if o.failed {
        // Established P2P gameplay does not require a live enrollment service.
        // A future process/rejoin must register again; retained RTC credentials
        // remain scoped and the signaling provider still checks revocation.
        if !self.online_launched {
            duel_fail(self, rgd.p2p_party_message(o))
        }

        return
    }

    if !o.started && o.party.recent_loaded {
        mode := duel_param("RDP_PARTY", "")
        ticket: p.Ticket

        if mode == "join" {
            valid: bool
            ticket, valid = p.ticket_parse(duel_param("RDP_INVITE", ""))

            if !valid {
                duel_fail(self, "invalid match invite")
                return
            }
        }

        if !rgd.p2p_party_begin(o, mode == "create" ? .Create : mode == "join" ? .Join : .Rejoin, ticket) {
            duel_fail(self, "match enrollment could not begin")
            return
        }
    }

    if !self.online_launched {
        gd.set_string(self.status, "text", fmt.ctprintf("%s", rgd.p2p_party_message(o)))

        if o.party.invited {
            gd.set_string(
                self.room_label,
                "text",
                "Invitation ready — use Copy join link to invite the other player.",
            )
        }

        if !o.ready {
            return
        }

        self.admission = o.authorization
        self.authenticated = true
        self.listening = self.admission.identity.member == self.admission.match.members[0]
        self.online_launched = true
        self.started = gd.time_get_ticks_msec(gd.singleton_time())
        gd.print_str(
            fmt.tprintf(
                "RDP_PROVISIONED session=%d member=%d incarnation=%d",
                self.admission.match.session,
                self.admission.identity.member,
                self.admission.identity.incarnation,
            ),
        )
        duel_start(self)
    }
}

@(gd_method)
replay_duel_party_invite :: proc(self: ^ReplayDuel) -> string {
    return self.online_enabled && self.online.party.invited ? string(self.online.party.code[:]) : ""
}

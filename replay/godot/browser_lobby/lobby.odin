// Short-code browser host/join for a player-hosted game without host migration.
// Keep the Lobby at a stable address until after its Room closes.
package browser_lobby

import "core:fmt"
import "core:mem"
import gd "godot:godot"
import auth "godot:replay/authority"
import rg "godot:replay/godot"
import p "godot:replay/provision"

Lobby :: struct {
    party:         rg.Party,
    ticket:        p.Ticket,
    host, started: bool,
}

begin :: proc(
    l: ^Lobby,
    service, namespace: string,
    content: u64,
    host: bool,
    code: string,
    guests: u8,
    allocator := context.allocator,
) -> string {
    if l.party.initialized {return "A room is already open."}
    l.host = host
    if !host {
        ticket, valid := p.short_ticket_parse(code, content)
        if !valid {return "Enter the five-character room code from the host."}
        l.ticket = ticket
    }
    endpoint, _ := auth.endpoint("127.0.0.1", 49742)
    local := gd.launch_param("REPLAY_LOCAL_SERVICE", "local", "0") == "1"
    url := gd.launch_param("REPLAY_SERVICE", "service", service)
    if !rg.party_open(
        &l.party,
        {
            service = url,
            namespace = fmt.tprintf("%s-%016x", namespace, content),
            content = content,
            endpoint = endpoint,
            invite_role = .Player,
            invite_uses = guests,
            short_codes = true,
            browser_seats = true,
            local_development = local,
            relay_credentials = !local,
        },
        allocator,
    ) {
        return "Could not open room storage or connect to the configured service."
    }
    return ""
}

// Poll throughout the game so short-lived relay credentials stay current.
poll :: proc(l: ^Lobby) -> (ready: bool, problem: string) {
    rg.party_frame(&l.party)
    if l.party.failed {return false, fmt.tprintf("%s (%v / %v)", rg.party_message(&l.party), l.party.error, l.party.protocol_error)}
    if !l.started && l.party.recent_loaded {
        if !rg.party_begin(&l.party, l.host ? .Create : .Join, l.ticket) {
            return false, "Could not start room enrollment."
        }
        l.started = true
    }
    if l.party.invite_error != .None {return false, "The room service could not issue an invitation."}
    return l.party.ready, ""
}

options :: proc(l: ^Lobby, s: rg.Session_Options) -> (rg.Room_Options, bool) {
    opts, ok := rg.party_room_options(&l.party, s)
    opts.automatic_successor = false
    opts.restore_published = false
    opts.session.replication.accept_checkpoints = false
    return opts, ok
}

code :: proc(l: ^Lobby) -> string {
    if l == nil || !l.party.invited {return ""}
    return string(l.party.code[:l.party.code_count])
}

close :: proc(l: ^Lobby) {
    if l == nil {return}
    rg.party_close(&l.party)
    l^ = {}
}

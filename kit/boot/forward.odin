package kit_boot

// THE KIT-SIDE EVENT TABLE — complete by construction.
//
// The GAME-facing half of session-event delivery has been complete for a
// while: scriptgen's SESSION_EVENTS table generates the dispatch and its role
// gates, so a game cannot half-wire a reaction it declared. The KIT's own half
// — the forwards that exist precisely SO NO GAME EVER HAS TO REMEMBER THEM —
// was the opposite shape: three hand-written `#partial switch`es (the lane's
// ownership move in boot_pump, the lane's player drop right below it, the
// succession machine in succession.odin), each enumerating the variants whose
// consequence its author happened to be thinking about. A twenty-third session
// event with a lane or a succession consequence compiled perfectly clean with
// its forward simply missing, and the symptom showed up weeks later wearing a
// disguise ("the host pops a departed seat's input buffers every tick
// forever").
//
// So the enumeration is ONE switch, and it is not `#partial` — which is Odin's
// way of saying every variant must be named or the package does not build.
// Variants with no kit-side consequence are named too, with an empty body and
// the one word that says WHY they are empty; that word is the review, and it
// makes this a decision table instead of a wall of no-ops. Adding an Event
// variant now fails to compile until somebody has decided — the same mechanism
// SES_KIND_COUNT and the wire-rev registration already stand on.
//
// This is the KIT's table only. Every event still rides out of boot_pump
// untouched for the game's own generated dispatch; nothing here consumes an
// event on a game's behalf, and nothing here is a place to put game logic.

import ksess "godot:kit/session"
import ksim "godot:kit/sim"
import kui "godot:kit/ui"

@(private)
boot_forward :: proc(b: ^Boot, ev: ksess.Event) {
	switch e in ev {

	// ---- seats -------------------------------------------------------------

	case ksess.Ev_Welcomed:
		boot_succ_seated(b) // seated means a host EXISTS: any chase window shuts
		// The roster RODE the welcome — paint it now, not at the next change.
		kui.lobby_refresh(&b.ui, b.ses)
		kui.score_refresh(&b.score, b.ses)
		kui.lobby_set_status(&b.ui, "Seated — waiting for the host to start")

	case ksess.Ev_Player_Joined:
		roster_changed(b)

	case ksess.Ev_Player_Left:
		// The lane hears departures like it hears ownership moves — same
		// no-game-ever-forgets rule: without the drop, the host pops the
		// departed seat's input buffers every tick forever and their entities
		// coast on held inputs.
		if b.lane != nil {
			ksim.lane_drop_player(b.lane, e.id)
		}
		roster_changed(b)

	case ksess.Ev_Host_Left:
		boot_succ_lost(b) // the takeover/rejoin window opens
		kui.lobby_set_status(&b.ui, "The host left — round over")
		// The phase deliberately stays put: the SEAT outlives the socket, and
		// succession may re-seat it — the welcome moves the phase, not the loss.

	case ksess.Ev_Join_Failed:
		boot_doors_again(b, "Could not reach the host")

	case ksess.Ev_Join_Denied:
		// The host said no, deliberately — so say which no. (This arm used to
		// set a phase byte and nothing else: the human got a lobby frozen on
		// "Joining..." with the doors still hidden, for every refusal reason.)
		boot_doors_again(b, deny_words(e.reason))

	case ksess.Ev_Kicked:
		boot_succ_shown_door(b) // a kicked player never chases the torch
		boot_doors_again(b, "Removed from the room")

	// ---- migration ----------------------------------------------------------

	case ksess.Ev_Backup_Target:
		boot_succ_torch(b, e.player) // host: light the torch for this holder

	case ksess.Ev_Succession:
		boot_succ_noted(b, e.successor) // NOTED only — mechanics wait for the words halves

	case ksess.Ev_Backup_Received:
		// STORAGE. The session already holds the blob (opaque until a resume
		// parses it); nothing on this side of the wire acts on its arrival.

	// ---- the world reaching this screen -------------------------------------

	case ksess.Ev_Spawned, ksess.Ev_Resynced, ksess.Ev_State_Applied:
		// The one fact boot_phase cannot read off the session: the world is on
		// THIS screen. Every role lands here — a raw host's own first spawn
		// too — which is what makes the raw path (netgd/ksess by hand) report
		// a truthful phase without boot's doors ever having been touched. (A
		// boot host with the generated dispatcher hears its OWN spawns at the
		// send instead — boot_born, entities.odin — and raises this latch via
		// world_pending at the same pump; only its Ev_Spawned skips this arm.)
		b.world_seen = true

	case ksess.Ev_Despawned:
		// FACTORY. The removal already ran through boot_free_entity — node
		// freed, ledger cleared, lane_untrack forwarded there — before this
		// event was ever queued. A second forward here would be a double free.

	case ksess.Ev_Owner_Changed:
		// The lane must always hear ownership moves (predicted↔watched, whose
		// inputs drive it, whom rewinds spare) — forwarded here so no game ever
		// forgets the line.
		if b.lane != nil {
			ksim.lane_set_owner(b.lane, e.id, e.owner)
		}

	case ksess.Ev_Entity_Changed:
		// GAME-FACING. Opt-in per-entity change notice (Session_Config
		// .change_events) for games that drive presentation off it; the kit
		// dresses nothing per entity.

	case ksess.Ev_Blob_Changed:
		// GAME-FACING. The blob's meaning is the game's whole and only.

	// ---- stats, profiles, commands ------------------------------------------

	case ksess.Ev_Stats_Updated:
		kui.score_refresh(&b.score, b.ses)

	case ksess.Ev_Profile_Changed:
		// GAME-FACING. No kit widget reads profile rows — the stock scoreboard
		// paints the STAT table (Ev_Stats_Updated, above) and the roster paints
		// names. A kit widget that ever grows a profile column adds its repaint
		// here, and this comment is how it will find the spot.

	case ksess.Ev_Command_Executed:
		// AUTHORITY RECEIPT. The command already ran inside the session; this
		// is the host's word about it, for scoreboards and logs.

	case ksess.Ev_Command_Confirmed, ksess.Ev_Command_Rejected:
		// SIM WIRE. The lane learns every verdict on its OWN channel
		// (lane_handle → cmd_settle, which re-runs the surviving chain and
		// culls a refused fire's predicted spawn). Forwarding the session's
		// copy would settle each verdict twice.

	case nil:
		// A polled event is never nil — session_poll hands back what the queue
		// was appended, and nothing appends the zero value. Named because the
		// switch is exhaustive, which is the whole point of this file.
	}
}

// The three ways a seat ends before it began — a refusal, a denial, a kick.
// Every one of them used to write `b.phase = .Menu` and stop there, and the
// phase had no consumers, so what the HUMAN got was a lobby stuck on
// "Joining..." with the doors still hidden by the join door that opened them.
// Only the join-CODE path ever put the menu back (boot_code_pulse's .Failed
// arm) — this is that same line, owed to the other three ends and paid.
@(private = "file")
boot_doors_again :: proc(b: ^Boot, status: string) {
	kui.lobby_set_status(&b.ui, status)
	kui.lobby_show_menu(&b.ui, true, false)
}

// Deny_Reason in a sentence. Full, not `#partial`, for the same reason the
// table above is: a fifth way to say no must be worded, not silently rendered
// as the fourth.
@(private = "file")
deny_words :: proc(reason: ksess.Deny_Reason) -> string {
	switch reason {
	case .Full:
		return "The room is full"
	case .Locked:
		return "The host closed the door"
	case .Banned:
		return "You are not welcome in this room"
	case .Version:
		return "Different build — the host refused the version"
	}
	return "The host said no"
}

package kit_ui

// The NETGRAPH — a drop-in "is it healthy?" overlay, the same stock-theme,
// text-only contract as the rest of kit/ui. It answers the toolkit's one
// standing promise ("never feels sloppy — prove it for YOUR game under the
// latency shim") by drawing the numbers that move when latency does:
//
//   net  42ms  jit 6ms  ok          <- both models: round trip + quality
//   sim  lead 4t  resim ▁▁▂▁▇▁▁  rec 128   <- the sim lane only
//
// The RESIM SPARKLINE is the point. A steady sim costs a memcmp and draws a
// flat baseline; a latency event (a lost input, a jitter spike, a contested
// mispredict) makes the client rewind and replay — and that burst is exactly
// the thing you cannot feel in a headless test but can SEE here. sim.md calls
// a resim burst "a latency event worth drawing"; this draws it.
//
// DECOUPLED BY DESIGN: the widget renders a Net_Stats value the game fills, so
// it never imports kit/sim — a coop-only game leaves `sim` false and gets the
// one-line rtt read; a sim game adds the lane tallies (lane.stat_resims,
// lane.stat_reconciles, ksim.lane_lead). net_ping_ms is the shared read: the
// local player's ping straight off the replicated stat, host or client.

import gd "godot:godot"
import ksess "godot:kit/session"
import "core:fmt"
import "core:strings"

// What to draw. The game fills it each frame; every field is optional (a zero
// value simply reads as "quiet"). rtt/jitter are milliseconds.
Net_Stats :: struct {
	rtt_ms:    f64, // round trip; net_ping_ms(s) is the easy fill
	jitter_ms: f64, // connection-quality wobble; netgd.wire_link_quality fills it on clients (ENet's rtt variance); 0 = unknown, quality falls back to rtt
	loss_pct:  f64, // packet loss percent — wire_link_quality again; drawn (and rated) when > 0
	sim:       bool, // draw the sim row? (false on the coop model)
	lead:      int, // ksim.lane_lead(l) — the client's working lead in ticks
	resims:    int, // lane.stat_resims — running tally; the widget sparks its per-frame delta
	recons:    int, // lane.stat_reconciles — running tally
	// The bytes-by-kind line, pre-formatted by netgd.wire_traffic(&boot.wire)
	// — the widget renders it opaquely ("" = skip the row), so kit/ui never
	// imports the transport.
	traffic:   string,
}

SPARK_N :: 24 // sparkline width, in refreshes

Netgraph :: struct {
	label:   gd.Label,
	spark:   [SPARK_N]u8, // ring of resim-per-refresh levels, 0..7 (block-char rows)
	head:    int, // next write slot
	seen:    int, // resims tally at the last refresh — the spark's shadow
	primed:  bool, // seen is valid (skip the first frame's bogus delta)
}

// Levels 0..8 as the eighth-blocks ▁▂▃▄▅▆▇█ (U+2581..U+2588); index 0 is the
// flat baseline a quiet sim holds.
@(private = "file")
SPARK_ROWS := [9]string {
	"\xE2\x96\x81", "\xE2\x96\x81", "\xE2\x96\x82", "\xE2\x96\x83", "\xE2\x96\x84",
	"\xE2\x96\x85", "\xE2\x96\x86", "\xE2\x96\x87", "\xE2\x96\x88",
}

netgraph_make :: proc(parent: gd.Node) -> Netgraph {
	ng: Netgraph
	ng.label = gd.new_label()
	gd.node_set_name(cast(gd.Node)ng.label, gd.new_string_name_cstring("Netgraph", true))
	gd.add_child(parent, cast(gd.Node)ng.label)
	// Top-left, lifted off the corner, and on TOP of the HUD — a diagnostic
	// reads over whatever it covers (scoreboard.odin makes the same call).
	gd.canvas_item_set_z_index(cast(gd.Canvas_Item)ng.label, 11)
	gd.control_set_position(cast(gd.Control)ng.label, {8, 8}, false)
	gd.set_bool(cast(gd.Object)ng.label, "visible", false)
	return ng
}

netgraph_destroy :: proc(ng: ^Netgraph) {
	ng^ = {}
	// The Label belongs to the scene (freed with the owner).
}

netgraph_show :: proc(ng: ^Netgraph, visible: bool) {
	gd.set_bool(cast(gd.Object)ng.label, "visible", visible)
}

// Roll the sparkline and repaint. Call once per frame with a freshly-filled
// Net_Stats; cheap enough to leave on, small enough to leave visible.
netgraph_refresh :: proc(ng: ^Netgraph, stats: Net_Stats) {
	// The resim spark tracks the DELTA since last refresh — a burst this frame,
	// not the lifetime total. First refresh has no baseline: prime, don't spark.
	if ng.primed {
		d := stats.resims - ng.seen
		level := u8(clamp(d, 0, 8))
		ng.spark[ng.head] = level
		ng.head = (ng.head + 1) % SPARK_N
	}
	ng.seen = stats.resims
	ng.primed = true

	b := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&b, "net  %.0fms", stats.rtt_ms)
	if stats.jitter_ms > 0 {
		fmt.sbprintf(&b, "  jit %.0fms", stats.jitter_ms)
	}
	if stats.loss_pct > 0 {
		fmt.sbprintf(&b, "  loss %.1f%%", stats.loss_pct)
	}
	fmt.sbprintf(&b, "  %s", net_quality(stats))

	if stats.traffic != "" {
		fmt.sbprintf(&b, "\n%s", stats.traffic)
	}

	if stats.sim {
		strings.write_string(&b, "\nsim  lead ")
		fmt.sbprintf(&b, "%dt  resim ", stats.lead)
		// Oldest-to-newest: walk the ring from head (the next slot = oldest).
		for i in 0 ..< SPARK_N {
			strings.write_string(&b, SPARK_ROWS[ng.spark[(ng.head + i) % SPARK_N]])
		}
		fmt.sbprintf(&b, "  rec %d", stats.recons)
	}

	gd.set_string(cast(gd.Object)ng.label, "text", fmt.ctprintf("%s", strings.to_string(b)))
}

// The connection-quality word: loss trumps everything (a lossy link feels
// broken at any latency), then jitter (a steady 120ms link beats one wobbling
// 40..200 — Clock_Sync's own note), then raw rtt as the fallback.
@(private = "file")
net_quality :: proc(stats: Net_Stats) -> string {
	if stats.loss_pct >= 2 {
		return "rough"
	}
	if stats.jitter_ms > 0 {
		switch {
		case stats.jitter_ms < 10 && stats.loss_pct < 0.5:
			return "good"
		case stats.jitter_ms < 30:
			return "ok"
		case:
			return "rough"
		}
	}
	if stats.loss_pct >= 0.5 {
		return "ok"
	}
	switch {
	case stats.rtt_ms < 60:
		return "good"
	case stats.rtt_ms < 120:
		return "ok"
	case:
		return "rough"
	}
}

// The shared rtt read: the LOCAL player's ping in ms, straight off the
// replicated stat column the session auto-feeds — so it answers on the host
// (from its own per-peer clock) and on every client (the host ships it) alike,
// on either netcode model. jitter is host-only (session_clock); fill it there
// if you want the quality word to key off it.
net_ping_ms :: proc(s: ^ksess.Session) -> f64 {
	return f64(ksess.session_stat(s, s.me, ksess.STAT_PING))
}

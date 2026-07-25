package shared_ids

// ----------------------------------------------------------------------------
// ids — the SHARED VOCABULARY of this project (res://shared/ids), imported by the
// main module, by one of its subpackages, and by the `enemies` script module. Three
// packages in TWO dlls compile these same declarations.
//
// Everything here is read-only by construction: an enum, a tuning constant, a payload
// struct and a pure proc. There is no package state to fork per dll — which is exactly
// the condition scriptgen verifies before allowing the cross-module import (a mutable
// global, an @(init), a //gd: marker or an import back into a module are all hard
// errors here; tests/shared_spike/run.sh pins each message).
//
// STEP is the value the reload phase edits: bumping it must rebuild and swap EVERY
// module, since any of them may be compiled against it.
// ----------------------------------------------------------------------------

// The entity vocabulary both dlls agree on.
Kind :: enum u8 {
	None   = 0,
	Player = 1,
	Enemy  = 2,
}

// A tuning constant. Edited in place by the reload phase (7 -> 70).
STEP :: 7

// A message payload both sides can build and read (a plain POD struct: no gd tags —
// scriptgen resolves replicated BUNDLES in the module or a godot: collection, never
// across the shared tree, and says so if you try).
Payload :: struct {
	kind:   Kind,
	amount: i32,
}

// A pure proc: same inputs, same answer, in whichever dll it was linked into.
brand :: proc(k: Kind) -> int {
	return int(k) * 100 + STEP
}

// A second pure proc, over the payload struct — the vocabulary's "protocol".
payload_code :: proc(p: Payload) -> int {
	return brand(p.kind) + int(p.amount)
}

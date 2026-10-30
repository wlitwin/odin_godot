package main

import "core:fmt"
import "core:os"
import rb "godot:replay/p2p"
import recording "../shared/recording"

main :: proc() {
	if len(os.args) != 2 {fmt.eprintln("usage: duel-verify <peer.rply>"); os.exit(2)}
	f, err := os.open(os.args[1])
	if err != nil {fmt.eprintln(err); os.exit(2)}
	defer os.close(f)
	// A bounded read also handles a file that grows after opening.
	bytes := make([]u8, rb.MAX_ARCHIVE_BYTES + 1); defer delete(bytes)
	n, read_error := os.read_at_least(f, bytes, len(bytes))
	if (read_error != nil && read_error != .EOF && read_error != .Unexpected_EOF) || n > rb.MAX_ARCHIVE_BYTES {
		fmt.eprintln("cannot read bounded archive", read_error); os.exit(2)
	}
	report := recording.verify(bytes[:n])
	fmt.printf("DUEL_ARCHIVE error=%v phase=%v base=%d head=%d confirmed=%d chain=%d mismatch_tick=%d expected=%d actual=%d\n",
	           report.error, report.phase, report.base, report.head, report.confirmed, report.chain, report.replay.tick, report.replay.expected, report.replay.actual)
	if report.phase == .Diverged {fmt.printf("DUEL_DISAGREEMENT peer=%d tick=%d local=%d remote=%d\n", report.disagreement.peer, report.disagreement.tick, report.disagreement.local_hash, report.disagreement.remote_hash)}
	if report.error != .None {os.exit(1)}
}

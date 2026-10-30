package main

import "core:fmt"
import "core:os"
import r "godot:replay"
import d "godot:replay/diagnostic"
import net "godot:replay/net"
import recording "../../shared/recording"
import game "../../shared/game"
import upgrade "../../shared/upgrade"

main :: proc() {
	os.exit(run())
}

run :: proc() -> int {
	legacy :=
		len(os.args) == 3 &&
		(os.args[2] == "--content48" || os.args[2] == "--content49" || os.args[2] == "--content50")
	if len(os.args) != 2 && !legacy {
		fmt.eprintln("usage: verify_recording FILE.rplrec [--content48|--content49|--content50]")
		return 2
	}
	bytes, ok := read_file(os.args[1])
	if !ok {
		fmt.eprintln("Cannot read a complete bounded recording")
		return 2
	}
	defer delete(bytes)
	if legacy {
		if os.args[2] == "--content50" {
			return verify(bytes, upgrade.model_50(), upgrade.RECORDING_50)
		}
		if os.args[2] == "--content49" {
			return verify(bytes, upgrade.model_49(), upgrade.RECORDING_49)
		}
		return verify(bytes, upgrade.model_48(), upgrade.RECORDING_48)
	}
	return verify(bytes, game.model(), recording.CONTEXT)
}

verify :: proc(
	bytes: []u8,
	source: net.Model($S, game.Control, $A, game.Event, game.SEATS),
	identity: d.Recording_Context,
) -> int {
	archive: d.Recording(S, net.Batch(game.Control, A, game.SEATS), net.Net_Event(game.Event))
	defer d.recording_destroy(&archive)
	if error := d.recording_decode(&archive, bytes, identity); error != .None {
		fmt.eprintf("Recording rejected: %v\n", error)
		return 2
	}
	model := source
	capture: r.Audit_Capture(S, net.Batch(game.Control, A, game.SEATS), net.Net_Event(game.Event))
	defer r.audit_capture_destroy(&capture)
	result := d.recording_verify(&archive, identity, net.recording_model(&model), &capture)
	if result.error != .None {
		text := d.audit_text(result.replay, &capture)
		defer delete(text)
		fmt.eprintf("Recording verification failed: %v\n%s", result.error, text)
		return 1
	}
	gameplay, verdicts, applied, rejected, joins, historical: u64
	for event in archive.events {
		if event.value.kind == .Gameplay {
			gameplay += 1
		} else {
			verdicts += 1
			if event.value.applied {
				applied += 1
			} else {
				rejected += 1
			}
		}
	}
	for tick in archive.ticks {
		if tick.input.joins != 0 {
			joins += 1
		}
		for view in tick.input.views {
			if view.status == .Historical {
				historical += 1
			}
		}
	}
	frame := archive.base
	if len(archive.ticks) > 0 {
		frame = archive.ticks[len(archive.ticks) - 1].frame
	}
	shots, casts: u64
	for player in frame.state.players {
		shots += u64(player.shots)
		casts += u64(player.casts)
	}
	fmt.printf(
		"REPLAY_SCRAP_RECORDING_OK first=%d head=%d steps=%d gameplay=%d verdicts=%d applied=%d rejected=%d joins=%d historical=%d epoch=%d bytes=%d shots=%d casts=%d mobs=%d\n",
		archive.base.tick,
		archive.header.head,
		len(archive.ticks),
		gameplay,
		verdicts,
		applied,
		rejected,
		joins,
		historical,
		archive.epoch,
		len(bytes),
		shots,
		casts,
		frame.state.mobs.count,
	)
	return 0
}

read_file :: proc(path: string) -> ([]u8, bool) {
	file, error := os.open(path)
	if error != nil {
		return nil, false
	}
	defer os.close(file)
	size, size_error := os.file_size(file)
	if size_error != nil || size < 1 || size > d.MAX_RECORDING_BYTES {
		return nil, false
	}
	bytes := make([]u8, int(size))
	success := false
	defer if !success {
		delete(bytes)
	}
	at := 0
	for at < len(bytes) {
		n, read := os.read(file, bytes[at:])
		at += n
		if n == 0 || read != nil && read != .EOF {
			return nil, false
		}
	}
	extra: [1]u8
	n, tail := os.read(file, extra[:])
	if n != 0 || tail != nil && tail != .EOF {
		return nil, false
	}
	success = true
	return bytes, true
}

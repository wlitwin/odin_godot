package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strconv"
import sc "godot:replay/schema"
import net "godot:replay/net"
import assets "godot:replay/assets"
import game "../../shared/game"

Checkpoint :: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)

Metadata :: struct {
	path, tick, epoch, content: string,
	hz: u32,
}

Field_Difference :: struct {
	path, kind, expected, actual, expected_bits, actual_bits: string,
	expected_present, actual_present: bool,
}

Report :: struct {
	format: u16,
	projection, schema: string,
	left, right: Metadata,
	equal, truncated: bool,
	total: int,
	fields: []Field_Difference,
}

main :: proc() {
	os.exit(run())
}

run :: proc() -> int {
	if len(os.args) < 3 {
		fmt.eprintln("Usage: inspect_run LEFT RIGHT [--limit N] [--public] [--allow-different-ticks]")
		return 2
	}
	limit := 32
	public, allow_ticks: bool
	for i := 3; i < len(os.args); i += 1 {
		switch os.args[i] {
		case "--public":
			public = true
		case "--allow-different-ticks":
			allow_ticks = true
		case "--limit":
			i += 1
			if i == len(os.args) {
				fmt.eprintln("INSPECT_ERROR missing limit")
				return 2
			}
			value, ok := strconv.parse_int(os.args[i])
			if !ok || value < 1 || value > 256 {
				fmt.eprintln("INSPECT_ERROR limit must be 1..256")
				return 2
			}
			limit = value
		case:
			fmt.eprintln("INSPECT_ERROR unknown option")
			return 2
		}
	}
	left, right: Checkpoint
	defer net.checkpoint_destroy(&left)
	defer net.checkpoint_destroy(&right)
	if !load_checkpoint(os.args[1], &left) || !load_checkpoint(os.args[2], &right) {
		return 2
	}
	if !allow_ticks && left.frame.tick != right.frame.tick {
		fmt.eprintf(
			"INSPECT_ERROR different ticks (%d and %d); use --allow-different-ticks for an intentional save comparison\n",
			left.frame.tick,
			right.frame.tick,
		)
		return 2
	}
	if left.settings.hz != right.settings.hz {
		fmt.eprintln("INSPECT_ERROR incompatible tick rates")
		return 2
	}
	codec: sc.Schema
	defer sc.destroy(&codec)
	options := sc.DEFAULT_OPTIONS
	if public {
		options.projection = .Public
	}
	if sc.init(&codec, game.World, options).error != .None {
		fmt.eprintln("INSPECT_ERROR schema")
		return 2
	}
	differences := make([]sc.Difference, limit)
	defer delete(differences)
	result := sc.diff(&codec, left.frame.state, right.frame.state, differences)
	if result.report.error != .None {
		fmt.eprintf("INSPECT_ERROR %v %s\n", result.report.error, result.report.path)
		return 2
	}
	fields := make([]Field_Difference, result.count)
	defer delete(fields)
	for difference, i in differences[:result.count] {
		fields[i] = {
			path = difference.path,
			kind = fmt.tprintf("%v", difference.kind),
			expected = sc.diff_value(&codec, difference, .Left, context.temp_allocator),
			actual = sc.diff_value(&codec, difference, .Right, context.temp_allocator),
			expected_bits = fmt.tprintf("0x%x", difference.left),
			actual_bits = fmt.tprintf("0x%x", difference.right),
			expected_present = difference.left_present,
			actual_present = difference.right_present,
		}
	}
	report := Report {
		format = 1,
		projection = public ? "public" : "authority",
		schema = fmt.tprintf("0x%x", codec.fingerprint),
		left = metadata(os.args[1], &left),
		right = metadata(os.args[2], &right),
		equal = result.total == 0,
		truncated = result.count < result.total,
		total = result.total,
		fields = fields,
	}
	bytes, err := json.marshal(report)
	defer delete(bytes)
	if err != nil {
		fmt.eprintln("INSPECT_ERROR JSON encoding")
		return 2
	}
	fmt.println(string(bytes))
	return result.total == 0 ? 0 : 1
}

metadata :: proc(path: string, cp: ^Checkpoint) -> Metadata {
	return {
		path,
		fmt.tprintf("%d", cp.frame.tick),
		fmt.tprintf("%d", cp.header.epoch),
		fmt.tprintf("0x%x", cp.header.content),
		cp.settings.hz,
	}
}

// Bounded read: check size before allocation and detect truncation/growth.
read_file :: proc(path: string) -> ([]u8, bool) {
	file, err := os.open(path)
	if err != nil {
		return nil, false
	}
	defer os.close(file)
	size, sized := os.file_size(file)
	if sized != nil || size < 1 || size > assets.BUNDLE_LIMIT {
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
	n, read := os.read(file, extra[:])
	if n != 0 || read != nil && read != .EOF {
		return nil, false
	}
	success = true
	return bytes, true
}

load_checkpoint :: proc(path: string, cp: ^Checkpoint) -> bool {
	bytes, ok := read_file(path)
	defer delete(bytes)
	if !ok {
		fmt.eprintf("INSPECT_ERROR cannot read bounded archive: %s\n", path)
		return false
	}
	view: assets.Bundle_View
	meta, _, inspected := sc.inspect(bytes)
	if inspected.error == .None && meta.kind == net.CHECKPOINT_KIND {
		view.meta, view.root = meta, bytes
	} else {
		bundle, err := assets.bundle_decode(bytes, game.CONTENT)
		if err != .None {
			fmt.eprintf("INSPECT_ERROR bundle=%v: %s\n", err, path)
			return false
		}
		view = bundle
	}
	if err := net.checkpoint_decode(cp, view.root, game.model(), game.CONTENT); err != .None {
		fmt.eprintf("INSPECT_ERROR checkpoint=%v: %s\n", err, path)
		return false
	}
	if cp.header.epoch != view.meta.epoch ||
	   cp.header.tick != view.meta.tick ||
	   cp.header.content != view.meta.content {
		fmt.eprintln("INSPECT_ERROR container metadata mismatch")
		return false
	}
	for player in cp.frame.state.players {
		if !assets.bundle_has(&view, player.spray.image) {
			fmt.eprintln("INSPECT_ERROR missing asset")
			return false
		}
	}
	return true
}

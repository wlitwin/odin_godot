package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import upgrade "../../shared/upgrade"

main :: proc() {
	if !run() {
		os.exit(1)
	}
}

run :: proc() -> bool {
	if len(os.args) != 3 {
		fmt.eprintln("Usage: upgrade_recording SOURCE NEW_DESTINATION")
		return false
	}
	bytes, ok := read_bounded(os.args[1], d.MAX_RECORDING_BYTES)
	defer delete(bytes)
	if !ok {
		return false
	}
	model := upgrade.model_48()
	converted, error := net.recording_upgrade_without_authority(bytes, &model, upgrade.RECORDING_48)
	defer delete(converted)
	if error != .None {
		fmt.eprintf("UPGRADE_ERROR recording=%v\n", error)
		return false
	}
	if !publish_new(os.args[2], converted) {
		return false
	}
	fmt.printf("REPLAY_SCRAP_RECORDING_UPGRADE_OK content=48 bytes=%d->%d\n", len(bytes), len(converted))
	return true
}

read_bounded :: proc(path: string, limit: int) -> ([]u8, bool) {
	file, opened := os.open(path)
	if opened != nil {
		fmt.eprintf("UPGRADE_ERROR read=%v\n", opened)
		return nil, false
	}
	defer os.close(file)
	size, sized := os.file_size(file)
	if sized != nil || size < 1 || size > i64(limit) {
		fmt.eprintln("UPGRADE_ERROR file size outside bounds")
		return nil, false
	}
	bytes := make([]u8, int(size))
	success := false
	defer if !success {
		delete(bytes)
	}
	at := 0
	for at < len(bytes) {
		n, err := os.read(file, bytes[at:])
		at += n
		if (err != nil && err != .EOF) || n == 0 {
			fmt.eprintln("UPGRADE_ERROR short or failed read")
			return nil, false
		}
	}
	extra: [1]u8
	n, err := os.read(file, extra[:])
	if n != 0 || (err != nil && err != .EOF) {
		fmt.eprintln("UPGRADE_ERROR file changed during read")
		return nil, false
	}
	success = true
	return bytes, true
}

publish_new :: proc(destination: string, bytes: []u8) -> bool {
	dir := filepath.dir(destination)
	defer delete(dir)
	file, created := os.create_temp_file(dir, ".replay-upgrade-*")
	if created != nil {
		fmt.eprintf("UPGRADE_ERROR stage=%v\n", created)
		return false
	}
	name := strings.clone(os.name(file))
	defer delete(name)
	defer os.remove(name)
	closed := false
	defer if !closed {
		os.close(file)
	}
	at := 0
	for at < len(bytes) {
		n, err := os.write(file, bytes[at:])
		at += n
		if err != nil || n == 0 {
			fmt.eprintf("UPGRADE_ERROR write=%v\n", err)
			return false
		}
	}
	if err := os.sync(file); err != nil {
		fmt.eprintf("UPGRADE_ERROR sync=%v\n", err)
		return false
	}
	err := os.close(file)
	closed = true
	if err != nil {
		fmt.eprintf("UPGRADE_ERROR close=%v\n", err)
		return false
	}
	// Linking a complete file publishes without replacing an existing file or
	// symlink. The stage is in the same directory; unsupported filesystems fail.
	if err := os.link(name, destination); err != nil {
		fmt.eprintf("UPGRADE_ERROR publish=%v (destination must be new; filesystem must support hard links)\n", err)
		return false
	}
	return true
}

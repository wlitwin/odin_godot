package main

import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"

main :: proc() {
	assert(len(os.args) == 3)
	mode, path := os.args[1], os.args[2]
	store: db.Store; defer db.close(&store)
	assert(db.open(&store, path, mode == "create") == .None)
	switch mode {
	case "create":
		record := auth.record_make(71, 72, {1, 1})
		address, _ := auth.endpoint("127.0.0.1", 45100)
		record.members[0] = {identity = {1, 1}, endpoint = address, enabled = true, can_host = true, trusted_authority = true}
		coordinator: auth.Coordinator
		assert(auth.coordinator_init(&coordinator, record, db.commit, &store, 0) == .None)
		assert(auth.coordinator_start(&coordinator, {1, 1}, 1, 0) == .None)
		assert(auth.coordinator_renew(&coordinator, {1, 1}, 1, 2, 37, 100) == .None)
		next := coordinator.record
		next.revision += 1
		next.requests[0] = {sequence = 17, hash = {0 = 33}}
		assert(db.commit(&store, coordinator.record.revision, next))
		fmt.println("REPLAY_SQLITE_COMMITTED")
	case "uncommitted":
		assert(db.sqlite3_exec(store.db, "BEGIN IMMEDIATE; UPDATE replay_authority SET value=zeroblob(12);", nil, nil, nil) == 0)
		fmt.println("REPLAY_SQLITE_UNCOMMITTED")
		for {time.sleep(100 * time.Millisecond)} // killed by the harness, no clean shutdown
	case "verify":
		record, found, err := db.load(&store, 71, 72)
		assert(found && err == .None && record.epoch == 1 && record.last_tick == 37)
		assert(record.requests[0].sequence == 17 && record.requests[0].hash[0] == 33)
		fmt.println("REPLAY_SQLITE_CRASH_OK")
	case: assert(false)
	}
}

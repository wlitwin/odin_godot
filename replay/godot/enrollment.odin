package replay_godot

import "core:crypto"
import "core:strings"
import gd "godot:godot"
import p "godot:replay/provision"

// Native storage is supplied explicitly so using Replay/Godot does not impose a
// SQLite dependency. The optional godot/provision_sqlite package provides it.
Enrollment_Backing :: struct {
	user: rawptr,
	load: proc(user: rawptr) -> (p.Enrollment_Record, bool, p.Enrollment_Error),
	commit: proc(user: rawptr, expected: u64, next: p.Enrollment_Record) -> (u64, p.Enrollment_Error),
}
Enrollment_Profile :: struct {
	value: p.Enrollment_Journal,
	backing: Enrollment_Backing,
	op: Browser_Store_Op,
	namespace, key: string,
}

enrollment_profile_open :: proc(e: ^Enrollment_Profile, service: string, content: u64, namespace, key: string,
                               backing: Enrollment_Backing = {}, local_development: bool = false) -> bool {
	if e.value.phase != .Closed || !browser_store_key(namespace) || !browser_store_key(key) ||
	   !p.enrollment_open(&e.value, service, content, local_development) {return false}
	e.namespace, e.key, e.backing = strings.clone(namespace), strings.clone(key), backing
	when gd.IS_WEB {
		if !browser_store_read(&e.op, namespace, key, p.ENROLLMENT_BYTES) {
			p.enrollment_loaded(&e.value, {}, false, 0, .Store); return false
		}
	} else {
		if backing.load == nil || backing.commit == nil {p.enrollment_loaded(&e.value, {}, false, 0, .Store); return false}
		record, found, error := backing.load(backing.user)
		defer crypto.zero_explicit(&record, size_of(record))
		return p.enrollment_loaded(&e.value, record, found, found ? record.revision : 0, error)
	}
	return true
}
enrollment_profile_begin :: proc(e: ^Enrollment_Profile, request: p.Request) -> bool {return p.enrollment_begin(&e.value, request)}
enrollment_profile_frame :: proc(e: ^Enrollment_Profile) {
	when gd.IS_WEB {
		if e.value.phase == .Loading {
			if browser_store_poll(&e.op) != .Complete {return}
			defer browser_store_close(&e.op)
			if e.op.error == .Missing {p.enrollment_loaded(&e.value, {}, false, 0); return}
			if e.op.error != .None {p.enrollment_loaded(&e.value, {}, false, 0, enrollment_browser_error(e.op.error)); return}
			bytes, err := browser_store_bytes(&e.op)
			defer {if len(bytes) > 0 {crypto.zero_explicit(raw_data(bytes), len(bytes))}; delete(bytes)}
			if err != .None {p.enrollment_loaded(&e.value, {}, false, 0, .Store); return}
			record, ok := p.enrollment_decode(&e.value.codec, bytes, e.value.content, e.value.local_development)
			defer crypto.zero_explicit(&record, size_of(record))
			p.enrollment_loaded(&e.value, record, ok, e.op.revision, ok ? .None : .Corrupt)
			return
		}
	}
	bytes, expected, writing := p.enrollment_write(&e.value)
	if !writing {return}
	when gd.IS_WEB {
		if e.op.phase == .Idle {
			if !browser_store_write(&e.op, e.namespace, e.key, bytes, expected, p.ENROLLMENT_BYTES) {
				p.enrollment_receipt(&e.value, 0, enrollment_browser_error(e.op.error)); browser_store_close(&e.op)
			}
			return
		}
		if browser_store_poll(&e.op) == .Complete {
			p.enrollment_receipt(&e.value, e.op.revision, enrollment_browser_error(e.op.error)); browser_store_close(&e.op)
		}
	} else {
		revision, error := e.backing.commit(e.backing.user, expected, e.value.candidate)
		p.enrollment_receipt(&e.value, revision, error)
	}
}
enrollment_profile_close :: proc(e: ^Enrollment_Profile) {
	browser_store_close(&e.op); p.enrollment_close(&e.value); delete(e.namespace); delete(e.key); e^ = {}
}

// The only outbound enrollment request comes from the durable Pending state.
// Returned credentials remain unavailable while their CAS write is outstanding.
provision_enrollment_frame :: proc(c: ^Provision_Connection, e: ^Enrollment_Profile) -> p.Error {
	enrollment_profile_frame(e)
	if e.value.phase != .Pending {return .None}
	url, ok := p.service_url(c.url, true)
	if !c.ready || !ok || url != e.value.service {return .Invalid}
	request, allowed := p.enrollment_request(&e.value)
	if !allowed {return .Invalid}
	if (c.client.pending || c.client.complete) && c.client.request != request {return .Invalid}
	if !c.client.pending && !c.client.complete {
		if err := provision_request(c, request); err != .None {return err}
	}
	if err := provision_frame(c); err != .None {return err}
	if c.client.complete {
		reply := c.client.reply; c.client.complete = false
		if !p.enrollment_accept(&e.value, reply) {return reply.result != .None ? reply.result : .Invalid}
		enrollment_profile_frame(e)
	}
	return .None
}

@(private)
enrollment_browser_error :: proc(error: Browser_Store_Error) -> p.Enrollment_Error {
	if error == .None {return .None}
	if error == .Conflict {return .Conflict}
	if error == .Corrupt || error == .Size {return .Corrupt}
	return .Store
}

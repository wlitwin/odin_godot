package replay_godot_storage

import "core:fmt"
import gd "godot:godot"

// A seat is a durable storage-key suffix, exclusively held for a Party lifetime.
// The tab hint contains no credentials. Copied hints cannot copy a live seat.
Browser_Seat :: struct {
    phase: Browser_Store_Phase,
    failed: bool,
    id: i64,
    seat: int,
}

browser_seat_open :: proc(o: ^Browser_Seat, namespace, scope: string) -> bool {
    if o.phase != .Idle || !browser_store_key_valid(namespace) || !browser_store_key_valid(scope) {
        return false
    }
    o.phase, o.failed = .Complete, true
    when gd.IS_WEB {
        script := gd.new_string_odin(BROWSER_SEAT_JS)
        defer gd.free_string(script)
        installed := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), script, true)
        defer gd.variant_destroy(&installed)
        if gd.variant_to_int(&installed) != 1 {return false}
        // Both strings have been validated against the storage-key alphabet.
        value := browser_seat_eval(fmt.tprintf("ReplayBrowserSeatsV1.open('%s/%s')", namespace, scope))
        if value <= 0 {return false}
        o.id, o.phase, o.failed = value, .Pending, false
        return true
    }
    return false
}

browser_seat_poll :: proc(o: ^Browser_Seat) -> Browser_Store_Phase {
    when gd.IS_WEB {
        if o.phase == .Pending {
            // -2 pending, -1 failed, otherwise the exclusively held seat.
            seat := browser_seat_eval(fmt.tprintf("ReplayBrowserSeatsV1.poll(%d)", o.id))
            if seat == -2 {return .Pending}
            o.phase, o.failed = .Complete, seat < 0 || seat >= 32
            if !o.failed {o.seat = int(seat)}
        }
    }
    return o.phase
}

browser_seat_close :: proc(o: ^Browser_Seat) {
    when gd.IS_WEB {
        if o.id > 0 {browser_seat_eval(fmt.tprintf("ReplayBrowserSeatsV1.close(%d)", o.id))}
    }
    o^ = {}
}

@(private)
browser_seat_eval :: proc(code: string) -> i64 {
    script := gd.new_string_odin(code)
    defer gd.free_string(script)
    value := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), script, true)
    defer gd.variant_destroy(&value)
    return gd.variant_to_int(&value)
}

@(private)
BROWSER_SEAT_JS :: `(() => {
 if (globalThis.ReplayBrowserSeatsV1) return 1;
 if (!globalThis.navigator?.locks?.request) return 0;
 const jobs = new Map(); let next = 0;
 const valid = key => typeof key === 'string' && /^[A-Za-z0-9_.\/-]{1,257}$/.test(key);
 async function reserve(job, seat) {
  return new Promise((resolve, reject) => {
   navigator.locks.request(job.key + '/' + seat, {ifAvailable:true}, lock => {
    if (!lock || !jobs.has(job.id)) {resolve(false); return;}
    return new Promise(release => {
     job.release = release;
     try {
      sessionStorage.setItem(job.key, String(seat));
      job.seat = seat; resolve(true);
     } catch (error) {release(); reject(error);}
    });
   }).catch(reject);
  });
 }
 globalThis.ReplayBrowserSeatsV1 = {
  open(scope) {
   if (!valid(scope) || jobs.size >= 16 || next >= Number.MAX_SAFE_INTEGER) return 0;
   const job = {id:++next, key:'replay-party-seat-v1/' + scope, seat:-2, release:null};
   jobs.set(job.id, job);
   (async () => {
    const hint = sessionStorage.getItem(job.key);
    const preferred = /^(0|[1-9][0-9]?)$/.test(hint ?? '') && Number(hint) < 32 ? Number(hint) : 0;
    if (await reserve(job, preferred)) return;
    for (let seat=0; seat<32 && jobs.has(job.id); seat++) {
     if (seat !== preferred && await reserve(job, seat)) return;
    }
    job.seat = -1;
   })().catch(() => {job.seat = -1; if (job.release) job.release();});
   return job.id;
  },
  poll(id) {return jobs.get(id)?.seat ?? -1;},
  close(id) {
   const job = jobs.get(id); if (!job) return 0;
   jobs.delete(id); if (job.release) job.release(); return 1;
  }
 };
 return 1;
})()`

package replay_authority

// A conservative elapsed clock for embeddings without a suspend-inclusive steady
// clock. Both inputs must be milliseconds and individually nondecreasing. Wall
// time covers a suspended monotonic clock; the monotonic source covers backward
// rate corrections. A backward sample poisons the clock instead of reviving leases.
// This assumes the wall source does not conceal suspension by moving backward
// between samples; it is not a defense against a malicious authority process.
// Taking the larger incremental delta can expire early under coarse timer
// quantization. It cannot freeze after a forward wall-clock offset.
Paired_Clock :: struct {ready,poisoned:bool,origin_wall,origin_monotonic,last_wall,last_monotonic,now:u64}
paired_clock_sample :: proc(c:^Paired_Clock,wall,monotonic:u64)->(u64,bool) {
 if c.poisoned {return c.now,false}
 if !c.ready {c^={ready=true,origin_wall=wall,origin_monotonic=monotonic,last_wall=wall,last_monotonic=monotonic};return 0,true}
 if wall<c.last_wall || monotonic<c.last_monotonic {c.poisoned=true;return c.now,false}
 elapsed:=max(wall-c.last_wall,monotonic-c.last_monotonic)
 if elapsed>max(u64)-c.now {c.poisoned=true;return c.now,false}
 c.last_wall,c.last_monotonic=wall,monotonic
 c.now+=elapsed
 return c.now,true
}

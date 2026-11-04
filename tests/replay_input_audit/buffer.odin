package replay_net
import "core:fmt"

Input_Audit_Kind :: enum u8 {
    Request,
    Frame,
    Sample,
    Capture,
    Sent,
    Received,
    Accepted,
    Model,
    Executed,
    Queued,
    Action_Sent,
    Arrival,
    Admitted,
    Settled,
    Result,
    Shot_Born,
    Shot_End,
}

Input_Audit_Record :: struct {
    kind:               Input_Audit_Kind,
    seat:               u16,
    tick, now, a, b, c: u64,
}

input_audit_records: [16384]Input_Audit_Record
input_audit_count, input_audit_dropped: int

input_audit_note :: proc(kind: Input_Audit_Kind, seat: u16, tick, now: u64, a: u64 = 0, b: u64 = 0, c: u64 = 0) {
    if input_audit_count == len(input_audit_records) {
        input_audit_dropped += 1
        return
    }

    input_audit_records[input_audit_count] = {kind, seat, tick, now, a, b, c}
    input_audit_count += 1
}

input_audit_dump :: proc() {
    fmt.printf("INPUT_AUDIT_COUNT count=%d dropped=%d\n", input_audit_count, input_audit_dropped)

    for e in input_audit_records[:input_audit_count] {
        switch e.kind {
        case .Request:
            fmt.printf("INPUT_REQUEST now=%d\n", e.now)
        case .Frame:
            fmt.printf("INPUT_FRAME before=%d after=%d pending=%t now=%d\n", e.tick, e.a, e.b != 0, e.now)
        case .Sample:
            fmt.printf(
                "INPUT_SAMPLE seat=%d tick=%d now=%d phase=%v depth=%d limit=%d\n",
                e.seat,
                e.tick,
                e.now,
                Phase(e.a),
                e.b,
                e.c,
            )
        case .Capture:
            fmt.printf("INPUT_CAPTURE seat=%d tick=%d now=%d\n", e.seat, e.tick, e.now)
        case .Sent:
            fmt.printf("INPUT_SENT seat=%d tick=%d now=%d\n", e.seat, e.tick, e.now)
        case .Received:
            fmt.printf(
                "INPUT_RECEIVED seat=%d tick=%d now=%d head=%d future_limit=%d\n",
                e.seat,
                e.tick,
                e.now,
                e.a,
                e.b,
            )
        case .Accepted:
            fmt.printf("INPUT_ACCEPTED seat=%d tick=%d now=%d head=%d\n", e.seat, e.tick, e.now, e.a)
        case .Model:
            fmt.printf("INPUT_MODEL seat=%d tick=%d ready=%d dashes=%d\n", e.seat, e.tick, e.a, e.b)
        case .Executed:
            fmt.printf("INPUT_EXECUTED seat=%d tick=%d dashes=%d\n", e.seat, e.tick, e.a)
        case .Queued:
            fmt.printf("INPUT_QUEUED sequence=%d now=%d\n", e.a, e.now)
        case .Action_Sent:
            fmt.printf("INPUT_ACTION_SENT seat=%d tick=%d sequence=%d now=%d\n", e.seat, e.tick, e.a, e.now)
        case .Arrival:
            fmt.printf("INPUT_ARRIVAL seat=%d tick=%d sequence=%d head=%d now=%d\n", e.seat, e.tick, e.a, e.b, e.now)
        case .Admitted:
            fmt.printf(
                "INPUT_ADMITTED seat=%d tick=%d sequence=%d proposed=%d reason=%d now=%d\n",
                e.seat,
                e.tick,
                e.a,
                e.b,
                e.c,
                e.now,
            )
        case .Settled:
            fmt.printf(
                "INPUT_SETTLED seat=%d tick=%d sequence=%d applied=%d reason=%d now=%d\n",
                e.seat,
                e.tick,
                e.a,
                e.b,
                e.c,
                e.now,
            )
        case .Result:
            fmt.printf("INPUT_RESULT sequence=%d applied=%d reason=%d now=%d\n", e.a, e.b, e.c, e.now)
        case .Shot_Born:
            fmt.printf("INPUT_SHOT_BORN seat=%d tick=%d shot=%d damage=%d family=%d\n", e.seat, e.tick, e.a, e.b, e.c)
        case .Shot_End:
            fmt.printf(
                "INPUT_SHOT_END seat=%d tick=%d shot=%d reason=%d hp_before=%d hp_after=%d\n",
                e.seat,
                e.tick,
                e.a,
                e.b,
                e.c >> 32,
                e.c & 0xffffffff,
            )
        }
    }
}

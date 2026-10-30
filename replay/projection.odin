package replay

// Project a retained frame to a small owned value. The callback receives State
// by value, so it cannot mutate history through a borrowed pointer. Compilers may
// eliminate unused aggregate copies; this API does not promise zero copying.
// Reentry into timeline mutation is refused while the callback executes.
project :: proc(t:^Timeline($State,$Input,$Event),tick:u64,projector:proc(State)->$Value)->(Value,Error) {
    if err:=available(t);err!=.None {return {},err}
    if projector==nil {return {},.Invalid_Config}
    if !value_supported(Value) {return {},.Unsupported_Value}
    record:=record_at(t,tick);if record==nil {return {},.History_Missing}
    t.busy=true;defer t.busy=false
    return projector(record.frame.state),.None
}

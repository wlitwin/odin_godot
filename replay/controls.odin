package replay

// Device state stays outside World. Any gate suppresses controls and discards
// buffered edges. Buttons held across a transition must be released before reuse.
Input_Block :: enum {Paused,Unfocused,Menu,Inspecting}
Input_Gates :: bit_set[Input_Block]
Control_Capture :: struct {buttons:Buttons,suppressed:u64,blocked:bool}
controls_capture :: proc(c:^Control_Capture,held,pressed,released:u64,gates:Input_Gates={}) {
    if gates!={} {
        c.buttons={};c.suppressed|=held|pressed;c.blocked=true;return
    }
    if c.blocked {c.suppressed|=held|pressed;c.blocked=false}
    mask:=~c.suppressed
    c.suppressed&=held|pressed
    buttons_set(&c.buttons,held&mask)
    c.buttons.pressed|=pressed&mask;c.buttons.released|=released&mask
}
controls_consume :: proc(c:^Control_Capture) {buttons_consume(&c.buttons)}
// Use at an explicit local lifecycle boundary; same-epoch pause/menu transitions
// should use gates so a held button cannot become a fresh press.
controls_reset :: proc(c:^Control_Capture) {c^={}}

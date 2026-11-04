package scrapyard_audio

Sfx :: enum u8 {
    Bolter,
    Riveter,
    Jam,
    Unjam,
    Reload,
    Hit,
    Kill,
    Explode,
    Ouch,
    Downed,
    Slime,
    Ignite,
    Spit,
    Pop,
    Slam,
    Dash,
    Pickup,
    Revive,
    Clear,
    Descend,
    Wipe,
    Buy,
    Ping,
}

file_name :: proc(cue: Sfx) -> cstring {
    rows := [Sfx]cstring {
        .Bolter = "bolter",
        .Riveter = "riveter",
        .Jam = "jam",
        .Unjam = "unjam",
        .Reload = "reload",
        .Hit = "hit",
        .Kill = "kill",
        .Explode = "explode",
        .Ouch = "ouch",
        .Downed = "downed",
        .Slime = "slime",
        .Ignite = "ignite",
        .Spit = "spit",
        .Pop = "pop",
        .Slam = "slam",
        .Dash = "dash",
        .Pickup = "pickup",
        .Revive = "revive",
        .Clear = "clear",
        .Descend = "descend",
        .Wipe = "wipe",
        .Buy = "buy",
        .Ping = "ping",
    }
    return rows[cue]
}

// Base loudness (dB) — the frequent sounds sit low, the dramatic beats high.
gain :: proc(cue: Sfx) -> f32 {
    rows := [Sfx]f32 {
        .Bolter = -5,
        .Riveter = -9,
        .Jam = -3,
        .Unjam = -4,
        .Reload = -7,
        .Hit = -11,
        .Kill = -5,
        .Explode = -3,
        .Ouch = -4,
        .Downed = 0,
        .Slime = -5,
        .Ignite = -7,
        .Spit = -6, // audible warning — the glob is a dodge prompt
        .Pop = -3,
        .Slam = 0,
        .Dash = -6,
        .Pickup = -9,
        .Revive = -3,
        .Clear = -4,
        .Descend = -4,
        .Wipe = 0,
        .Buy = -7,
        .Ping = -4, // it exists to be heard
    }
    return rows[cue]
}

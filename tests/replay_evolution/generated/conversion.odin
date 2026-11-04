package scrapyard_revision_fixture
import e "godot:replay/evolution"

convert :: proc(old: Catalog_49) -> (Catalog_50, bool) {
    // TODO: choose and review every new default below.
    defaults_reviewed := false

    if !defaults_reviewed {
        return {}, false
    }

    defaults: Catalog_50
    added := []string {
        "$.mobs[0].pulse.windup", // TODO: defaults.mobs[0].pulse.windup
        "$.mobs[0].pulse.cooldown", // TODO: defaults.mobs[0].pulse.cooldown
        "$.mobs[0].pulse.radius", // TODO: defaults.mobs[0].pulse.radius
        "$.mobs[0].pulse.damage", // TODO: defaults.mobs[0].pulse.damage
        "$.mobs[1].pulse.windup", // TODO: defaults.mobs[1].pulse.windup
        "$.mobs[1].pulse.cooldown", // TODO: defaults.mobs[1].pulse.cooldown
        "$.mobs[1].pulse.radius", // TODO: defaults.mobs[1].pulse.radius
        "$.mobs[1].pulse.damage", // TODO: defaults.mobs[1].pulse.damage
        "$.mobs[2].pulse.windup", // TODO: defaults.mobs[2].pulse.windup
        "$.mobs[2].pulse.cooldown", // TODO: defaults.mobs[2].pulse.cooldown
        "$.mobs[2].pulse.radius", // TODO: defaults.mobs[2].pulse.radius
        "$.mobs[2].pulse.damage", // TODO: defaults.mobs[2].pulse.damage
        "$.mobs[3].pulse.windup", // TODO: defaults.mobs[3].pulse.windup
        "$.mobs[3].pulse.cooldown", // TODO: defaults.mobs[3].pulse.cooldown
        "$.mobs[3].pulse.radius", // TODO: defaults.mobs[3].pulse.radius
        "$.mobs[3].pulse.damage", // TODO: defaults.mobs[3].pulse.damage
        "$.mobs[4].pulse.windup", // TODO: defaults.mobs[4].pulse.windup
        "$.mobs[4].pulse.cooldown", // TODO: defaults.mobs[4].pulse.cooldown
        "$.mobs[4].pulse.radius", // TODO: defaults.mobs[4].pulse.radius
        "$.mobs[4].pulse.damage", // TODO: defaults.mobs[4].pulse.damage
        "$.mobs[5].pulse.windup", // TODO: defaults.mobs[5].pulse.windup
        "$.mobs[5].pulse.cooldown", // TODO: defaults.mobs[5].pulse.cooldown
        "$.mobs[5].pulse.radius", // TODO: defaults.mobs[5].pulse.radius
        "$.mobs[5].pulse.damage", // TODO: defaults.mobs[5].pulse.damage
        "$.mobs[6].pulse.windup", // TODO: defaults.mobs[6].pulse.windup
        "$.mobs[6].pulse.cooldown", // TODO: defaults.mobs[6].pulse.cooldown
        "$.mobs[6].pulse.radius", // TODO: defaults.mobs[6].pulse.radius
        "$.mobs[6].pulse.damage", // TODO: defaults.mobs[6].pulse.damage
        "$.mobs[7].pulse.windup", // TODO: defaults.mobs[7].pulse.windup
        "$.mobs[7].pulse.cooldown", // TODO: defaults.mobs[7].pulse.cooldown
        "$.mobs[7].pulse.radius", // TODO: defaults.mobs[7].pulse.radius
        "$.mobs[7].pulse.damage", // TODO: defaults.mobs[7].pulse.damage
    }
    value, report := e.copy_preserved(old, defaults, added)
    return value, report.error == .None
}

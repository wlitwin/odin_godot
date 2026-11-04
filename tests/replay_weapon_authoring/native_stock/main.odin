package main
import "core:fmt"
import c "subject:shared/content"

main :: proc() {
    expected :: #config(EXPECTED_GUNS, 8)
    catalog := c.stock()
    assert(c.valid(catalog))
    assert(int(catalog.gun_count) == expected)
    assert(catalog.mobs[1].hp == 20 && catalog.mobs[1].speed == 0 && catalog.mobs[1].bite == 0)

    if expected == 8 {
        gun := catalog.guns[7]
        assert(c.name_string(&gun.name) == "stapler" && gun.damage == 3 && gun.cooldown == 12)
        assert(gun.mechanism.mag == 3 && gun.mechanism.reload_ticks == 60 && gun.mechanism.jam_per_mille == 0)
        assert(gun.speed == 12 && gun.ttl == 30 && gun.region == ([4]u16{0, 48, 32, 16}))
        assert(c.next_gun(&catalog, 6) == 7)
    } else {
        assert(expected == 7 && !c.gun_present(&catalog, 7) && c.next_gun(&catalog, 6) == 0)
    }

    fmt.printf("REPLAY_WEAPON_STOCK_OK guns=%d\n", catalog.gun_count)
}

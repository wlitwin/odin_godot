package replay_room_service

import gd "godot:godot"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import pitch "godot:examples/replay_speedball/shared/pitch"
import slopball "godot:examples/replay_slopball/shared/pitch"
import slopball3d "godot:examples/replay_slopball3d/shared/pitch"
import claimball "godot:examples/replay_claimball/shared/pitch"
import duel "godot:examples/replay_quickdraw/shared/duel"
import scrapyard "godot:examples/replay_scrapyard/shared/game"
import scenegd "godot:replay/godot/scene"

// The operator-selected content ID determines executable validation code.
// Request fields never select a model. Unknown content remains admission-only
// unless the deployment explicitly requires a supported checkpoint model.
checkpoint_open :: proc(self: ^Game, content: u64) -> (string, bool) {
    required := gd.env_string("REPLAY_ROOM_CHECKPOINT_MODEL", "")
    name, valid := checkpoint_model(content, required)

    if !valid || name == "disabled" {
        return name, valid
    }

    backend: ck.Backend

    switch content {
    case cave_owned.CONTENT:
        name = "cavecrawl-owned"
        self.cave_owned_backend = {
            store = &self.store,
            model = cave_owned.model(),
        }
        backend = db.checkpoint_backend(&self.cave_owned_backend)
    case cave.CONTENT:
        name = "cavecrawl"
        self.cave_backend = {
            store = &self.store,
            model = cave.model(),
        }
        backend = db.checkpoint_backend(&self.cave_backend)
    case duel.CONTENT:
        name = "quickdraw"
        self.duel_backend = {
            store = &self.store,
            model = duel.model(),
        }
        backend = db.checkpoint_backend(&self.duel_backend)
    case slopball3d.CONTENT:
        name = "slopball3d"
        self.slopball3d_backend = {
            store = &self.store,
            model = slopball3d.model(),
        }
        backend = db.checkpoint_backend(&self.slopball3d_backend)
    case slopball.CONTENT:
        name = "slopball"
        self.slopball_backend = {
            store = &self.store,
            model = slopball.model(),
        }
        backend = db.checkpoint_backend(&self.slopball_backend)
    case claimball.CONTENT:
        name = "claimball"
        self.claimball_backend = {
            store = &self.store,
            model = claimball.model(),
        }
        backend = db.checkpoint_backend(&self.claimball_backend)
    case pitch.CONTENT:
        name = "speedball"
        self.pitch_backend = {
            store = &self.store,
            model = pitch.model(),
        }
        backend = db.checkpoint_backend(&self.pitch_backend)
    case scrapyard.CONTENT:
        name = "scrapyard"
        self.scrapyard_backend = {
            store = &self.store,
            model = scrapyard.model(),
            assets = {collect = scrapyard.checkpoint_assets, validate = scenegd.asset_png_valid},
        }
        backend = db.checkpoint_backend(&self.scrapyard_backend)
    }

    return name, ck.hub_open(&self.checkpoints, &self.hub, backend) == .None
}

checkpoint_model :: proc(content: u64, required: string) -> (string, bool) {
    if required == "disabled" {
        return "disabled", true
    }

    name := "disabled"

    switch content {
    case slopball3d.CONTENT:
        name = "slopball3d"
    case slopball.CONTENT:
        name = "slopball"
    case claimball.CONTENT:
        name = "claimball"
    case duel.CONTENT:
        name = "quickdraw"
    case cave.CONTENT:
        name = "cavecrawl"
    case cave_owned.CONTENT:
        name = "cavecrawl-owned"
    case pitch.CONTENT:
        name = "speedball"
    case scrapyard.CONTENT:
        name = "scrapyard"
    }

    return name, required == "" || required == name
}

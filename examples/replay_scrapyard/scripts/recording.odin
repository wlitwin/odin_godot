package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import recording "../shared/recording"
import debuggd "godot:replay/godot/debug"

recording_ready :: proc(self: ^ReplayScrapyard) {
    if !self.development {
        return
    }

    parent := gd.get_node(self.owner, "UI/Menu/Scroll/Column")

    if !debuggd.debug_recording_init(&self.recording, parent) {
        return
    }

    save := gd.get_node(self.owner, "UI/Menu/Scroll/Column/Save")
    gd.node_move_child(parent, self.recording.button, gd.Int(gd.node_get_index(save, false) + 1))
    gd.set_string(
        self.recording.button,
        "tooltip_text",
        "Export recent simulation frames, controls, actions and verdicts for offline debugging",
    )
}

recording_frame :: proc(self: ^ReplayScrapyard) {
    if !self.recording.pending {
        return
    }

    if !self.development || !self.session.ready {
        self.recording.pending = false
        return
    }

    started := gd.time_get_ticks_usec(gd.singleton_time())
    path := scrap_param("RSY_RECORDING_PATH", "user://scrapyard.rplrec")

    if self.session.authority {
        debuggd.debug_recording_frame(
            &self.recording,
            &self.session.server.timeline,
            recording.CONTEXT,
            path,
            "scrapyard.rplrec",
        )
    } else {
        debuggd.debug_recording_frame(
            &self.recording,
            &self.session.client.timeline,
            recording.CONTEXT,
            path,
            "scrapyard.rplrec",
        )
    }

    result := self.recording.last
    gd.print_str(
        fmt.tprintf(
            "RSY_RECORDING exports=%d first=%d head=%d bytes=%d error=%v storage=%v authority=%v usec=%d",
            self.recording.exports,
            result.first,
            result.last,
            result.bytes,
            result.error,
            result.storage,
            self.session.authority,
            gd.time_get_ticks_usec(gd.singleton_time()) - started,
        ),
    )
}

package scriptgen

import "core:fmt"
import "core:strings"
import decl "godot:decl"

// Reusable field metadata belongs beside the entity. Behavior tables may also
// be emitted in the owning game's package with an import-qualified entity type
// and a distinct binding prefix, without duplicate Godot registration.
emit_entity_replication :: proc(b: ^strings.Builder, s: ^Script, cls, snake: string) {
    w :: strings.write_string
    // kit/net replication descriptor. The recursive ABI walk already rejected
    // target-sensitive leaves and padding. These #asserts pin its expected
    // size/alignment where the field TYPE is actually known (the consumer compile).
    // `type_of(Cls{}.f)` is unevaluated: no instance is constructed.
    if len(s.replicates) > 0 {
        for r in s.replicates {
            // nearly_simple_compare = memcmp-safe layout INCLUDING floats (plain
            // simple_compare excludes them over NaN semantics — for shadow diffing,
            // bitwise is exactly right). Pointers are memcmp-safe but meaningless on
            // the wire, hence the explicit exclusion.
            te := field_type_expr(cls, r.path)
            fmt.sbprintf(
                b,
                "#assert(intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s), \"%s.%s: gd:\\\"replicate\\\" fields must be POD (ints/floats/bools/enums/vectors/fixed arrays — no strings, slices, maps, or pointers)\")\n",
                te,
                te,
                te,
                cls,
                join_path(r.path),
            )
            fmt.sbprintf(
                b,
                "#assert(size_of(%s) == %d && align_of(%s) == %d, \"%s.%s: target layout differs from NET_SCHEMA_CANONICAL; use fixed-width, padding-free fields\")\n",
                te,
                r.abi_size,
                te,
                r.abi_align,
                cls,
                join_path(r.path),
            )
        }

        fmt.sbprintf(b, "@(private = \"file\")\n_%s_net_fields := [?]knet.Field_Desc {{\n", snake)

        for r in s.replicates {
            flags := ""

            switch {
            case r.interp && r.owner:
                flags = "{.Interp, .Owner_Stream}"
            case r.interp && r.predict:
                flags = "{.Interp, .Predicted}"
            case r.interp:
                flags = "{.Interp}"
            case r.owner:
                flags = "{.Owner_Stream}"
            case r.predict:
                flags = "{.Predicted}"
            case:
                flags = "{}"
            }

            lerp := len(r.lerp) > 0 ? fmt.tprintf(", lerp = %s", r.lerp) : ""

            if len(r.blend) > 0 {
                lerp = fmt.tprintf(", lerp = .Custom, blend = %s", r.blend_code)
            }

            wire := len(r.wire) > 0 ? fmt.tprintf(", wire = %s", r.wire) : ""

            if len(r.codec) > 0 {
                wire = fmt.tprintf(", wire = .Custom, codec = %s", r.codec_code)
            }

            slack := len(r.slack) > 0 ? fmt.tprintf(", slack = %s", r.slack) : ""
            glide := len(r.glide) > 0 ? fmt.tprintf(", glide = %s", r.glide) : ""
            cut := len(r.cut) > 0 ? fmt.tprintf(", cut = %s", r.cut) : ""
            fmt.sbprintf(
                b,
                "\t{{offset = %s, size = size_of(%s), name = %q, flags = %s%s%s%s%s%s}},\n",
                field_offset_expr(cls, r.path),
                field_type_expr(cls, r.path),
                join_path(r.path),
                flags,
                lerp,
                wire,
                slack,
                glide,
                cut,
            )
        }

        w(b, "}\n\n")
        fmt.sbprintf(
            b,
            "// kit/net replication descriptor for %s — consumed by the toolkit session layer.\n%s_net_desc := knet.Entity_Desc{{fields = _%s_net_fields[:], name = %q}}\n\n",
            cls,
            snake,
            snake,
            cls,
        )
    }

}

emit_entity_commands :: proc(b: ^strings.Builder, s: ^Script, cls, snake: string, wrappers: bool = true, descriptor: string = "") {
    descriptor := descriptor != "" ? descriptor : snake
    w :: strings.write_string
    // Immediate commands share one descriptor dispatch path for received,
    // predicted and locally authoritative calls. The typed wrapper selects
    // the Session's bound set; the decode thunk owns consequence dispatch.
    upper := strings.to_upper(snake)
    // A class that TICKS executes its verbs inside the tick pipeline instead
    // (kit/sim command scheduling) — the knet command loop's optimistic-apply
    // and the lane's resim would otherwise fight over one baseline. Its knet
    // command table and ctx-shaped wrappers are skipped whole; the sim block
    // below emits the tick-scheduled equivalents.
    is_sim := s.tick.proc_name != "" || len(s.block_ticks) > 0

    if len(s.commands) > 0 {
        emit_action_metadata(b, s, snake)
    }

    if len(s.commands) > 0 && !is_sim {
        w(b, "// ---- @(gd_command) dispatch + typed issue wrappers ----\n\n")
        w(b, "// Command wire ids — a stable FNV-1a hash of each verb's name, NOT a\n")
        w(b, "// position: reordering (or adding/removing) procs never renumbers the\n")
        w(b, "// wire, and a version-skewed peer's unknown id rejects instead of\n")
        w(b, "// misdispatching. Typed knet.Cmd_Id so a coop id can't be handed to a\n")
        w(b, "// sim verb's proc (it still crosses the wire as a plain u16).\n")

        for c in s.commands {
            fmt.sbprintf(b, "%s_CMD_%s :: knet.Cmd_Id(0x%x)\n", upper, strings.to_upper(c.name), cmd_wire_id(c.name))
            fmt.sbprintf(b, "%s_POLICY_%s :: %s\n", upper, strings.to_upper(c.name), c.policy_expr)
        }

        w(b, "\n")

        for c in s.commands {
            // A composed command routes into the embedded field (`&self.gun`) and qualifies the
            // proc with its package (`play.gun_fire`); a direct one runs `runner_fire(self, …)`.
            recv := len(c.path) > 0 ? fmt.tprintf("&self.%s", join_path(c.path)) : "self"
            qual := c.pkg_alias != "" ? fmt.tprintf("%s.", c.pkg_alias) : ""
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_cmd_%s :: proc(entity: rawptr, r: ^knet.Reader, env: ^knet.Command_Env) -> bool {{\n",
                snake,
                c.name,
            )
            fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)

            for a, i in c.args {
                fmt.sbprintf(b, "\t_a%d := knet.read_%s(r)\n", i, a.wire)
            }

            w(b, "\tif r.err {return false}\n")

            // The verb call — payload returns are captured for the consequence
            // (or blanked when nothing consumes them).
            if c.then_proc == "" && c.payload_count == 0 {
                fmt.sbprintf(b, "\treturn %s%s(%s", qual, command_call_name(c), recv)

                if c.owner {
                    w(b, ", self")
                } // the block asked for its wielder — pass the entity

                if c.wants_by {
                    w(b, ", env.by")
                } // the declared issuer — ctx.me predicting, the sender on the host

                for _, i in c.args {
                    fmt.sbprintf(b, ", _a%d", i)
                }

                w(b, ")\n}\n\n")
                continue
            }

            w(b, "\t_ok")

            for i in 0 ..< c.payload_count {
                if c.then_proc != "" {
                    fmt.sbprintf(b, ", _p%d", i)
                } else {
                    w(b, ", _") // payload declined — the block offered, nobody consumes
                }
            }

            fmt.sbprintf(b, " := %s%s(%s", qual, command_call_name(c), recv)

            if c.owner {
                w(b, ", self")
            }

            if c.wants_by {
                w(b, ", env.by")
            }

            for _, i in c.args {
                fmt.sbprintf(b, ", _a%d", i)
            }

            w(b, ")\n")

            if c.then_proc != "" {
                // The consequence: authority-only, once, after the verb applied —
                // predictions and replays run this same thunk with authority=false.
                w(b, "\tif _ok && env.authority {\n")

                if c.then_game != "" {
                    fmt.sbprintf(
                        b,
                        "\t\tassert(env.user != nil, \"%s needs the game pointer — session_set_factory's user is what consequences receive (tests: set ctx.game_user)\")\n",
                        c.then_proc,
                    )
                    fmt.sbprintf(b, "\t\t%s(cast(^%s)env.user, self, env.by", c.then_proc, c.then_game)
                } else {
                    fmt.sbprintf(b, "\t\t%s(self, env.by", c.then_proc)
                }

                for _, i in c.args {
                    fmt.sbprintf(b, ", _a%d", i)
                }

                for i in 0 ..< c.payload_count {
                    fmt.sbprintf(b, ", _p%d", i)
                }

                w(b, ")\n\t}\n")
            }

            w(b, "\treturn _ok\n}\n\n")
        }

        fmt.sbprintf(b, "@(private = \"file\")\n_%s_commands := [?]knet.Command_Desc {{\n", snake)

        for &c in s.commands {
            w(b, "\t{")
            emit_action_desc(b, s, &c, "Immediate", snake)
            fmt.sbprintf(b, ", invoke = _%s_cmd_%s},\n", snake, c.name)
        }

        w(b, "}\n\n")
    }

    // ---- `<field>_edge` halves: delta-lane change presentation ----
    // One thunk per declared half (cast, deref old, call the author's proc —
    // the new value is the field itself at fire time) plus the Edge_Desc
    // table wired into the command set; the session's per-frame edge pass
    // (knet.registry_edges_tick) does the rest — mirror, net diff, resync
    // silence — so no seen_* scratch and no re-seed handling exist to forget.
    has_edges := false

    for r in s.replicates {
        if r.edge_proc != "" {
            has_edges = true
            break
        }
    }

    if has_edges {
        for r in s.replicates {
            if r.edge_proc == "" {
                continue
            }

            leaf := join_snake(r.path)
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_edge_%s :: proc(entity: rawptr, game: rawptr, old: rawptr) {{\n",
                snake,
                leaf,
            )
            fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)

            // The old-value cast derives its type from the field itself
            // (type_of) — no spelled type, so an imported block's field needs
            // no qualifier and no import here.
            if r.edge_game != "" {
                fmt.sbprintf(
                    b,
                    "\tassert(game != nil, \"%s needs the game pointer — session_set_factory's user is what edge halves receive\")\n",
                    r.edge_proc,
                )
                fmt.sbprintf(
                    b,
                    "\t%s(cast(^%s)game, self, (cast(^type_of(self.%s))old)^, self.%s)\n",
                    r.edge_proc,
                    r.edge_game,
                    join_path(r.path),
                    join_path(r.path),
                )
            } else {
                fmt.sbprintf(
                    b,
                    "\t%s(self, (cast(^type_of(self.%s))old)^, self.%s)\n",
                    r.edge_proc,
                    join_path(r.path),
                    join_path(r.path),
                )
            }

            w(b, "}\n\n")
        }

        fmt.sbprintf(b, "@(private = \"file\")\n_%s_edges := [?]knet.Edge_Desc {{\n", snake)

        for r, i in s.replicates {
            if r.edge_proc == "" {
                continue
            }

            fmt.sbprintf(b, "\t{{field = %d, fire = _%s_edge_%s}},\n", i, snake, join_snake(r.path))
        }

        w(b, "}\n\n")
    }

    // The command set is emitted for EVERY entity with a descriptor — desc-only
    // entities (no commands) used to force a hand-built set in the game. A
    // ticking class's set stays desc-only: its verbs ride the lane.
    if len(s.replicates) > 0 || len(s.commands) > 0 {
        cmds := len(s.commands) > 0 && !is_sim ? fmt.tprintf(", commands = _%s_commands[:]", snake) : ""
        net_id := s.net_id_type != "" ? fmt.tprintf(", net_id_offset = int(offset_of(%s, net_id))", cls) : ""
        edges := has_edges ? fmt.tprintf(", edges = _%s_edges[:]", snake) : ""
        fmt.sbprintf(
            b,
            "// kit/net command set for %s — the command table + the replicated-field descriptor.\n%s_command_set := knet.Command_Set{{entity_desc = &%s_net_desc%s%s%s}}\n\n",
            cls,
            snake,
            descriptor,
            cmds,
            net_id,
            edges,
        )
    }

    if len(s.commands) > 0 && !is_sim {
        for c in s.commands {
            if !wrappers {continue}
            // Composed wrappers are named per entity and field path.
            wrapper := len(c.path) > 0 ? fmt.tprintf("%s_%s", snake, c.name) : c.proc_name
            fmt.sbprintf(b, "// Issue `%s` — the SAME call on every peer AND on both models, zero role\n", c.name)
            w(b, "// branches. Both paths use the Session's bound descriptor. Client: applies the\n")
            w(b, "// typed action policy, optionally predicts, and sends when admitted.\n")
            w(b, "// Returns a knet.Action_Outcome — .state is Applied/Predicted/Rejected,\n")
            w(b, "// .reason names a synchronous refusal, and .seq correlates the final callback.\n")
            w(b, "// `knet.command_ok(r)` is the \"applied on my screen?\" check. The boot is the\n")
            w(b, "// game's one handle: promoting this class to the sim lane re-routes the verb\n")
            w(b, "// without touching a single issue site.\n")
            fmt.sbprintf(b, "%s_cmd :: proc(b: ^kboot.Boot, self: ^%s", wrapper, cls)

            for a in c.args {
                fmt.sbprintf(b, ", %s: %s", a.name, a.type_text)
            }

            w(b, ") -> knet.Action_Outcome {\n")
            w(b, "\tctx := &b.ses.ctx\n\t_id := self.net_id\n")
            fmt.sbprintf(b, "\t_set := &%s_command_set\n", snake)
            w(b, "\tif _entry, _found := knet.registry_get(&b.ses.reg, _id); _found {\n")
            w(b, "\t\tif _entry.entity != rawptr(self) {return knet.action_outcome(.Rejected, .Stale)}\n\t\t_set = _entry.set\n")
            w(b, "\t} else if b.ses.ran {return knet.action_outcome(.Rejected, .Stale)}\n")
            fmt.sbprintf(b, "\t_command := knet.command_find(_set, u16(%s_CMD_%s))\n", upper, strings.to_upper(c.name))
            w(b, "\tif _command == nil {return knet.action_outcome(.Rejected, .Malformed)}\n")
            w(b, "\tif _reason := ksess.session_action_rejection(b.ses, _id, _command.policy); _reason != .None {return knet.action_outcome(.Rejected, _reason)}\n")
            w(b, "\tif ctx.is_authority {\n")
            // Per-call storage: a consequence can issue another command without
            // overwriting this invocation's encoded arguments or captured ID.
            w(b, "\t\t_args := knet.writer_make()\n\t\tdefer knet.writer_destroy(&_args)\n")
            for a in c.args {
                fmt.sbprintf(b, "\t\tknet.write_%s(&_args, %s)\n", a.wire, a.name)
            }
            w(b, "\t\t_reader := knet.reader_make(knet.writer_bytes(&_args))\n")
            w(b, "\t\t_env := knet.Command_Env{authority = true, user = ctx.game_user, by = ctx.me}\n")
            fmt.sbprintf(b, "\t\t_reason := knet.command_execute(self, _set, u16(%s_CMD_%s), &_reader, &_env)\n", upper, strings.to_upper(c.name))
            fmt.sbprintf(b, "\t\tknet.command_hook_local(ctx, _id, %s_CMD_%s, _reason == .None)\n", upper, strings.to_upper(c.name))
            w(b, "\t\tif _reason == .None {return knet.action_outcome(.Applied)}\n\t\treturn knet.action_outcome(.Rejected, _reason)\n\t}\n")
            fmt.sbprintf(b, "\tknet.command_begin(ctx, _id, %s_CMD_%s)\n", upper, strings.to_upper(c.name))
            for a in c.args {
                fmt.sbprintf(b, "\tknet.write_%s(&ctx.msg, %s)\n", a.wire, a.name)
            }
            fmt.sbprintf(b, "\t_issue := knet.command_issue(ctx, self, _set, %s_CMD_%s)\n", upper, strings.to_upper(c.name))
            w(b, "\tif !_issue.sent {return knet.action_outcome(.Rejected, _issue.reason)}\n")
            w(
                b,
                "\tif _issue.prediction_attempted && !_issue.prediction_applied {return knet.action_outcome(.Rejected, _issue.reason, u32(_issue.seq))}\n",
            )
            w(b, "\treturn knet.action_outcome(.Predicted, seq = u32(_issue.seq))\n}\n\n")
        }
    }

}

emit_entity_sim :: proc(b: ^strings.Builder, s: ^Script, cls, snake: string, wrappers: bool = true, descriptor: string = "") {
    descriptor := descriptor != "" ? descriptor : snake
    w :: strings.write_string
    upper := strings.to_upper(snake)
    // ---- @(gd_tick): the sim-lane step thunk + Sim_Set (kit/sim) ----
    // The thunk is the whole bridge: the lane drives entities through rawptrs
    // (live ticks AND resim replays take the identical path), the author's
    // proc stays typed and single-player-shaped. The input struct crosses the
    // wire raw, so the same POD contract as replicated fields is #asserted at
    // the consumer compile, naming the type.
    if s.tick.proc_name != "" || len(s.block_ticks) > 0 {
        w(b, "// ---- @(gd_tick) sim-lane step ----\n\n")

        if s.tick.input_code != "" {
            fmt.sbprintf(
                b,
                "#assert(intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s), \"%s: @(gd_tick) input structs must be POD (they cross the wire raw — no strings, slices, maps, or pointers)\")\n\n",
                s.tick.input_code,
                s.tick.input_code,
                s.tick.input_code,
                s.tick.input_code,
            )
        }

        fmt.sbprintf(
            b,
            "@(private = \"file\")\n_%s_tick_step :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {{\n",
            snake,
        )

        if s.tick.proc_name != "" && s.tick.input_code != "" {
            w(b, "\tif input == nil {return} // no input drives this entity here this tick: coast\n")
        }

        consumed := s.tick.then_proc != "" || s.tick.fx_proc != ""
        need_self := consumed || len(s.block_ticks) > 0

        if need_self {
            fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
        }

        if s.tick.proc_name != "" {
            if s.tick.payload_count > 0 {
                w(b, "\t")

                for i in 0 ..< s.tick.payload_count {
                    if i > 0 {
                        w(b, ", ")
                    }

                    if consumed {
                        fmt.sbprintf(b, "_p%d", i)
                    } else {
                        w(b, "_") // payload offered, nobody consumes (warned at build)
                    }
                }

                w(b, consumed ? " := " : " = ")
            } else {
                w(b, "\t")
            }

            if need_self {
                fmt.sbprintf(b, "%s(self", s.tick.proc_name)
            } else {
                fmt.sbprintf(b, "%s(cast(^%s)entity", s.tick.proc_name, cls)
            }

            if s.tick.input_code != "" {
                fmt.sbprintf(b, ", (cast(^%s)input)^", s.tick.input_code)
            }

            if s.tick.wants_lane {
                w(b, ", lane")
            }

            w(b, ")\n")
        }

        // Composed block ticks, AFTER the entity's own step in field order —
        // the entity writes intent first, blocks integrate.
        for bt in s.block_ticks {
            qual := bt.pkg_alias != "" ? fmt.tprintf("%s.", bt.pkg_alias) : ""
            fmt.sbprintf(b, "\t%s%s(&self.%s", qual, block_call_name(bt), join_path(bt.path))

            if bt.wants_owner {
                w(b, ", self")
            }

            if bt.wants_lane {
                w(b, ", lane")
            }

            w(b, ")\n")
        }

        // The role gates the game used to hand-write, held HERE: the
        // consequence on the authority (which never resims), the fx on the
        // owning peer's live pass only — a replay re-runs the tick, never
        // the presentation, and never double-fires a consequence.
        if s.tick.then_proc != "" {
            // in_auth marks the authority-only context for lane_fact's
            // provenance-aware owner skip: a fact door announced from a `_then`
            // must INCLUDE the anchor's owner — their screen never ran this half.
            w(b, "\tif ksim.lane_is_authority(lane) {\n\t\tlane.in_auth = true\n\t\t")

            if s.tick.then_game != "" {
                fmt.sbprintf(
                    b,
                    "assert(ksim.lane_game(lane) != nil, \"%s needs the game pointer — lane_set_sim's user is what tick consequences receive\")\n\t\t",
                    s.tick.then_proc,
                )
                fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, owner", s.tick.then_proc, s.tick.then_game)
            } else {
                fmt.sbprintf(b, "%s(self, owner", s.tick.then_proc)
            }

            for i in 0 ..< s.tick.payload_count {
                fmt.sbprintf(b, ", _p%d", i)
            }

            w(b, ")\n\t\tlane.in_auth = false\n\t}\n")
        }

        if s.tick.fx_proc != "" && !s.tick.fx_mine {
            w(b, "\tif owner == ksim.lane_me(lane) && !lane.resimming {\n\t\t")

            if s.tick.fx_game != "" {
                fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self", s.tick.fx_proc, s.tick.fx_game)
            } else {
                fmt.sbprintf(b, "%s(self", s.tick.fx_proc)
            }

            for i in 0 ..< s.tick.payload_count {
                fmt.sbprintf(b, ", _p%d", i)
            }

            w(b, ")\n\t}\n")
        }

        if s.tick.fx_proc != "" && s.tick.fx_mine {
            // The EVERY-SCREEN form: on an event tick (any bool fact true) the
            // authority broadcasts the fact tuple (watchers fire it from the
            // watch clock — lane_fact), and the screens whose live pass just
            // simulated it fire inline: the owner's (mine=true) and the
            // authority's own view of everyone else (mine=false, live truth).
            w(b, "\tif ")
            first := true

            for wire, i in s.tick.payload_wires {
                if wire != "bool" {
                    continue
                }

                if !first {
                    w(b, " || ")
                }

                fmt.sbprintf(b, "_p%d", i)
                first = false
            }

            w(b, " { // an event tick: the facts present\n")
            w(b, "\t\tif ksim.lane_is_authority(lane) {\n")
            w(b, "\t\t\t_fw := knet.writer_make(64, context.temp_allocator)\n")

            for wire, i in s.tick.payload_wires {
                fmt.sbprintf(b, "\t\t\tknet.write_%s(&_fw, _p%d)\n", wire, i)
            }

            w(b, "\t\t\tksim.lane_fact(lane, entity, knet.writer_bytes(&_fw))\n")
            w(b, "\t\t}\n")
            w(b, "\t\tif !lane.resimming {\n")
            w(b, "\t\t\t_mine := owner == ksim.lane_me(lane)\n")
            w(b, "\t\t\tif _mine || ksim.lane_is_authority(lane) {\n\t\t\t\t")

            if s.tick.fx_game != "" {
                fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, _mine", s.tick.fx_proc, s.tick.fx_game)
            } else {
                fmt.sbprintf(b, "%s(self, _mine", s.tick.fx_proc)
            }

            for i in 0 ..< s.tick.payload_count {
                fmt.sbprintf(b, ", _p%d", i)
            }

            w(b, ")\n\t\t\t}\n\t\t}\n\t}\n")
        }

        w(b, "}\n\n")

        if s.tick.fx_proc != "" && s.tick.fx_mine {
            // The fx DECODE thunk (Sim_Set.fx): SIM_FACT bytes → typed facts →
            // the presentation half. The lane fires it on WATCHING screens when
            // the watch clock reaches the fact's tick; the live pass above
            // called the half directly.
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_fx :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {{\n",
                snake,
            )
            fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
            w(b, "\tr := knet.reader_make(args)\n")

            for wire, i in s.tick.payload_wires {
                fmt.sbprintf(b, "\t_p%d := knet.read_%s(&r)\n", i, wire)
            }

            w(b, "\tif r.err {return}\n\t")

            if s.tick.fx_game != "" {
                fmt.sbprintf(b, "%s(cast(^%s)ksim.lane_game(lane), self, mine", s.tick.fx_proc, s.tick.fx_game)
            } else {
                fmt.sbprintf(b, "%s(self, mine", s.tick.fx_proc)
            }

            for i in 0 ..< s.tick.payload_count {
                fmt.sbprintf(b, ", _p%d", i)
            }

            w(b, ")\n}\n\n")
        }

        // ---- @(gd_command) on a ticking class: tick-scheduled verbs ----
        // The verb executes INSIDE the tick pipeline on both ends (kit/sim
        // command.odin): the client speculates at its next tick and resims
        // re-apply the captured patch; the authority executes at the stamped
        // tick and its `_then` fires there — the exec thunk holds that gate.
        if len(s.commands) > 0 {
            w(b, "// Command wire ids — a stable FNV-1a hash of each verb's name, NOT a\n")
            w(b, "// position: reordering procs never renumbers the wire. Typed ksim.Cmd_Id\n")
            w(b, "// so a sim verb id can't be handed to a coop command (still a plain u16\n")
            w(b, "// on the wire).\n")

            for c in s.commands {
                fmt.sbprintf(
                    b,
                    "%s_CMD_%s :: ksim.Cmd_Id(0x%x)\n",
                    upper,
                    strings.to_upper(c.name),
                    cmd_wire_id(c.name),
                )
                fmt.sbprintf(b, "%s_POLICY_%s :: %s\n", upper, strings.to_upper(c.name), c.policy_expr)
            }

            w(b, "\n")

            for c in s.commands {
                recv := len(c.path) > 0 ? fmt.tprintf("&self.%s", join_path(c.path)) : "self"
                qual := c.pkg_alias != "" ? fmt.tprintf("%s.", c.pkg_alias) : ""
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_simcmd_%s :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> knet.Action_Reject_Reason {{\n",
                    snake,
                    c.name,
                )
                fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)
                w(b, "\tr := knet.reader_make(args)\n")

                if len(c.args) > 0 {
                    for a, i in c.args {
                        fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, a.wire)
                    }
                }

                w(b, "\tif r.err || len(knet.reader_remaining(&r)) != 0 {return .Malformed}\n")
                w(b, "\t_ok")

                for i in 0 ..< c.payload_count {
                    if c.then_proc != "" {
                        fmt.sbprintf(b, ", _p%d", i)
                    } else {
                        w(b, ", _")
                    }
                }

                fmt.sbprintf(b, " := %s%s(%s", qual, command_call_name(c), recv)

                if c.owner {
                    w(b, ", self")
                }

                if c.wants_by {
                    w(b, ", by")
                } // the declared issuer — the lane resolved it (me speculating, the seat on the host)

                for _, i in c.args {
                    fmt.sbprintf(b, ", _a%d", i)
                }

                w(b, ")\n")

                if c.apply_proc != "" {
                    // The predicted-effect half, on the live pass — resims
                    // re-run it alone, with the ledgered args.
                    fmt.sbprintf(b, "\tif _ok {{%s(self", c.apply_proc)

                    for _, i in c.args {
                        fmt.sbprintf(b, ", _a%d", i)
                    }

                    w(b, ")}\n")
                }

                if c.then_proc != "" {
                    // in_auth: a fact door announced from this authority-only
                    // half must include the anchor's owner in the broadcast.
                    w(b, "\tif _ok && ksim.lane_is_authority(lane) {\n\t\tlane.in_auth = true\n")

                    if c.then_game != "" {
                        fmt.sbprintf(
                            b,
                            "\t\tassert(ksim.lane_game(lane) != nil, \"%s needs the game pointer — lane_set_sim's user is what consequences receive\")\n",
                            c.then_proc,
                        )
                        fmt.sbprintf(b, "\t\t%s(cast(^%s)ksim.lane_game(lane), self, by", c.then_proc, c.then_game)
                    } else {
                        fmt.sbprintf(b, "\t\t%s(self, by", c.then_proc)
                    }

                    for _, i in c.args {
                        fmt.sbprintf(b, ", _a%d", i)
                    }

                    for i in 0 ..< c.payload_count {
                        fmt.sbprintf(b, ", _p%d", i)
                    }

                    w(b, ")\n\t\tlane.in_auth = false\n\t}\n")
                }

                w(b, "\treturn _ok ? .None : .Predicate\n}\n\n")

                if c.apply_proc != "" {
                    // The resim's door into the apply half: decode the
                    // LEDGERED args, re-run the effect against corrected
                    // pre-state — never the verb, never its delta writes.
                    fmt.sbprintf(
                        b,
                        "@(private = \"file\")\n_%s_simcmd_%s_apply :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane) {{\n",
                        snake,
                        c.name,
                    )
                    fmt.sbprintf(b, "\tself := cast(^%s)entity\n", cls)

                    if len(c.args) > 0 {
                        w(b, "\tr := knet.reader_make(args)\n")

                        for a, i in c.args {
                            fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, a.wire)
                        }

                        w(b, "\tif r.err {return}\n")
                    }

                    fmt.sbprintf(b, "\t%s(self", c.apply_proc)

                    for _, i in c.args {
                        fmt.sbprintf(b, ", _a%d", i)
                    }

                    w(b, ")\n}\n\n")
                }
            }

            fmt.sbprintf(b, "@(private = \"file\")\n_%s_sim_cmds := [?]ksim.Sim_Cmd {{\n", snake)

            for &c in s.commands {
                w(b, "\t{")
                emit_action_desc(b, s, &c, "Scheduled", snake)

                if c.apply_proc != "" {
                    fmt.sbprintf(
                        b,
                        ", exec = _%s_simcmd_%s, apply = _%s_simcmd_%s_apply},\n",
                        snake,
                        c.name,
                        snake,
                        c.name,
                    )
                } else {
                    fmt.sbprintf(b, ", exec = _%s_simcmd_%s},\n", snake, c.name)
                }
            }

            w(b, "}\n\n")

            for c in s.commands {
                if !wrappers {continue}
                wrapper := len(c.path) > 0 ? fmt.tprintf("%s_%s", snake, c.name) : c.proc_name
                fmt.sbprintf(
                    b,
                    "// Issue `%s` — tick-scheduled on the sim lane: the SAME call on every peer\n",
                    c.name,
                )
                w(b, "// AND on both models, zero role branches. Your own entity speculates at your\n")
                w(b, "// next tick; the authority executes at the stamped tick and answers with a\n")
                w(b, "// verdict — a rejection unwinds the delta-lane writes and the reconcile\n")
                w(b, "// scrubs the predicted ones. Returns a knet.Action_Outcome: .Predicted =\n")
                w(b, "// scheduled and in flight on my screen (even the authority's own issue runs\n")
                w(b, "// at the stamped tick, never inline — .Applied is a coop-loop word); the\n")
                w(b, "// verdict is state. `knet.command_ok(r)` reads it, same as any coop verb.\n")
                fmt.sbprintf(b, "%s_cmd :: proc(b: ^kboot.Boot, self: ^%s", wrapper, cls)

                for a in c.args {
                    fmt.sbprintf(b, ", %s: %s", a.name, a.type_text)
                }

                w(b, ") -> knet.Action_Outcome {\n")
                fmt.sbprintf(
                    b,
                    "\tassert(b.lane != nil, \"%s_cmd rides the sim lane — kboot.boot_lane(&boot, &lane) installs it\")\n",
                    wrapper,
                )

                if len(c.args) > 0 {
                    w(b, "\t_w := knet.writer_make(64, context.temp_allocator)\n")

                    for a in c.args {
                        fmt.sbprintf(b, "\tknet.write_%s(&_w, %s)\n", a.wire, a.name)
                    }

                    fmt.sbprintf(
                        b,
                        "\t_issue := ksim.lane_command(b.lane, self.net_id, %s_CMD_%s, knet.writer_bytes(&_w))\n",
                        upper,
                        strings.to_upper(c.name),
                    )
                } else {
                    fmt.sbprintf(
                        b,
                        "\t_issue := ksim.lane_command(b.lane, self.net_id, %s_CMD_%s, nil)\n",
                        upper,
                        strings.to_upper(c.name),
                    )
                }

                w(
                    b,
                    "\tif _issue.scheduled {return knet.action_outcome(.Predicted, seq = u32(_issue.seq), model = .Scheduled)}\n",
                )
                w(b, "\treturn knet.action_outcome(.Rejected, _issue.reason, model = .Scheduled)\n}\n\n")
            }
        }

        in_size := s.tick.input_code != "" ? fmt.tprintf("size_of(%s)", s.tick.input_code) : "0"
        // The wire class the input rides (resolve_sim assigned it package-wide);
        // 0 for the primary or an inputless tick, emitted only when it differs.
        in_class :=
            s.tick.input_code != "" && s.tick.input_class != 0 ? fmt.tprintf(", input_class = %d", s.tick.input_class) : ""
        contested := s.tick.contested ? ", contested = true" : ""
        sim_cmds := len(s.commands) > 0 ? fmt.tprintf(", commands = _%s_sim_cmds[:]", snake) : ""
        fx := s.tick.fx_mine ? fmt.tprintf(", fx = _%s_fx", snake) : ""
        fmt.sbprintf(
            b,
            "// kit/sim set for %s — ksim.lane_track_set(&lane, id, self, &%s_sim_set, owner)\n%s_sim_set := ksim.Sim_Set{{entity_desc = &%s_net_desc, tick = _%s_tick_step, input_size = %s%s%s%s%s}}\n\n",
            cls,
            snake,
            snake,
            descriptor,
            snake,
            in_size,
            in_class,
            contested,
            sim_cmds,
            fx,
        )
    }

}

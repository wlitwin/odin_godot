package scriptgen

import "core:fmt"
import "core:slice"
import "core:strings"
import decl "godot:decl"

// Maps a Variant enum member like ".Int" to the bare token used to build cached
// constructor variable names (`_to_Int`, `_from_Int`).
ctor_tag :: proc(enum_name: string) -> string {
    return enum_name[1:] // drop leading '.'
}

// ---- replicated-field expressions (nested-replicate-fields) -------------------
//
// A replicated field is addressed by its PATH from the entity root (Replicate_Info.path):
// {"hp"} for a top-level field, {"m","x"} for one reached through a `using`/embedded
// sub-struct. These build the offset/size/type-of expressions the descriptor and the POD
// #assert consume. A length-1 path emits byte-identical output to the pre-nesting code.

// The value-type expression: {"hp"} -> `type_of(Cls{}.hp)`; {"m","x"} -> `type_of(Cls{}.m.x)`.
field_type_expr :: proc(cls: string, path: []string) -> string {
    return fmt.tprintf("type_of(%s{{}}.%s)", cls, join_path(path))
}

// The byte-offset expression. Nested paths compose per segment via `type_of` on the
// container, so no intermediate struct type is ever NAMED — the generated file needs no
// import of the sub-struct's package (works for imported bundles too):
//   {"hp"}        -> offset_of(Cls, hp)
//   {"m","x"}     -> offset_of(Cls, m) + offset_of(type_of(Cls{}.m), x)
//   {"a","b","x"} -> offset_of(Cls, a) + offset_of(type_of(Cls{}.a), b) + offset_of(type_of(Cls{}.a.b), x)
field_offset_expr :: proc(cls: string, path: []string) -> string {
    if len(path) == 1 {
        return fmt.tprintf("offset_of(%s, %s)", cls, path[0])
    }

    b := strings.builder_make()

    for seg, i in path {
        if i > 0 {
            strings.write_string(&b, " + ")
        }

        if i == 0 {
            fmt.sbprintf(&b, "offset_of(%s, %s)", cls, seg)
        } else {
            fmt.sbprintf(&b, "offset_of(type_of(%s{{}}.%s), %s)", cls, join_path(path[:i]), seg)
        }
    }

    return strings.to_string(b)
}

// Infer container types from the actual field. This also works for private
// element types in another package, without exporting their implementation.
backup_type_exprs :: proc(cls, snake: string, backup: Backup_Info) -> (key, elem: string) {
    field := field_type_expr(cls, backup.path)
    switch backup.kind {
    case .Map:
        pair := fmt.tprintf("_%s_backup_map_types(%s)", snake, field)
        return fmt.tprintf("type_of(%s.key)", pair), fmt.tprintf("type_of(%s.value)", pair)
    case .Dyn:
        return "", fmt.tprintf("intrinsics.type_elem_type(%s)", field)
    case .Pod:
        return "", field
    }
    return
}

// gd:"backup" — the host-local migration/save codec (Backup_Info). A
// version-hashed <class>_backup_write/_read pair over the tagged fields, so a
// takeover or a resume restores the campaign with no hand-matched write/read
// lists to drift. POD fields ride whole (knet.write_pod); map[POD]POD and
// [dynamic]POD get a length-prefixed loop. The version const is an FNV-1a of the
// field SIGNATURE, so a stale blob from a mismatched build bails on read instead
// of misreading bytes — the automatic form of the hand-kept version byte.
emit_backup :: proc(b: ^strings.Builder, s: ^Script) {
    if len(s.backups) == 0 {
        return
    }

    cls := s.struct_name
    snake := decl.snake_name(cls)
    upper := strings.to_upper(snake)
    w :: strings.write_string

    // FNV-1a over the field signature — a stable compile-time version stamp
    // (the shared hash law's 32-bit namespace; see godot:decl).
    ver := decl.FNV32_OFFSET

    for bk in s.backups {
        sig := fmt.tprintf("%s|%v|%s|%s;", join_path(bk.path), bk.kind, bk.key_name, bk.elem_name)
        ver = decl.fnv1a32_acc(ver, sig)
    }

    pod :: proc(x: string) -> string {
        return fmt.tprintf(
            "intrinsics.type_is_nearly_simple_compare(%s) && !intrinsics.type_is_pointer(%s) && !intrinsics.type_is_multi_pointer(%s)",
            x,
            x,
            x,
        )
    }

    w(b, "// ---- gd:\"backup\": host-local migration + save codec ----\n")

    for bk in s.backups {
        if bk.kind != .Map {continue}
        fmt.sbprintf(
            b,
            "@(private = \"file\")\n_%s_Backup_Map_Types :: struct($K, $V: typeid) {{key: K, value: V}}\n",
            snake,
        )
        fmt.sbprintf(
            b,
            "@(private = \"file\")\n_%s_backup_map_types :: proc($M: typeid/map[$K]$V) -> _%s_Backup_Map_Types(K, V) {{return {{}}}}\n\n",
            snake,
            snake,
        )
        break
    }

    for bk in s.backups {
        key, elem := backup_type_exprs(cls, snake, bk)
        switch bk.kind {
        case .Pod:
            fmt.sbprintf(
                b,
                "#assert(%s, \"%s.%s: gd:\\\"backup\\\" fields must be POD (no strings, slices, maps, or pointers)\")\n",
                pod(field_type_expr(cls, bk.path)),
                cls,
                bk.field,
            )
        case .Map:
            fmt.sbprintf(b, "#assert(%s, \"%s.%s: gd:\\\"backup\\\" map key must be POD\")\n", pod(key), cls, bk.field)
            fmt.sbprintf(
                b,
                "#assert(%s, \"%s.%s: gd:\\\"backup\\\" map value must be POD\")\n",
                pod(elem),
                cls,
                bk.field,
            )
        case .Dyn:
            fmt.sbprintf(
                b,
                "#assert(%s, \"%s.%s: gd:\\\"backup\\\" element must be POD\")\n",
                pod(elem),
                cls,
                bk.field,
            )
        }
    }

    fmt.sbprintf(b, "\n%s_BACKUP_VERSION :: u32(0x%x)\n\n", upper, ver)

    // ---- write ----
    fmt.sbprintf(b, "%s_backup_write :: proc(self: ^%s, w: ^knet.Writer) {{\n", snake, cls)
    fmt.sbprintf(b, "\tknet.write_u32(w, %s_BACKUP_VERSION)\n", upper)

    for bk in s.backups {
        acc := fmt.tprintf("self.%s", join_path(bk.path))

        switch bk.kind {
        case .Pod:
            fmt.sbprintf(b, "\tknet.write_pod(w, %s)\n", acc)
        case .Map:
            fmt.sbprintf(
                b,
                "\tknet.write_u32(w, u32(len(%s)))\n\tfor k, v in %s {{knet.write_pod(w, k); knet.write_pod(w, v)}}\n",
                acc,
                acc,
            )
        case .Dyn:
            fmt.sbprintf(b, "\tknet.write_u32(w, u32(len(%s)))\n\tfor e in %s {{knet.write_pod(w, e)}}\n", acc, acc)
        }
    }

    w(b, "}\n\n")

    // ---- read (false on a version mismatch or a truncated blob) ----
    fmt.sbprintf(b, "%s_backup_read :: proc(self: ^%s, r: ^knet.Reader) -> bool {{\n", snake, cls)
    fmt.sbprintf(b, "\tif knet.read_u32(r) != %s_BACKUP_VERSION {{return false}}\n", upper)

    for bk in s.backups {
        acc := fmt.tprintf("self.%s", join_path(bk.path))
        key, elem := backup_type_exprs(cls, snake, bk)

        switch bk.kind {
        case .Pod:
            fmt.sbprintf(b, "\t%s = knet.read_pod(r, type_of(%s))\n", acc, acc)
        case .Map:
            fmt.sbprintf(
                b,
                "\t{{\n\t\tn := knet.read_u32(r)\n\t\tif r.err {{return false}}\n\t\tclear(&%s)\n\t\tfor _ in 0 ..< n {{\n\t\t\tk := knet.read_pod(r, %s)\n\t\t\tv := knet.read_pod(r, %s)\n\t\t\tif r.err {{return false}}\n\t\t\t%s[k] = v\n\t\t}}\n\t}}\n",
                acc,
                key,
                elem,
                acc,
            )
        case .Dyn:
            fmt.sbprintf(
                b,
                "\t{{\n\t\tn := knet.read_u32(r)\n\t\tif r.err {{return false}}\n\t\tclear(&%s)\n\t\tfor _ in 0 ..< n {{\n\t\t\te := knet.read_pod(r, %s)\n\t\t\tif r.err {{return false}}\n\t\t\tappend(&%s, e)\n\t\t}}\n\t}}\n",
                acc,
                elem,
                acc,
            )
        }
    }

    w(b, "\treturn !r.err\n}\n\n")
}

// ---- main emitter ------------------------------------------------------------
//
// ONE consolidated `odin_godot_scripts.gen.odin` per scripts dir carries the
// generated code for EVERY annotated script in that dir: one header, one
// `package`, one import block (the UNION of what the sections need), one shared
// cached-Variant-constructor block, then one section per script introduced by a
// `// ==== <source>.odin (class <Class>) ====` banner.
//
// Merging is safe because every generated top-level name is either PUBLIC — and
// so already had to be unique across the package, separate files shared one
// namespace too — or `@(private = "file")` and prefixed with the owning class's
// snake. The one un-prefixed group is the cached-Variant-constructor block
// (`_to_Int`, `_ensure_ctors`, ...), which is hoisted to file scope here and
// emitted ONCE over the union of every section's tags.

// A script's slot in the consolidated file.
Gen_Section :: struct {
    src_name: string, // the REAL authored basename ("mob.odin"), not the class snake
    script:   ^Script,
}

// What ONE script needs from the fixed import set. The file imports the UNION over
// its sections, so an import is emitted exactly when at least one section names it
// — never one no section uses (an unused import is a compile error in Odin).
Gen_Needs :: struct {
    knet, intrinsics, ksim, ksess, kboot, netgd, replay_view: bool,
}

script_needs :: proc(s: ^Script) -> (n: Gen_Needs) {
    n.replay_view = s.replay_view.line != 0
    // A gd:"replicate" field needs the kit/net descriptor + the POD compile-time
    // check (commands imply replicates — parse validation enforces it — but keep the
    // condition independent for robustness). @(gd_message) thunks name knet.Player_Id.
    n.knet =
        len(s.replicates) > 0 ||
        len(s.commands) > 0 ||
        len(s.entities) > 0 ||
        len(s.backups) > 0 ||
        len(s.messages) > 0 ||
        len(s.net_events) > 0
    n.intrinsics = len(s.replicates) > 0 || len(s.backups) > 0
    for e in s.entities {
        if e.binding != nil && e.binding.tick.input_code != "" {n.intrinsics = true}
    }
    // @(gd_tick) generates the sim-lane thunk + Sim_Set (kit/sim) — and an
    // entity TABLE references a target's Sim_Set when that class ticks.
    ticked_entities := false

    for e in s.entities {
        if e.has_tick {
            ticked_entities = true
            break
        }
    }

    // A boot-routed authority step (s.step_boot) is NOT lane wiring — the coop
    // game's fixed step rides `<snake>_step` + the boot accumulator instead.
    has_lane_wiring :=
        len(s.input_classes) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot)
    n.ksim = s.tick.proc_name != "" || len(s.block_ticks) > 0 || ticked_entities || has_lane_wiring
    // Any declared migration half pulls kboot (the hooks table + the events-tail
    // drain) and ksess (the events proc's signature).
    has_succ := s.succ_backup != "" || s.succ_took_over != "" || s.succ_wiped != "" || s.succ_migrating != ""
    coop_commands := len(s.commands) > 0 && s.tick.proc_name == "" && len(s.block_ticks) == 0
    event_boot := len(s.net_events) > 0 || len(s.facts) > 0
    // entity tables (`entity=Name:id` scene fields) name ksess.Entity_Type and
    // build kboot.Entity_Kind rows; the lane wiring names ksess.Session; the
    // standard transport forwards route into netgd/ksess; the boot-routed step
    // and the session-event dispatch name ksess too. @(gd_message) names
    // ksess.Typed_Route / session_app_* / Session / Peer_Id / Channel.
    n.ksess =
        len(s.entities) > 0 ||
        has_lane_wiring ||
        len(s.std_forwards) > 0 ||
        s.step_boot ||
        len(s.event_halves) > 0 ||
        has_succ ||
        s.profile_code != "" ||
        len(s.messages) > 0 ||
        coop_commands ||
        len(s.net_events) > 0
    // The unified `<verb>_cmd` wrappers take the game's one handle (^kboot.Boot)
    // on BOTH models, so any class with commands names kboot.
    n.kboot =
        len(s.entities) > 0 ||
        len(s.commands) > 0 ||
        has_succ ||
        s.net_attach ||
        s.net_pump ||
        s.net_frame ||
        s.net_detach ||
        event_boot
    n.netgd = len(s.std_forwards) > 0

    for ex in s.exports {
        if ex.getter != "" {
            n.intrinsics = true
        }
    }

    return
}

// The consolidated file's import block. Keyed BOTH ways: by path (a package named
// by two sections is imported once) and by effective alias (two different paths can
// never claim one alias — that would be a duplicate declaration inside DO NOT EDIT
// code, reported as a confusing error against generated source).
Import_Table :: struct {
    by_path:  map[string]string, // path  -> alias
    by_alias: map[string]string, // alias -> path
    lines:    [dynamic]string,
}

// `bare` emits `import "<path>"` (the alias IS the package's own name); otherwise
// `import <alias> "<path>"`. Either way `alias` is the name the bodies write.
import_add :: proc(t: ^Import_Table, alias, path: string, bare := false) {
    if have, dup := t.by_path[path]; dup {
        if have != alias {
            errorf(
                "generated import conflict: %q is imported as %q and also wanted as %q — one package, one alias per generated file",
                path,
                have,
                alias,
            )
        }

        return
    }

    if other, taken := t.by_alias[alias]; taken {
        errorf(
            "generated import conflict: the alias %q is claimed by both %q and %q — rename one package's directory",
            alias,
            other,
            path,
        )
        return
    }

    t.by_path[path] = alias
    t.by_alias[alias] = path

    if bare {
        append(&t.lines, fmt.aprintf("import %q\n", path))
    } else {
        append(&t.lines, fmt.aprintf("import %s %q\n", alias, path))
    }
}

// The single import block: the fixed trio, the conditional kit imports under the
// UNION of the sections' needs, then the verb-composition packages deduped across
// the whole file.
emit_imports :: proc(b: ^strings.Builder, sections: []Gen_Section) {
    need: Gen_Needs

    for sec in sections {
        n := script_needs(sec.script)
        need.knet |= n.knet
        need.intrinsics |= n.intrinsics
        need.ksim |= n.ksim
        need.ksess |= n.ksess
        need.kboot |= n.kboot
        need.netgd |= n.netgd
        need.replay_view |= n.replay_view
    }

    t: Import_Table
    t.by_path = make(map[string]string, context.temp_allocator)
    t.by_alias = make(map[string]string, context.temp_allocator)
    t.lines = make([dynamic]string, context.temp_allocator)

    import_add(&t, "gd", "godot:godot")
    import_add(&t, "gdext", "godot:gdext", bare = true)
    import_add(&t, "rt", "godot:runtime")

    if need.knet {
        import_add(&t, "knet", "godot:kit/net")
    }

    if need.intrinsics {
        import_add(&t, "intrinsics", "base:intrinsics", bare = true)
    }

    if need.ksim {
        import_add(&t, "ksim", "godot:kit/sim")
    }

    if need.ksess {
        import_add(&t, "ksess", "godot:kit/session")
    }

    if need.kboot {
        import_add(&t, "kboot", "godot:kit/boot")
    }

    if need.netgd {
        import_add(&t, "netgd", "godot:kit/netgd")
    }

    if need.replay_view {
        import_add(&t, "rview", "godot:replay/godot/scene")
    }

    fixed := len(t.lines)

    // verb-composition: import each package a COMPOSED command's/method's/block
    // tick's proc lives in, so the routed thunk can name `play.gun_fire`. "" = the
    // entity's own package (no import). The fixed imports above are already in the
    // table, so a block that unusually lives in one is never double-imported —
    // it collides loudly instead of emitting an unresolvable qualifier.
    for sec in sections {
        s := sec.script

        for alias, path in s.code_imports {import_add(&t, alias, path)}
        for alias, path in s.tick.input_imports {import_add(&t, alias, path)}
        for ic in s.input_classes {
            for alias, path in ic.imports {import_add(&t, alias, path)}
        }
        for e in s.entities {
            if e.pkg_path != "" {import_add(&t, e.pkg_alias, e.pkg_path)}
        }

        for c in s.commands {
            if c.pkg_path != "" {
                import_add(&t, c.pkg_alias, c.pkg_path)
            }
        }

        for m in s.methods {
            if m.pkg_path != "" {
                import_add(&t, m.pkg_alias, m.pkg_path)
            }
        }

        for bt in s.block_ticks {
            if bt.pkg_path != "" {
                import_add(&t, bt.pkg_alias, bt.pkg_path)
            }
        }
    }

    // The fixed imports keep their canonical order; the composed ones sort, so the
    // same inputs produce a byte-identical block however the sections arrived.
    slice.sort(t.lines[fixed:])

    for line in t.lines {
        strings.write_string(b, line)
    }

    // The trampolines/lifecycle wrappers establish `context = rt.script_context()` before
    // calling the user's plain Odin procs. On native that is `runtime.default_context()`
    // (heap-backed); on web the core installs an engine-backed context with a working
    // temp allocator (the freestanding default context has none). See runtime/context.odin.
    strings.write_string(b, "\n")
}

// The ONE cached-Variant-constructor block, over the union of every section's tags.
// It is the only generated group whose names are not class-prefixed, so sharing one
// file means sharing one definition — every trampoline already calls exactly these
// names, so hoisting needs no change at the call sites.
emit_ctors :: proc(b: ^strings.Builder, sections: []Gen_Section) {
    w :: strings.write_string

    add :: proc(set: ^[dynamic]string, tag: string) {
        for e in set {
            if e == tag {
                return
            }
        }

        append(set, tag)
    }

    to_set := make([dynamic]string, context.temp_allocator)
    from_set := make([dynamic]string, context.temp_allocator)
    // Every method/accessor trampoline opens with `_ensure_ctors()`, so its definition must
    // exist whenever ANY such trampoline is emitted — even if no arg/return needs a Variant
    // constructor (a zero-arg `@(gd_method)` on a script with no other ctor needs). In that
    // case the proc is a cheap no-op; without it the call is an undeclared-name error.
    has_trampoline := false

    for sec in sections {
        s := sec.script
        st, sf := collect_ctors(s)

        for tag in st {
            add(&to_set, tag)
        }

        for tag in sf {
            add(&from_set, tag)
        }

        if len(s.methods) > 0 {
            has_trampoline = true
        }

        for ex in s.exports {
            if ex.getter != "" || ex.setter != "" {
                has_trampoline = true
                break
            }
        }
    }

    if len(to_set) == 0 && len(from_set) == 0 && !has_trampoline {
        return
    }

    w(b, "// ---- cached Variant constructors (shared by every section) ----\n")

    for tag in to_set {
        fmt.sbprintf(b, "@(private = \"file\")\n_to_%s: gdext.TypeFromVariantConstructorProc\n", tag)
    }

    for tag in from_set {
        fmt.sbprintf(b, "@(private = \"file\")\n_from_%s: gdext.VariantFromTypeConstructorProc\n", tag)
    }

    w(b, "@(private = \"file\")\n_ctors_ready: bool\n")
    w(b, "@(private = \"file\")\n_ensure_ctors :: proc \"contextless\" () {\n")
    w(b, "\tif _ctors_ready {return}\n")

    for tag in to_set {
        fmt.sbprintf(b, "\t_to_%s = gdext.get_variant_to_type_constructor(.%s)\n", tag, tag)
    }

    for tag in from_set {
        fmt.sbprintf(b, "\t_from_%s = gdext.get_variant_from_type_constructor(.%s)\n", tag, tag)
    }

    w(b, "\t_ctors_ready = true\n}\n\n")
}

// generate_all — the whole consolidated artifact for one scripts dir. `sections` is
// already in its final (source-filename) order; the caller owns the sorting so the
// same inputs always produce a byte-identical file.
generate_all :: proc(pkg: string, sections: []Gen_Section, bridges: []Package_Bridge) -> string {
    b := strings.builder_make()
    w :: strings.write_string

    w(&b, "// Code generated by scriptgen. DO NOT EDIT.\n")
    fmt.sbprintf(&b, "// One artifact per scripts dir: %d script section(s), banner-marked below.\n", len(sections))
    fmt.sbprintf(&b, "package %s\n\n", pkg)

    if len(sections) > 0 {
        emit_imports(&b, sections)
        emit_ctors(&b, sections)
    }
    for bridge in bridges {
        if bridge.value {
            fmt.sbprintf(
                &b,
                "%s :: proc \"contextless\" () -> type_of(%s) {{return %s}}\n",
                bridge.name,
                bridge.procedure,
                bridge.procedure,
            )
        } else {
            fmt.sbprintf(&b, "%s :: proc {{%s}}\n", bridge.name, bridge.procedure)
        }
    }

    for sec in sections {
        // The editor's deletion probe (core/reload.odin SECTION_BANNER) parses this
        // exact banner to find sections whose authored source is gone — keep in sync.
        label := sec.script.class_name != "" ? sec.script.class_name : sec.script.struct_name
        fmt.sbprintf(&b, "// ==== %s (class %s) ====\n\n", sec.src_name, label)
        emit_script(&b, sec.script)
    }

    return strings.to_string(b)
}

// Emit the callback-free half of every generated action descriptor. Immediate
// and scheduled execution tables both embed this exact shape; only their
// callback-bearing outer structs differ.
emit_action_metadata :: proc(b: ^strings.Builder, s: ^Script, prefix: string = "") {
    w :: strings.write_string
    snake := prefix != "" ? prefix : decl.snake_name(s.struct_name)

    for c in s.commands {
        if len(c.args) > 0 {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_action_%s_args := [?]knet.Action_Argument_Desc {{\n",
                snake,
                c.name,
            )

            for arg in c.args {
                fmt.sbprintf(
                    b,
                    "\t{{name = %q, type_name = %q, wire_kind = %q}},\n",
                    arg.name,
                    arg.type_text,
                    arg.wire,
                )
            }

            w(b, "}\n\n")
        }

        if len(c.outcomes) > 0 {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_action_%s_outcomes := [?]knet.Action_Outcome_Value_Desc {{\n",
                snake,
                c.name,
            )

            for outcome in c.outcomes {
                fmt.sbprintf(b, "\t{{name = %q, type_name = %q}},\n", outcome.name, outcome.type_text)
            }

            w(b, "}\n\n")
        }
    }
}

emit_action_desc :: proc(b: ^strings.Builder, s: ^Script, c: ^Command_Info, model: string, prefix: string = "") {
    snake := prefix != "" ? prefix : decl.snake_name(s.struct_name)
    upper := strings.to_upper(snake)
    fmt.sbprintf(
        b,
        "action = {{name = %q, id = %s_CMD_%s, model = .%s, policy = %s_POLICY_%s",
        c.name,
        upper,
        strings.to_upper(c.name),
        model,
        upper,
        strings.to_upper(c.name),
    )

    if len(c.args) > 0 {
        fmt.sbprintf(b, ", arguments = _%s_action_%s_args[:]", snake, c.name)
    }

    if len(c.outcomes) > 0 {
        fmt.sbprintf(b, ", outcomes = _%s_action_%s_outcomes[:]", snake, c.name)
    }

    if c.then_proc != "" {
        fmt.sbprintf(
            b,
            ", consequence = {{name = %q, authority_only = true, takes_game = %v}}",
            c.then_proc,
            c.then_game != "",
        )
    }

    strings.write_string(b, "}")
}

// One script's section: everything below the shared header/imports/ctors.
emit_script :: proc(b: ^strings.Builder, s: ^Script) {
    emit_kit_bridges(b, s)
    emit_owner_bindings(b, s)
    emit_replay_view(b, s)
    w :: strings.write_string
    cls := s.struct_name
    snake := decl.snake_name(cls)

    // The recursive canonical ABI was computed before emission. Pin the consumer
    // compiler to those exact widths/alignments: native and wasm may share a
    // fingerprint only when their concrete raw layouts share the bytes too.
    if s.tick.input_code != "" && s.tick.input_abi_size > 0 {
        fmt.sbprintf(
            b,
            "#assert(size_of(%s) == %d && align_of(%s) == %d, \"%s: target layout differs from NET_SCHEMA_CANONICAL; use fixed-width, padding-free fields\")\n",
            s.tick.input_code,
            s.tick.input_abi_size,
            s.tick.input_code,
            s.tick.input_abi_align,
            s.tick.input_code,
        )
    }

    for ic in s.input_classes {
        if ic.abi_size <= 0 {
            continue
        }

        fmt.sbprintf(
            b,
            "#assert(size_of(%s) == %d && align_of(%s) == %d, \"%s: target layout differs from NET_SCHEMA_CANONICAL; use fixed-width, padding-free fields\")\n",
            ic.type_name,
            ic.abi_size,
            ic.type_name,
            ic.abi_align,
            ic.type_name,
        )
    }

    if s.profile_code != "" && s.profile_abi_size > 0 {
        fmt.sbprintf(
            b,
            "#assert(size_of(%s) == %d && align_of(%s) == %d, \"%s: target layout differs from NET_SCHEMA_CANONICAL; use fixed-width, padding-free fields\")\n",
            s.profile_code,
            s.profile_abi_size,
            s.profile_code,
            s.profile_abi_align,
            s.profile_code,
        )
    }

    for m in s.messages {
        if m.abi_size <= 0 {
            continue
        }

        fmt.sbprintf(
            b,
            "#assert(size_of(%s) == %d && align_of(%s) == %d, \"%s: target layout differs from NET_SCHEMA_CANONICAL; use fixed-width, padding-free fields\")\n",
            m.payload_code,
            m.abi_size,
            m.payload_code,
            m.abi_align,
            m.payload_code,
        )
    }

    if s.tick.input_abi_size > 0 || len(s.input_classes) > 0 || s.profile_abi_size > 0 || len(s.messages) > 0 {
        w(b, "\n")
    }

    // ---- lifecycle wrappers (plain proc -> rt.Lifecycle `proc \"c\"`) ----
    for lc in s.lifecycles {
        if lc.keyword == "finalize" {
            continue
        }

        fname := fmt.tprintf("_%s_lc_%s", snake, lc.keyword)

        if lc.keyword == "process" || lc.keyword == "physics_process" {
            fmt.sbprintf(b, "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr, delta: f64) {{\n", fname)
            w(b, "\tcontext = rt.script_context()\n")

            if lc.has_delta {
                fmt.sbprintf(b, "\t%s(cast(^%s)self_raw, delta)\n}}\n\n", lc.proc_name, cls)
            } else {
                fmt.sbprintf(b, "\t%s(cast(^%s)self_raw)\n}}\n\n", lc.proc_name, cls)
            }
        } else {
            fmt.sbprintf(b, "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr) {{\n", fname)
            w(b, "\tcontext = rt.script_context()\n")

            if lc.keyword == "ready" && s.profile_code != "" {
                // gd:"profile=T" — the declaration form of session_profile_install:
                // wired BEFORE the game's ready so a ready that *_starts (role
                // launches do) already has the row type installed. The install's
                // own #asserts hold the POD/size contract against the named type.
                fmt.sbprintf(
                    b,
                    "\tksess.session_profile_install(&(cast(^%s)self_raw).%s, %s) // gd:\"profile\"\n",
                    cls,
                    s.profile_ses,
                    s.profile_code,
                )
            }

            fmt.sbprintf(b, "\t%s(cast(^%s)self_raw)\n}}\n\n", lc.proc_name, cls)
        }
    }

    // Final cleanup is independent of tree exit and of facade overrides.
    has_finalizer := s.kit_stack && !s.kit_cleanup_manual
    final_hook := ""

    for lc in s.lifecycles {
        if lc.keyword == "finalize" {
            has_finalizer = true
            final_hook = lc.proc_name
        }
    }

    if has_finalizer {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_lc_finalize :: proc \"c\" (raw: rawptr) {{\n", snake)
        w(b, "\tcontext = rt.script_context()\n")
        fmt.sbprintf(b, "\tself := cast(^%s)raw\n", cls)

        if final_hook != "" {
            fmt.sbprintf(b, "\t%s(self)\n", final_hook)
        }

        if s.kit_stack && !s.kit_cleanup_manual {
            fmt.sbprintf(
                b,
                "\tkboot.boot_net_destroy(&self.%s, &self.%s, &self.%s",
                s.boot_field,
                s.session_field,
                s.comms_field,
            )

            if s.lane_fields == 1 {
                fmt.sbprintf(b, ", &self.%s", s.lane_field)
            }

            w(b, ")\n")
        }

        w(b, "}\n\n")
    }

    // ---- method trampolines ----
    for m in s.methods {
        emit_method_trampoline(b, s, m)
    }

    // ---- getter/setter wrappers (richer-authoring #4) ----
    for ex in s.exports {
        if ex.getter != "" || ex.setter != "" {
            emit_accessor_wrappers(b, s, ex)
        }
    }

    // ---- typed signal emit helpers ----
    if len(s.signals) > 0 {
        emit_signal_helpers(b, s)
    }

    // ---- backing arrays + registration ----
    emit_registration(b, s)
}

// to_/from_ constructor tag sets needed across all methods.
collect_ctors :: proc(s: ^Script) -> (to_set: [dynamic]string, from_set: [dynamic]string) {
    add :: proc(set: ^[dynamic]string, tag: string) {
        for e in set {
            if e == tag {
                return
            }
        }

        append(set, tag)
    }

    for m in s.methods {
        for a in m.args {
            if a.variant {
                continue
            }

            add(&to_set, ctor_tag(a.vi.enum_name))
        }

        if m.ret.kind != .Nil {
            add(&from_set, ctor_tag(m.ret.enum_name))
        }
    }

    // getter/setter wrappers (richer-authoring #4): a getter marshals field->Variant
    // (from_), a setter marshals Variant->field (to_).
    for ex in s.exports {
        if ex.getter != "" {
            add(&from_set, ctor_tag(ex.vi.enum_name))
        }

        if ex.setter != "" {
            add(&to_set, ctor_tag(ex.vi.enum_name))
        }
    }

    return
}

emit_method_trampoline :: proc(b: ^strings.Builder, s: ^Script, m: Method_Info) {
    w :: strings.write_string
    cls := s.struct_name
    snake := decl.snake_name(cls)
    fname := fmt.tprintf("_%s_m_%s", snake, m.gd_name)

    fmt.sbprintf(b, "// %s(", m.gd_name)

    for a, i in m.args {
        if i > 0 {
            w(b, ", ")
        }

        fmt.sbprintf(b, "%s: %s", a.name, a.type_text)
    }

    w(b, ")")

    if m.ret.kind != .Nil {
        fmt.sbprintf(b, " -> %s", m.ret.enum_name)
    }

    w(b, "\n")

    fmt.sbprintf(
        b,
        "@(private = \"file\")\n%s :: proc \"c\" (self_raw: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr) {{\n",
        fname,
    )

    // Arity guard (dll-boundary defense in depth; the core's inst_call checks too): the
    // unpack below reads exactly this many Variants — a short call must not read past them.
    if len(m.args) > 0 {
        fmt.sbprintf(b, "\tif argc < %d {{return}}\n", len(m.args))
    }

    w(b, "\tcontext = rt.script_context()\n")
    w(b, "\t_ensure_ctors()\n")
    fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)

    // Unpack args.
    call_args := make([dynamic]string)

    for a, i in m.args {
        if a.variant {
            fmt.sbprintf(
                b,
                "\t_a%d: gd.Variant\n\tgdext.variant_new_copy(&_a%d, args[%d])\n\tdefer gd.variant_destroy(&_a%d)\n",
                i,
                i,
                i,
                i,
            )
            append(&call_args, fmt.tprintf("_a%d", i))
            continue
        }

        tag := ctor_tag(a.vi.enum_name)

        switch a.vi.kind {
        case .Int:
            fmt.sbprintf(b, "\t_a%d: i64\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
            append(&call_args, fmt.tprintf("%s(_a%d)", a.type_text, i))
        case .Float:
            fmt.sbprintf(b, "\t_a%d: f64\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
            append(&call_args, fmt.tprintf("%s(_a%d)", a.type_text, i))
        case .Bool:
            fmt.sbprintf(b, "\t_a%d: bool\n\t_to_%s(&_a%d, args[%d])\n", i, tag, i, i)
            append(&call_args, fmt.tprintf("_a%d", i))
        case .Other:
            if strings.trim_space(a.type_text) == "string" {
                fmt.sbprintf(b, "\t_a%d: gd.String\n\t_to_String(&_a%d, args[%d])\n", i, i, i)
                emit_method_release(b, ".String", fmt.tprintf("_a%d", i))
                fmt.sbprintf(b, "\t_s%d := gd.gd_string_to_odin(_a%d, context.temp_allocator)\n", i, i)
                append(&call_args, fmt.tprintf("_s%d", i))
            } else {
                fmt.sbprintf(b, "\t_a%d: %s\n\t_to_%s(&_a%d, args[%d])\n", i, a.type_text, tag, i, i)

                if method_builtin_destructor(a.vi.enum_name) {
                    emit_method_release(b, a.vi.enum_name, fmt.tprintf("_a%d", i))
                }

                append(&call_args, fmt.tprintf("_a%d", i))
            }
        case .Nil:
        }
    }

    // Call the user proc. A composed block method routes into &self.<path>, qualifies the proc with
    // its package, and (if it declared one) passes `self` as the owner; a direct method runs `self`.
    args_joined := strings.join(call_args[:], ", ")
    defer delete(args_joined)
    recv := len(m.path) > 0 ? fmt.tprintf("&self.%s", join_path(m.path)) : "self"
    qual := m.pkg_alias != "" ? fmt.tprintf("%s.", m.pkg_alias) : ""
    prefix := recv

    if m.owner {
        prefix = fmt.tprintf("%s, self", prefix)
    } // the block asked for its wielder

    if len(call_args) > 0 {
        prefix = fmt.tprintf("%s, %s", prefix, args_joined)
    }

    if m.ret.kind == .Nil {
        fmt.sbprintf(b, "\t%s%s(%s)\n", qual, m.proc_name, prefix)
    } else {
        fmt.sbprintf(b, "\t_r := %s%s(%s)\n", qual, m.proc_name, prefix)
        tag := ctor_tag(m.ret.enum_name)

        switch m.ret.kind {
        case .Int:
            fmt.sbprintf(b, "\t_rv := i64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
        case .Float:
            fmt.sbprintf(b, "\t_rv := f64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
        case .Bool, .Other:
            if m.ret_type == "string" {
                w(b, "\t_rv := gd.new_string_odin(_r)\n\tdefer gd.free_string(_rv)\n\t_from_String(ret, &_rv)\n")
            } else {
                if m.owned_return && !m.return_refcounted {
                    emit_method_release(b, m.ret.enum_name, "_r")
                }

                fmt.sbprintf(b, "\t_rv := _r\n\t_from_%s(ret, &_rv)\n", tag)

                if m.return_refcounted {
                    w(
                        b,
                        "\tif _r != nil && gd.ref_counted_unreference(cast(gd.Ref_Counted)_r) {gdext.object_destroy(_r)}\n",
                    )
                }
            }
        case .Nil:
        }
    }

    w(b, "}\n\n")
}

// Getter/setter wrappers (richer-authoring #4). A getter wrapper marshals the author's
// `get_<x>(self) -> V` result into the out-Variant; a setter wrapper unpacks the in-Variant
// into a typed value and calls `set_<x>(self, v)`. These are the proc ptrs the core's
// inst_get/inst_set call instead of raw field access. Marshalling mirrors the method
// trampoline's arg/return conventions.
emit_accessor_wrappers :: proc(b: ^strings.Builder, s: ^Script, ex: Export_Info) {
    w :: strings.write_string
    cls := s.struct_name
    snake := decl.snake_name(cls)
    tag := ctor_tag(ex.vi.enum_name)
    getter_owned, getter_refcounted: bool

    for method in s.methods {
        if method.proc_name == ex.getter {
            getter_owned, getter_refcounted = method.owned_return, method.return_refcounted
        }

    }

    if ex.getter != "" {
        fmt.sbprintf(b, "// getter for @export `%s` -> %s\n", ex.name, ex.getter)
        fmt.sbprintf(
            b,
            "@(private = \"file\")\n_%s_get_%s :: proc \"c\" (self_raw: rawptr, ret: gdext.VariantPtr) {{\n",
            snake,
            ex.name,
        )
        w(b, "\tcontext = rt.script_context()\n")
        w(b, "\t_ensure_ctors()\n")
        fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)
        fmt.sbprintf(
            b,
            "\t_Return_Type :: intrinsics.type_proc_return_type(type_of(%s), 0)\n\t_r := %s(self)\n",
            ex.getter,
            ex.getter,
        )

        switch ex.vi.kind {
        case .Int:
            fmt.sbprintf(b, "\t_rv := i64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
        case .Float:
            fmt.sbprintf(b, "\t_rv := f64(_r)\n\t_from_%s(ret, &_rv)\n", tag)
        case .Bool, .Other:
            if ex.vi.enum_name == ".String" {
                w(
                    b,
                    "\twhen _Return_Type == string {\n\t\t_rv := gd.new_string_odin(_r)\n\t\tdefer gd.free_string(_rv)\n\t\t_from_String(ret, &_rv)\n\t} else {\n",
                )
            }

            if ex.vi.enum_name == ".Object" {
                w(
                    b,
                    "\t#assert(_Return_Type == gd.Object || _Return_Type == gd.Ref_Counted, \"getter must return an engine object handle\")\n",
                )
            } else {
                fmt.sbprintf(
                    b,
                    "\t#assert(_Return_Type == %s, \"getter must return the declared export type\")\n",
                    ex.type_text,
                )
            }

            if getter_owned && !getter_refcounted {
                emit_method_release(b, ex.vi.enum_name, "_r")
            }

            fmt.sbprintf(b, "\t_rv := _r\n\t_from_%s(ret, &_rv)\n", tag)

            if getter_refcounted {
                w(
                    b,
                    "\tif _r != nil && gd.ref_counted_unreference(cast(gd.Ref_Counted)_r) {gdext.object_destroy(_r)}\n",
                )
            }

            if ex.vi.enum_name == ".String" {
                w(b, "\t}\n")
            }
        case .Nil:
        }

        w(b, "}\n\n")
    }

    if ex.setter != "" {
        fmt.sbprintf(b, "// setter for @export `%s` -> %s\n", ex.name, ex.setter)
        fmt.sbprintf(
            b,
            "@(private = \"file\")\n_%s_set_%s :: proc \"c\" (self_raw: rawptr, value: gdext.VariantPtr) {{\n",
            snake,
            ex.name,
        )
        w(b, "\tcontext = rt.script_context()\n")
        w(b, "\t_ensure_ctors()\n")
        fmt.sbprintf(b, "\tself := cast(^%s)self_raw\n", cls)

        switch ex.vi.kind {
        case .Int:
            fmt.sbprintf(b, "\t_v: i64\n\t_to_%s(&_v, value)\n", tag)
            fmt.sbprintf(b, "\t%s(self, %s(_v))\n", ex.setter, ex.type_text)
        case .Float:
            fmt.sbprintf(b, "\t_v: f64\n\t_to_%s(&_v, value)\n", tag)
            fmt.sbprintf(b, "\t%s(self, %s(_v))\n", ex.setter, ex.type_text)
        case .Bool:
            fmt.sbprintf(b, "\t_v: bool\n\t_to_%s(&_v, value)\n", tag)
            fmt.sbprintf(b, "\t%s(self, _v)\n", ex.setter)
        case .Other:
            fmt.sbprintf(b, "\t_v: %s\n\t_to_%s(&_v, value)\n", ex.type_text, tag)

            if method_builtin_destructor(ex.vi.enum_name) {
                emit_method_release(b, ex.vi.enum_name, "_v")
            }

            fmt.sbprintf(b, "\t%s(self, _v)\n", ex.setter)
        case .Nil:
        }

        w(b, "}\n\n")
    }
}

// Typed emit helpers, one per signal FIELD: `<snake>_emit_<field>(self, payload…)`. Thin
// wrappers over the godot package's `gd.emit`/`gd.emit_args` (which own the emit_signal
// MethodBind caching + CallError handling); the value they add is the TYPED signature —
// the field name and payload types are compile-checked at every emit site. The returned
// Error surfaces a misspelled/unregistered signal; callers are free to ignore it.
emit_signal_helpers :: proc(b: ^strings.Builder, s: ^Script) {
    w :: strings.write_string
    cls := s.struct_name
    snake := decl.snake_name(cls)

    w(b, "// ---- typed signal emit helpers (over gd.emit/gd.emit_args) ----\n")

    for sig in s.signals {
        fmt.sbprintf(
            b,
            "// emit the `%s` signal (declared by the %s.%s field) with its payload.\n",
            sig.name,
            cls,
            sig.name,
        )
        fmt.sbprintf(b, "%s_emit_%s :: proc \"contextless\" (self: ^%s", snake, sig.name, cls)

        for a in sig.args {
            fmt.sbprintf(b, ", %s: %s", a.name, a.vi.native)
        }

        w(b, ") -> gd.Error {\n")

        if len(sig.args) == 0 {
            fmt.sbprintf(b, "\treturn gd.emit(self.owner, \"%s\")\n", sig.name)
        } else {
            for a, i in sig.args {
                fmt.sbprintf(b, "\t_v%d := %s\n\t_va%d := gd.variant_from(&_v%d)\n", i, a.name, i, i)
            }

            fmt.sbprintf(b, "\t_err := gd.emit_args(self.owner, \"%s\"", sig.name)

            for i in 0 ..< len(sig.args) {
                fmt.sbprintf(b, ", _va%d", i)
            }

            w(b, ")\n")

            for i in 0 ..< len(sig.args) {
                fmt.sbprintf(b, "\tgdext.variant_destroy(&_va%d)\n", i)
            }

            w(b, "\treturn _err\n")
        }

        w(b, "}\n\n")
    }
}

emit_registration :: proc(b: ^strings.Builder, s: ^Script) {
    w :: strings.write_string
    cls := s.struct_name
    snake := decl.snake_name(cls)

    w(b, "// ---- registration ----\n")

    // Per-export field metadata reflection cannot see: source line, `///` doc, and the
    // getter/setter WRAPPER proc pointers for `get=`/`set=` tags. The Export/Onready
    // tables themselves are built at registration by the runtime reflection walk
    // (rt.register_class -> runtime/register_class.odin).
    if len(s.exports) > 0 {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_fields := [?]rt.Field_Meta {{\n", snake)

        for ex in s.exports {
            fmt.sbprintf(b, "\t{{field = \"%s\", line = %d", ex.name, ex.line)

            if ex.doc != "" {
                // %q — user-authored text can carry quotes/backslashes.
                fmt.sbprintf(b, ", doc = %q", ex.doc)
            }

            if ex.res_class != "" {
                // Hint class derived from the typed resource handle (see parse.odin's
                // object-export block) — the runtime synthesizes resource=<this> from it.
                fmt.sbprintf(b, ", resource_class = \"%s\"", ex.res_class)
            }

            if ex.getter != "" {
                fmt.sbprintf(b, ", getter = _%s_get_%s", snake, ex.name)
            }

            if ex.setter != "" {
                fmt.sbprintf(b, ", setter = _%s_set_%s", snake, ex.name)
            }

            w(b, "},\n")
        }

        w(b, "}\n\n")
    }

    // per-method arg-type arrays
    for m in s.methods {
        if len(m.args) == 0 {
            continue
        }

        fmt.sbprintf(b, "@(private = \"file\")\n_%s_%s_args := [?]gdext.Variant_Type{{", snake, m.gd_name)

        for a, i in m.args {
            if i > 0 {
                w(b, ", ")
            }

            w(b, a.vi.enum_name)
        }

        w(b, "}\n")
    }

    if len(s.methods) > 0 {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_methods := [?]rt.Method {{\n", snake)

        for m in s.methods {
            // C-shaped table: pointer + count into the static per-method arg-type array.
            // An empty arg list stays at the zero value (nil + 0).
            args_ref := ""

            if len(m.args) > 0 {
                args_ref = fmt.tprintf(
                    "arg_types = raw_data(_%s_%s_args[:]), arg_types_count = %d, ",
                    snake,
                    m.gd_name,
                    len(m.args),
                )
            }

            fmt.sbprintf(
                b,
                "\t{{name = \"%s\", trampoline = _%s_m_%s, %sreturn_type = %s}},\n",
                m.gd_name,
                snake,
                m.gd_name,
                args_ref,
                m.ret.enum_name,
            )
        }

        w(b, "}\n\n")
    }

    // (No signal tables: signals are declared by typed struct fields, so the runtime
    // reflection walk builds the rt.Signal tables itself at registration.)

    // connections (@(gd_connect="signal") / @(gd_connect="Path:signal") declarations)
    if len(s.connections) > 0 {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_connections := [?]rt.Connection {{\n", snake)

        for c in s.connections {
            switch {
            case c.indexed:
                fmt.sbprintf(
                    b,
                    "\t{{signal = \"%s\", method = \"%s\", path = \"%s\", indexed = true}},\n",
                    c.signal,
                    c.method,
                    c.path,
                )
            case c.path != "":
                fmt.sbprintf(b, "\t{{signal = \"%s\", method = \"%s\", path = \"%s\"}},\n", c.signal, c.method, c.path)
            case:
                fmt.sbprintf(b, "\t{{signal = \"%s\", method = \"%s\"}},\n", c.signal, c.method)
            }
        }

        w(b, "}\n\n")
    }

    // groups (//gd:group declarations) — joined by the core on READY.
    if len(s.groups) > 0 {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_groups := [?]cstring {{", snake)

        for g, i in s.groups {
            if i > 0 {
                w(b, ", ")
            }

            fmt.sbprintf(b, "%q", g)
        }

        w(b, "}\n\n")
    }

    // rpcs (@(gd_rpc[="..."]) declarations) — per-method multiplayer RPC config.
    if len(s.rpcs) > 0 {
        fmt.sbprintf(b, "@(private = \"file\")\n_%s_rpcs := [?]rt.Rpc {{\n", snake)

        for r in s.rpcs {
            fmt.sbprintf(
                b,
                "\t{{method = \"%s\", mode = %d, transfer = %d, call_local = %v, channel = %d}},\n",
                r.method,
                r.mode,
                r.transfer,
                r.call_local,
                r.channel,
            )
        }

        w(b, "}\n\n")
    }

    emit_entity_replication(b, s, cls, snake)

    emit_entity_commands(b, s, cls, snake)

    // ---- @(gd_message): typed app-message routes, written by nobody ----
    // Each Session stores this instance as the callback context. The generated
    // decoder checks the exact payload size; no mutable route is shared across games.
    // Wiring provides one route per message, a `<class>_messages` proc the generated
    // net facade calls (custom shells call it once), and the send doors. NOT
    // lane-scoped — a coop game and a sim game get these identically
    // (messages ride the session's app router, not a lane).
    if len(s.messages) > 0 {
        w(b, "// ---- @(gd_message) typed app-message routes ----\n\n")

        w(b, "// Register every @(gd_message) route on this class. The generated net facade\n")
        fmt.sbprintf(b, "// calls this; a custom shell calls `%s_messages(self, &self.ses)` once\n", snake)
        w(b, "// after boot_attach. Routes survive *_start.\n")
        fmt.sbprintf(b, "%s_messages :: proc(self: ^%s, s: ^ksess.Session) {{\n", snake, cls)

        for m in s.messages {
            fmt.sbprintf(
                b,
                "\t#assert(%d < ksess.MAX_APP_TAGS, \"%s: message tag exceeds ksess.MAX_APP_TAGS\")\n",
                m.tag_value,
                m.proc_name,
            )
            fmt.sbprintf(
                b,
                "\tksess.session_app_route(s, u8(%d), self, proc(user: rawptr, from: knet.Player_Id, _: ksess.Peer_Id, r: ^knet.Reader) {{\n",
                m.tag_value,
            )
            fmt.sbprintf(
                b,
                "\t\tif r.err || len(knet.reader_remaining(r)) != size_of(%s) {{r.err = true; return}}\n",
                m.payload_code,
            )
            fmt.sbprintf(b, "\t\tmsg := knet.read_pod(r, %s)\n", m.payload_code)
            fmt.sbprintf(b, "\t\t%s(cast(^%s)user, from, msg)\n\t})\n", m.proc_name, cls)
        }

        w(b, "}\n\n")

        for m in s.messages {
            fmt.sbprintf(
                b,
                "// Send a %s under the %q route to `to_peer` (ksess.HOST_PEER, a seated\n",
                m.payload_code,
                m.name,
            )
            w(b, "// peer, or ksess.BROADCAST_PEER); .Reliable unless you pass otherwise.\n")
            fmt.sbprintf(
                b,
                "%s_send :: proc(s: ^ksess.Session, msg: %s, to_peer: ksess.Peer_Id, channel := ksess.Channel.Reliable) {{\n",
                m.proc_name,
                m.payload_code,
            )
            fmt.sbprintf(
                b,
                "\tksess.session_app_send_typed(s, %s, msg, to_peer, channel)\n}}\n\n",
                fmt.tprintf("u8(%d)", m.tag_value),
            )
            fmt.sbprintf(
                b,
                "// Send a %s to a specific PLAYER (the seat is resolved on the authority).\n",
                m.payload_code,
            )
            fmt.sbprintf(
                b,
                "%s_send_to :: proc(s: ^ksess.Session, player: knet.Player_Id, msg: %s) {{\n",
                m.proc_name,
                m.payload_code,
            )
            fmt.sbprintf(
                b,
                "\tksess.session_app_send_typed_to(s, player, %s, msg)\n}}\n\n",
                fmt.tprintf("u8(%d)", m.tag_value),
            )
        }
    }

    // ---- @(gd_event): cooperative reliable presentation -----------------
    // Sim-tracked declarations were lowered into s.facts and are emitted with
    // the lane below. These are the session-clock/static rows: one generated
    // table, one install proc, suffix-free ^Boot doors, and typed decode thunks.
    if len(s.net_events) > 0 {
        w(b, "// ---- @(gd_event) cooperative presentation routes ----\n")

        for e in s.net_events {
            fmt.sbprintf(b, "EVENT_%s :: u16(0x%x)\n", strings.to_upper(e.name), cmd_wire_id(e.name))
        }

        w(b, "\n")

        for e in s.net_events {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_event_%s :: proc(user: rawptr, ses: ^ksess.Session, anchor: knet.Net_Id, mine: bool, args: []u8) {{\n",
                snake,
                e.name,
            )
            fmt.sbprintf(b, "\tself := cast(^%s)user\n\t_ = ses\n", cls)
            non_anchor_refs := len(e.entity_refs)

            if e.anchor_index >= 0 {
                non_anchor_refs -= 1
            }

            if non_anchor_refs > 0 || len(e.arg_names) > 0 {
                w(b, "\tr := knet.reader_make(args)\n")

                for _, i in e.entity_refs {
                    if i == e.anchor_index {
                        continue
                    }

                    fmt.sbprintf(b, "\t_entity_id%d := knet.read_net_id(&r)\n", i)
                }

                for wire, i in e.arg_wires {
                    fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, wire)
                }

                w(b, "\tif r.err || len(knet.reader_remaining(&r)) != 0 {return}\n")
            } else {
                w(b, "\tif len(args) != 0 {return}\n")
            }

            for ref, i in e.entity_refs {
                entity_type := ref.type_code
                id_expr := i == e.anchor_index ? "anchor" : fmt.tprintf("_entity_id%d", i)
                fmt.sbprintf(
                    b,
                    "\t_entity%d_raw, _entity%d_ok := kboot.boot_entity(&self.%s, %s, %s_TYPE)\n\tif !_entity%d_ok {{return}}\n",
                    i,
                    i,
                    s.boot_field,
                    id_expr,
                    strings.to_upper(entity_helper(ref.binding^)),
                    i,
                )
            }

            if e.anchor_index < 0 {
                w(b, "\t_ = anchor\n")
            }

            fmt.sbprintf(b, "\t%s(self", e.fx_proc)

            for ref, i in e.entity_refs {
                entity_type := ref.type_code
                fmt.sbprintf(b, ", cast(^%s)_entity%d_raw", entity_type, i)
            }

            w(b, ", mine")

            for _, i in e.arg_names {
                fmt.sbprintf(b, ", _a%d", i)
            }

            w(b, ")\n}\n\n")

            fmt.sbprintf(b, "%s :: proc(b: ^kboot.Boot", e.name)

            for ref, i in e.entity_refs {
                entity_name := ref.parameter
                fmt.sbprintf(b, ", %s: ^%s", entity_name, ref.type_code)
            }

            for arg_name, i in e.arg_names {
                fmt.sbprintf(b, ", %s: %s", arg_name, e.arg_types[i])
            }

            w(b, ") {\n")
            w(b, "\tif b.ses == nil || !b.ses.is_host {return}\n")

            for ref, i in e.entity_refs {
                entity_name := ref.parameter
                fmt.sbprintf(b, "\tif %s == nil {{return}}\n", entity_name)
                emit_event_kind_guard(b, ref, "b", fmt.tprintf("%s.net_id", entity_name), entity_name, i)
            }

            if len(e.entity_refs) - (e.anchor_index >= 0 ? 1 : 0) > 0 || len(e.arg_names) > 0 {
                w(b, "\tw := knet.writer_make(64, context.temp_allocator)\n")

                for ref, i in e.entity_refs {
                    entity_name := ref.parameter
                    if i == e.anchor_index {
                        continue
                    }

                    fmt.sbprintf(b, "\tknet.write_net_id(&w, %s.net_id)\n", entity_name)
                }

                for arg_name, i in e.arg_names {
                    fmt.sbprintf(b, "\tknet.write_%s(&w, %s)\n", e.arg_wires[i], arg_name)
                }
            }

            anchor_expr := e.anchor_index >= 0 ? fmt.tprintf("%s.net_id", e.anchor_param) : "knet.NET_ID_INVALID"
            args_expr :=
                len(e.entity_refs) - (e.anchor_index >= 0 ? 1 : 0) > 0 || len(e.arg_names) > 0 ? "knet.writer_bytes(&w)" : "nil"
            fmt.sbprintf(
                b,
                "\t_ = ksess.session_net_event_emit(b.ses, EVENT_%s, %s, %s)\n}}\n\n",
                strings.to_upper(e.name),
                anchor_expr,
                args_expr,
            )
        }

        fmt.sbprintf(b, "@(private = \"file\")\n_%s_event_table := [?]ksess.Net_Event_Desc {{\n", snake)

        for e in s.net_events {
            fmt.sbprintf(
                b,
                "\t{{name = %q, id = EVENT_%s, audience = %s, timing = %s, anchored = %v, present = _%s_event_%s}},\n",
                e.name,
                strings.to_upper(e.name),
                net_event_audience_expr(e.audience),
                e.timing == "anchored" ? ".Anchored" : ".Immediate",
                e.anchor_index >= 0,
                snake,
                e.name,
            )
        }

        w(b, "}\n\n")
        fmt.sbprintf(
            b,
            "%s_event_routes :: proc(self: ^%s, ses: ^ksess.Session) {{\n\tksess.session_set_net_events(ses, self, _%s_event_table[:])\n}}\n\n",
            snake,
            cls,
            snake,
        )
    }

    emit_entity_sim(b, s, cls, snake)

    // ---- the standard transport forwards (a kboot.Boot field declares them) ----
    // Bodies for the Method_Info entries resolve_boot_forwards synthesized:
    // the four one-liners every session game used to copy, wired through the
    // boot's own wire/session pointers. Name-dispatched like any method, so
    // they survive hot reload; a hand-written same-name method suppressed the
    // synthesis entirely.
    for name in s.std_forwards {
        switch name {
        case "on_packet":
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_std_on_packet :: proc(self: ^%s, id: gd.Int, packet: gd.Packed_Byte_Array) {{\n\tnetgd.wire_receive(&self.%s.wire, id, packet)\n}}\n\n",
                snake,
                cls,
                s.boot_field,
            )
        case "on_peer_left":
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_std_on_peer_left :: proc(self: ^%s, id: gd.Int) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_peer_disconnected(self.%s.ses, ksess.Peer_Id(id))\n}}\n\n",
                snake,
                cls,
                s.boot_field,
                s.boot_field,
            )
        case "on_net_up":
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_std_on_net_up :: proc(self: ^%s) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_client_join(self.%s.ses)\n}}\n\n",
                snake,
                cls,
                s.boot_field,
                s.boot_field,
            )
        case "on_net_down":
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_std_on_net_down :: proc(self: ^%s) {{\n\tif self.%s.ses == nil {{return}}\n\tksess.session_peer_disconnected(self.%s.ses, ksess.HOST_PEER)\n}}\n\n",
                snake,
                cls,
                s.boot_field,
                s.boot_field,
            )
        }
    }

    // ---- @(gd_sample)/@(gd_step): the lane wiring, written by nobody ----
    // The thunks hold the rawptr casts; `<snake>_lane_init` carries the input
    // size (from the package's tick input struct — resolve_sim pinned the
    // sample to it) and up to two world passes: @(gd_step) runs everywhere,
    // @(gd_step="authority") on the host alone. The generated net facade wraps
    // lane_init + boot_lane for a conventional shell; custom shells may still
    // call both directly. (A
    // boot-routed authority step — s.step_boot — is not lane wiring; its
    // `<snake>_step` is emitted below with the session-event dispatch.)
    if len(s.input_classes) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot) {
        w(b, "// ---- @(gd_sample)/@(gd_step) lane wiring ----\n\n")

        // One typed device-read thunk per input class that has a sample.
        for ic in s.input_classes {
            if ic.sample != "" {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_lane_sample_%d :: proc(user: rawptr, tick: u64, dst: rawptr) {{\n\t%s(cast(^%s)user, tick, cast(^%s)dst)\n}}\n\n",
                    snake,
                    ic.class_id,
                    ic.sample,
                    cls,
                    ic.type_name,
                )
            }

            if ic.validate != "" || len(ic.constraints) > 0 {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_lane_validate_%d :: proc(user: rawptr, input: rawptr) -> bool {{\n\tvalue := cast(^%s)input\n",
                    snake,
                    ic.class_id,
                    ic.type_name,
                )

                for rule in ic.constraints {
                    if rule.finite && !rule.unit {
                        if rule.array_len > 0 {
                            fmt.sbprintf(
                                b,
                                "\tfor component in value.%s {{if !ksim.input_finite(component) {{return false}}}}\n",
                                rule.field,
                            )
                        } else {
                            fmt.sbprintf(b, "\tif !ksim.input_finite(value.%s) {{return false}}\n", rule.field)
                        }
                    }

                    if rule.unit {
                        fmt.sbprintf(b, "\tif !ksim.input_unit(&value.%s) {{return false}}\n", rule.field)
                    }

                    if rule.range_min != "" {
                        if rule.array_len > 0 {
                            fmt.sbprintf(
                                b,
                                "\tfor &component in value.%s {{component = clamp(component, %s, %s)}}\n",
                                rule.field,
                                rule.range_min,
                                rule.range_max,
                            )
                        } else {
                            fmt.sbprintf(
                                b,
                                "\tvalue.%s = clamp(value.%s, %s, %s)\n",
                                rule.field,
                                rule.field,
                                rule.range_min,
                                rule.range_max,
                            )
                        }
                    }

                    if rule.mask != "" {
                        if rule.array_len > 0 {
                            fmt.sbprintf(
                                b,
                                "\tfor component in value.%s {{if component & ~type_of(component)(%s) != 0 {{return false}}}}\n",
                                rule.field,
                                rule.mask,
                            )
                        } else {
                            fmt.sbprintf(
                                b,
                                "\tif value.%s & ~type_of(value.%s)(%s) != 0 {{return false}}\n",
                                rule.field,
                                rule.field,
                                rule.mask,
                            )
                        }
                    }

                    if rule.enum_check {
                        fmt.sbprintf(b, "\tif !ksim.input_enum_valid(value.%s) {{return false}}\n", rule.field)
                    }
                }

                if ic.validate != "" {
                    fmt.sbprintf(b, "\treturn %s(cast(^%s)user, value)\n", ic.validate, cls)
                } else {
                    w(b, "\t_ = user\n\treturn true\n")
                }

                w(b, "}\n\n")
            }
        }

        if s.step.proc_name != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_lane_step :: proc(user: rawptr, tick: u64) {{\n\t%s(cast(^%s)user%s)\n}}\n\n",
                snake,
                s.step.proc_name,
                cls,
                s.step.wants_tick ? ", tick" : "",
            )
        }

        if s.step_auth.proc_name != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_lane_step_auth :: proc(user: rawptr, tick: u64) {{\n\t%s(cast(^%s)user%s)\n}}\n\n",
                snake,
                s.step_auth.proc_name,
                cls,
                s.step_auth.wants_tick ? ", tick" : "",
            )
        }

        step_ref := s.step.proc_name != "" ? fmt.tprintf("_%s_lane_step", snake) : "nil"
        step_auth_ref := s.step_auth.proc_name != "" ? fmt.tprintf("_%s_lane_step_auth", snake) : "nil"
        // The primary class (id 0) rides lane_init + lane_set_sim; extras
        // register after. An inputless lane (no classes) passes size 0 / nil.
        primary_size := "0"
        primary_sample := "nil"

        if len(s.input_classes) > 0 {
            p := s.input_classes[0] // sorted by id: [0] is the primary
            primary_size = fmt.tprintf("size_of(%s)", p.type_name)

            if p.sample != "" {
                primary_sample = fmt.tprintf("_%s_lane_sample_%d", snake, p.class_id)
            }
        }

        fmt.sbprintf(
            b,
            "// The lane beside the session: the input classes, each with its typed\n" +
            "// sample, and up to two world passes (everywhere + authority) — all from\n" +
            "// the attributes. A single-input game registers one class; a game driving\n" +
            "// two entity kinds registers both. cfg tunes; zero = defaults. Each class\n" +
            "// stamps its input TYPE so lane_input_of resolves by type, not size.\n" +
            "%s_lane_init :: proc(self: ^%s, l: ^ksim.Lane, ses: ^ksess.Session, tag := ksim.SIM_TAG, cfg := ksim.Lane_Config{{}}) {{\n" +
            "\tksim.lane_init(l, ses, %s, tag, cfg)\n" +
            "\tksim.lane_set_sim(l, self, %s, %s, %s)\n",
            snake,
            cls,
            primary_size,
            primary_sample,
            step_ref,
            step_auth_ref,
        )

        if len(s.input_classes) > 0 {
            fmt.sbprintf(
                b,
                "\t#assert(%d <= ksim.MAX_INPUT_CLASSES_PER_SEAT, \"generated input classes exceed kit/sim's per-seat admission cap\")\n",
                len(s.input_classes),
            )
        }

        if len(s.input_classes) > 0 && s.input_classes[0].type_name != "" {
            fmt.sbprintf(b, "\tksim.lane_class_set_type(l, 0, typeid_of(%s))\n", s.input_classes[0].type_name)

            if s.input_classes[0].validate != "" || len(s.input_classes[0].constraints) > 0 {
                fmt.sbprintf(b, "\tksim.lane_class_set_validate(l, 0, _%s_lane_validate_0)\n", snake)
            }
        }

        if len(s.input_classes) > 1 {
            for ic in s.input_classes[1:] {
                sample_ref := ic.sample != "" ? fmt.tprintf("_%s_lane_sample_%d", snake, ic.class_id) : "nil"
                fmt.sbprintf(
                    b,
                    "\tksim.lane_add_input_class(l, %d, size_of(%s), %s)\n",
                    ic.class_id,
                    ic.type_name,
                    sample_ref,
                )
                fmt.sbprintf(b, "\tksim.lane_class_set_type(l, %d, typeid_of(%s))\n", ic.class_id, ic.type_name)

                if ic.validate != "" || len(ic.constraints) > 0 {
                    fmt.sbprintf(
                        b,
                        "\tksim.lane_class_set_validate(l, %d, _%s_lane_validate_%d)\n",
                        ic.class_id,
                        snake,
                        ic.class_id,
                    )
                }
            }
        }

        if len(s.facts) > 0 {
            fmt.sbprintf(b, "\tksim.lane_set_facts(l, _%s_fact_table[:])\n", snake)
        }

        w(b, "}\n\n")

        // ---- sim-routed @(gd_event): generated presentation doors ----------
        // The author wrote `<event>_fx`; each door here
        // is the bare `<event>` name the sim calls where it DISCOVERS the event.
        // Every gate lives in the door, so the call site is role-free.
        if len(s.facts) > 0 {
            w(b, "// ---- declared sim presentation events: the announce doors ----\n")
            w(b, "// Stable wire ids — an FNV-1a hash of each event's name, never a position:\n")
            w(b, "// reordering declarations can't renumber the wire.\n")

            for f in s.facts {
                fmt.sbprintf(b, "EVENT_%s :: u16(0x%x)\n", strings.to_upper(f.name), cmd_wire_id(f.name))
            }

            w(b, "\n")

            for f in s.facts {
                fmt.sbprintf(b, "// Announce %q — call it where the sim discovers the event (the world\n", f.name)
                w(b, "// pass, or an authority-only half). The door holds every gate: the\n")
                w(b, "// authority broadcasts to watching screens (they fire on the watch\n")
                w(b, "// clock, beside the delayed avatar), the causer's live pass fires now\n")
                w(b, "// (mine=true), a resim replay never re-fires, and screens with no part\n")

                if f.anchor_index >= 0 {
                    w(b, "// in it stay silent. Announced on a CORPSE (an anchor the game already\n")
                    w(b, "// despawned/untracked) it shows nowhere — not on the wire, not here, not\n")
                    w(b, "// later on a watcher: a fact meant to be seen is announced BEFORE the despawn.\n")
                } else {
                    w(b, "// in it stay silent.\n")
                }

                fmt.sbprintf(b, "%s :: proc(b: ^kboot.Boot", f.name)

                for ref, i in f.entity_refs {
                    entity_name := ref.parameter
                    fmt.sbprintf(b, ", %s: ^%s", entity_name, ref.type_code)
                }

                for a, i in f.arg_names {
                    fmt.sbprintf(b, ", %s: %s", a, f.arg_types[i])
                }

                w(b, ") {\n")
                w(b, "\tif b.lane == nil {return}\n\tl := b.lane\n")

                if f.anchor_index >= 0 {
                    // The corpse gate, FIRST: lane_fact skips the wire for an untracked
                    // anchor and fire_facts drops a filed fact whose anchor died, but the
                    // authority clause below would still present it on the host's own
                    // screen — the one place nobody else sees. Nowhere, consistently.
                    fmt.sbprintf(
                        b,
                        "\tif !ksim.lane_tracks_entity(l, %s) {{\n\t\treturn // a corpse: already untracked — nobody is told, so nobody shows it (the host included)\n\t}}\n",
                        f.anchor_param,
                    )
                }

                for ref, i in f.entity_refs {
                    entity_name := ref.parameter
                    if i == f.anchor_index {
                        continue
                    }

                    fmt.sbprintf(b, "\t_entity_id%d, _entity_ok%d := ksim.lane_entity_id(l, %s)\n", i, i, entity_name)
                    fmt.sbprintf(
                        b,
                        "\tif !_entity_ok%d {{return}} // a typed event ref must still be lane-tracked\n",
                        i,
                    )
                }

                w(b, "\tif ksim.lane_is_authority(l) {\n")
                w(b, "\t\t_fw := knet.writer_make(64, context.temp_allocator)\n")

                for _, i in f.entity_refs {
                    if i == f.anchor_index {
                        continue
                    }

                    fmt.sbprintf(b, "\t\tknet.write_net_id(&_fw, _entity_id%d)\n", i)
                }

                for a, i in f.arg_names {
                    fmt.sbprintf(b, "\t\tknet.write_%s(&_fw, %s)\n", f.arg_wires[i], a)
                }

                anchor_ref := f.anchor_index >= 0 ? f.anchor_param : "nil"
                fmt.sbprintf(
                    b,
                    "\t\tksim.lane_fact(l, %s, knet.writer_bytes(&_fw), EVENT_%s)\n",
                    anchor_ref,
                    strings.to_upper(f.name),
                )
                w(b, "\t}\n")

                if f.anchor_index >= 0 {
                    w(b, "\tif ksim.lane_live(l) {\n")
                    fmt.sbprintf(b, "\t\t_owner := ksim.lane_owner_of(l, %s)\n", f.anchor_param)
                    w(
                        b,
                        "\t\t_mine := (_owner != knet.PLAYER_ID_INVALID && _owner == ksim.lane_me(l)) || (_owner == knet.PLAYER_ID_INVALID && ksim.lane_is_authority(l))\n",
                    )
                    local_condition := "_mine || ksim.lane_is_authority(l)"

                    switch f.audience {
                    case "owner":
                        local_condition = "_mine"
                    case "observers":
                        local_condition = "!_mine && ksim.lane_is_authority(l)"
                    }

                    fmt.sbprintf(b, "\t\tif %s {{\n", local_condition)
                    fmt.sbprintf(b, "\t\t\t%s(cast(^%s)ksim.lane_game(l)", f.fx_proc, cls)

                    for ref in f.entity_refs {
                        entity_name := ref.parameter
                        fmt.sbprintf(b, ", %s", entity_name)
                    }

                    w(b, ", _mine")

                    for a in f.arg_names {
                        fmt.sbprintf(b, ", %s", a)
                    }

                    w(b, ")\n\t\t}\n\t}\n")
                } else if f.audience != "observers" {
                    // Anchorless: the WORLD caused it — the authority's own live
                    // simulation is the causer (mine=true on its screen alone);
                    // every client presents from the broadcast, on the watch clock.
                    w(b, "\tif ksim.lane_is_authority(l) && ksim.lane_live(l) {\n")
                    fmt.sbprintf(b, "\t\t%s(cast(^%s)ksim.lane_game(l)", f.fx_proc, cls)

                    for ref in f.entity_refs {
                        entity_name := ref.parameter
                        fmt.sbprintf(b, ", %s", entity_name)
                    }

                    w(b, ", true")

                    for a in f.arg_names {
                        fmt.sbprintf(b, ", %s", a)
                    }

                    w(b, ")\n\t}\n")
                }

                w(b, "}\n\n")
                // The decode thunk (the lane's fact table): SIM_FACT bytes →
                // typed args → the half, fired when the watch clock arrives.
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_fact_%s :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {{\n",
                    snake,
                    f.name,
                )
                fmt.sbprintf(b, "\tself := cast(^%s)ksim.lane_game(lane)\n\tif self == nil {{return}}\n", cls)
                non_anchor_refs := len(f.entity_refs)

                if f.anchor_index >= 0 {
                    non_anchor_refs -= 1
                }

                if non_anchor_refs > 0 || len(f.arg_names) > 0 {
                    w(b, "\tr := knet.reader_make(args)\n")

                    for _, i in f.entity_refs {
                        if i == f.anchor_index {
                            continue
                        }

                        fmt.sbprintf(b, "\t_entity_id%d := knet.read_net_id(&r)\n", i)
                    }

                    for wr, i in f.arg_wires {
                        fmt.sbprintf(b, "\t_a%d := knet.read_%s(&r)\n", i, wr)
                    }

                    w(b, "\tif r.err || len(knet.reader_remaining(&r)) != 0 {return}\n")
                } else {
                    w(b, "\tif len(args) != 0 {return}\n")
                }

                for _, i in f.entity_refs {
                    if i == f.anchor_index {
                        continue
                    }

                    fmt.sbprintf(b, "\t_entity%d, _entity_ok%d := ksim.lane_entity(lane, _entity_id%d)\n", i, i, i)
                    fmt.sbprintf(
                        b,
                        "\tif !_entity_ok%d {{return}} // the referenced entity despawned before presentation\n",
                        i,
                    )
                }

                if f.anchor_index >= 0 && f.entity_refs[f.anchor_index].binding != nil {
                    w(b, "\t_anchor_id, _anchor_ok := ksim.lane_entity_id(lane, entity)\n\tif !_anchor_ok {return}\n")
                }
                for ref, i in f.entity_refs {
                    id := i == f.anchor_index ? "_anchor_id" : fmt.tprintf("_entity_id%d", i)
                    raw := i == f.anchor_index ? "entity" : fmt.tprintf("_entity%d", i)
                    emit_event_kind_guard(b, ref, fmt.tprintf("&self.%s", s.boot_field), id, raw, i)
                }

                if f.anchor_index < 0 {
                    w(b, "\t_ = entity\n")
                }

                fmt.sbprintf(b, "\t%s(cast(^%s)ksim.lane_game(lane)", f.fx_proc, cls)

                for ref, i in f.entity_refs {
                    entity_type := ref.type_code
                    if i == f.anchor_index {
                        fmt.sbprintf(b, ", cast(^%s)entity", entity_type)
                    } else {
                        fmt.sbprintf(b, ", cast(^%s)_entity%d", entity_type, i)
                    }
                }

                w(b, ", mine")

                for _, i in f.arg_names {
                    fmt.sbprintf(b, ", _a%d", i)
                }

                w(b, ")\n}\n\n")
            }

            fmt.sbprintf(b, "@(private = \"file\")\n_%s_fact_table := [?]ksim.Fact_Desc{{\n", snake)

            for f in s.facts {
                fmt.sbprintf(
                    b,
                    "\t{{id = EVENT_%s, audience = %s, fx = _%s_fact_%s}},\n",
                    strings.to_upper(f.name),
                    net_event_audience_expr(f.audience),
                    snake,
                    f.name,
                )
            }

            w(b, "}\n\n")
        }
    }

    // ---- the BOOT-routed authority step (@(gd_step="authority"), no lane) ----
    // The coop game's fixed step: role gate, tick loop, and the same-frame edge
    // pass in ONE generated proc — the call site is role-free (`<snake>_step(self,
    // ticks)` with boot_pump's ticks, every peer; clients no-op). The edge pass
    // runs HERE because the authored pass mutates after boot_pump's automatic
    // one — a half that MOVES something the next tick reads must not land a
    // frame late (the pass is idempotent: everyone else pays a memcmp).
    if s.step_boot {
        fmt.sbprintf(
            b,
            "// Run this frame's authority steps — %s, `ticks` times, HOST only —\n" +
            "// then fire the authority's fresh edges same-frame. Call it right after\n" +
            "// boot_pump (or wherever your frame wants the world to advance):\n" +
            "//\n" +
            "//   events, marks, ticks := kboot.boot_pump(&self.%s, delta, now)\n" +
            "//   %s_step(self, ticks)\n" +
            "%s_step :: proc(self: ^%s, ticks: int) {{\n" +
            "\tif self.%s.ses == nil || !self.%s.ses.is_host {{return}}\n" +
            "\tfor _ in 0 ..< ticks {{\n" +
            "\t\t%s(self)\n" +
            "\t}}\n" +
            "\tksess.session_run_edges(self.%s.ses)\n" +
            "}}\n\n",
            s.step_auth.proc_name,
            s.boot_field,
            snake,
            snake,
            cls,
            s.boot_field,
            s.boot_field,
            s.step_auth.proc_name,
            s.boot_field,
        )
    }

    // ---- session-event dispatch: the declared halves, switched by nobody ----
    // One generated proc replaces the game shell's event-drain switch: each
    // declared `<game>_<event>` half fires wherever the event fires, and each
    // `_then` half fires on the AUTHORITY alone — the role gates live here,
    // never in game code. Single-role events get their annotation enforced at
    // dispatch too: a (client) event queued just BEFORE a takeover flipped
    // is_host dies at the gate instead of re-running takeover code (the double
    // transport-death signal queues Ev_Succession twice in one batch — the gate
    // is what makes the second one harmless). Call it with boot_pump's events,
    // any frame order you like: `<snake>_events(self, events)`.
    has_succ := s.succ_backup != "" || s.succ_took_over != "" || s.succ_wiped != "" || s.succ_migrating != ""
    has_born := s.embodied != ""

    for e in s.entities {
        if e.born != "" {
            has_born = true
        }
    }

    if len(s.event_halves) > 0 || has_succ || has_born {
        fmt.sbprintf(
            b,
            "// Dispatch this frame's session events to the class's declared halves\n" +
            "// (role gates generated: client-only events skip a host — a takeover\n" +
            "// mid-batch kills the stale re-fire — and `_then` halves fire on the\n" +
            "// authority alone).\n" +
            "%s_events :: proc(self: ^%s, events: []ksess.Event) {{\n",
            snake,
            cls,
        )

        if len(s.event_halves) == 0 && !has_born {
            w(b, "\t_ = events\n")
        } else {
            w(b, "\tfor ev in events {\n\t\t#partial switch e in ev {\n")
        }

        if has_born {
            // THE BORN ARM, typed: Ev_Spawned means the fields are SET — resolve
            // the entity through the census and hand it to its kind's `<t>_born`
            // (the dress every game used to write as a type-switch in its
            // untyped entity_spawned half), then the embodied latch: an AVATAR
            // kind of MINE was born — my spawn, my drop-in, my reconnect
            // reclaiming its standing body. A declared untyped half still runs,
            // after the typed dispatch (merged below into this same arm).
            w(b, "\t\tcase ksess.Ev_Spawned:\n")
            emitted_switch := false

            for e in s.entities {
                if e.born == "" {
                    continue
                }

                tsnake := entity_helper(e)

                if !emitted_switch {
                    w(b, "\t\t\tswitch e.type {\n")
                    emitted_switch = true
                }

                fmt.sbprintf(
                    b,
                    "\t\t\tcase %s_TYPE:\n\t\t\t\tif _e, _ok := kboot.boot_entity(&self.%s, e.id, %s_TYPE); _ok {{\n\t\t\t\t\t%s(self, cast(^%s)_e, e.id, e.owner)\n\t\t\t\t}}\n",
                    strings.to_upper(tsnake),
                    s.boot_field,
                    strings.to_upper(tsnake),
                    e.born,
                    entity_type(e),
                )
            }

            if emitted_switch {
                w(b, "\t\t\t}\n")
            }

            if s.embodied != "" {
                cond := strings.builder_make(context.temp_allocator)

                for e in s.entities {
                    if !e.avatar {
                        continue
                    }

                    if strings.builder_len(cond) > 0 {
                        w(&cond, " || ")
                    }

                    fmt.sbprintf(&cond, "e.type == %s_TYPE", strings.to_upper(entity_helper(e)))
                }

                fmt.sbprintf(
                    b,
                    "\t\t\tif (%s) && self.%s.ses != nil && e.owner == self.%s.ses.me {{\n\t\t\t\t%s(self, e.id)\n\t\t\t}}\n",
                    strings.to_string(cond),
                    s.boot_field,
                    s.boot_field,
                    s.embodied,
                )
            }

            // The declared untyped half, folded into this arm (two case arms on
            // one variant would not compile).
            for h in s.event_halves {
                if SESSION_EVENTS[h.ev].variant != "Ev_Spawned" {
                    continue
                }

                args := strings.builder_make(context.temp_allocator)

                for p in SESSION_EVENTS[h.ev].params {
                    fmt.sbprintf(&args, ", %s", p.field)
                }

                if h.bare != "" {
                    fmt.sbprintf(b, "\t\t\t%s(self%s)\n", h.bare, strings.to_string(args))
                }

                if h.then_proc != "" {
                    fmt.sbprintf(
                        b,
                        "\t\t\tif self.%s.ses != nil && self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
                        s.boot_field,
                        s.boot_field,
                        h.then_proc,
                        strings.to_string(args),
                    )
                }
            }
        }

        for h in s.event_halves {
            if has_born && SESSION_EVENTS[h.ev].variant == "Ev_Spawned" {
                continue
            } // folded into the born arm above

            ev := SESSION_EVENTS[h.ev]
            args := strings.builder_make(context.temp_allocator)

            for p in ev.params {
                fmt.sbprintf(&args, ", %s", p.field)
            }

            fmt.sbprintf(b, "\t\tcase ksess.%s:\n", ev.variant)

            if len(ev.params) == 0 {
                w(b, "\t\t\t_ = e\n")
            }

            switch ev.role {
            case .Every:
                if h.bare != "" {
                    fmt.sbprintf(b, "\t\t\t%s(self%s)\n", h.bare, strings.to_string(args))
                }

                if h.then_proc != "" {
                    fmt.sbprintf(
                        b,
                        "\t\t\tif self.%s.ses != nil && self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
                        s.boot_field,
                        s.boot_field,
                        h.then_proc,
                        strings.to_string(args),
                    )
                }
            case .Client:
                fmt.sbprintf(
                    b,
                    "\t\t\tif self.%s.ses != nil && !self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
                    s.boot_field,
                    s.boot_field,
                    h.bare,
                    strings.to_string(args),
                )
            case .Host:
                fmt.sbprintf(
                    b,
                    "\t\t\tif self.%s.ses != nil && self.%s.ses.is_host {{\n\t\t\t\t%s(self%s)\n\t\t\t}}\n",
                    s.boot_field,
                    s.boot_field,
                    h.bare,
                    strings.to_string(args),
                )
            }
        }

        if len(s.event_halves) > 0 || has_born {
            w(b, "\t\t}\n\t}\n")
        }

        if has_succ {
            // The migration drain: boot_pump only NOTED a succession; the
            // mechanics run here, AFTER the words halves saw the old world.
            fmt.sbprintf(b, "\tkboot.boot_migrate_pending(&self.%s)\n", s.boot_field)
        }

        w(b, "}\n\n")
    }

    // ---- host migration: the declared halves -> kboot.boot_migration's table ----
    // The dance itself is the kit's (kit/boot/succession.odin): the torch on
    // Ev_Backup_Target, the takeover/chase fork, the census-driven wipe, the
    // chase caps and latches. These thunks are the game's four seams.
    if has_succ {
        w(b, "// ---- host migration (the `_backup`/`_took_over`/`_wiped`/`_migrating` halves) ----\n\n")

        if s.succ_backup != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_succ_backup :: proc(game: rawptr, w: ^knet.Writer) {{\n\t%s(cast(^%s)game, w)\n}}\n\n",
                snake,
                s.succ_backup,
                cls,
            )
        }

        if s.succ_took_over != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_succ_took_over :: proc(game: rawptr, r: ^knet.Reader) {{\n\t%s(cast(^%s)game, r)\n}}\n\n",
                snake,
                s.succ_took_over,
                cls,
            )
        }

        if s.succ_wiped != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_succ_wiped :: proc(game: rawptr) {{\n\t%s(cast(^%s)game)\n}}\n\n",
                snake,
                s.succ_wiped,
                cls,
            )
        }

        if s.succ_migrating != "" {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_succ_migrating :: proc(game: rawptr, step: kboot.Migrate_Step, target: string, try: int) {{\n\t%s(cast(^%s)game, step, target, try)\n}}\n\n",
                snake,
                s.succ_migrating,
                cls,
            )
        }

        fmt.sbprintf(
            b,
            "// The migration hook table — the generated net facade installs it. A custom\n" +
            "// shell passes it to kboot.boot_migration(&self.%s, self, %s_succ_hooks)\n" +
            "// in ready, after boot_attach. Arms off the SESSION's backup\n" +
            "// config; the halves only supply bytes and words.\n",
            s.boot_field,
            snake,
        )
        fmt.sbprintf(b, "%s_succ_hooks := kboot.Succ_Hooks {{\n", snake)

        if s.succ_backup != "" {
            fmt.sbprintf(b, "\tbackup = _%s_succ_backup,\n", snake)
        }

        if s.succ_took_over != "" {
            fmt.sbprintf(b, "\ttook_over = _%s_succ_took_over,\n", snake)
        }

        if s.succ_wiped != "" {
            fmt.sbprintf(b, "\twiped = _%s_succ_wiped,\n", snake)
        }

        if s.succ_migrating != "" {
            fmt.sbprintf(b, "\tmigrating = _%s_succ_migrating,\n", snake)
        }

        w(b, "}\n\n")
    }

    // ---- entity kinds: `entity=Name:id` scene fields -> the kboot table ----
    // The tag on the exported PackedScene field is the whole factory
    // declaration: TYPE consts (the wire ids games used to hand-keep), typed
    // rt.script_of thunks, typed spawn/free hook thunks, and one
    // kboot.Entity_Kind row per tag. kit/boot's boot_entities drives it.
    if len(s.entities) > 0 {
        w(b, "// ---- entity kinds (gd:\"...,entity=Name:id\" scene fields) ----\n\n")
        w(b, "// The stable wire ids, named like the hand-kept consts they replace.\n")

        for e in s.entities {
            fmt.sbprintf(b, "%s_TYPE :: ksess.Entity_Type(%d)\n", strings.to_upper(entity_helper(e)), e.type_id)
        }

        w(b, "\n")

        for e in s.entities {
            tsnake := entity_helper(e)
            if len(e.scenes) > 1 {
                fmt.sbprintf(b, "%s :: enum u32 {{\n", entity_variant_type(e))
                for scene in e.scenes {fmt.sbprintf(b, "\t%s = 0x%x,\n", scene.name, scene.id)}
                w(b, "}\n\n")
            }
            fmt.sbprintf(b, "@(private = \"file\")\n_%s_ent_scenes_%s := [?]kboot.Entity_Scene {{\n", snake, tsnake)
            for scene in e.scenes {
                fmt.sbprintf(
                    b,
                    "\t{{variant = ksess.Scene_Variant(0x%x), name = %q, scene_offset = offset_of(%s, %s)}},\n",
                    scene.id,
                    scene.name,
                    cls,
                    scene.field,
                )
            }
            w(b, "}\n\n")
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_ent_make_%s :: proc(node: gd.Node) -> rawptr {{\n\treturn rt.script_of(node, %s)\n}}\n\n",
                snake,
                tsnake,
                entity_type(e),
            )

            if e.spawned != "" {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_ent_spawned_%s :: proc(game: rawptr, entity: rawptr, id: knet.Net_Id, owner: knet.Player_Id) {{\n\t%s(cast(^%s)game, cast(^%s)entity, id, owner)\n}}\n\n",
                    snake,
                    tsnake,
                    e.spawned,
                    cls,
                    entity_type(e),
                )
            }

            if e.freed != "" {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_ent_freed_%s :: proc(game: rawptr, entity: rawptr, id: knet.Net_Id) {{\n\t%s(cast(^%s)game, cast(^%s)entity, id)\n}}\n\n",
                    snake,
                    tsnake,
                    e.freed,
                    cls,
                    entity_type(e),
                )
            }
        }

        fmt.sbprintf(b, "// The factory table — %s_entities(self, &self.boot) installs it (below); the raw\n", snake)
        w(b, "// door is kboot.boot_entities(&self.boot, self, <table>[:], <events>).\n")
        fmt.sbprintf(b, "%s_entity_kinds := [?]kboot.Entity_Kind {{\n", snake)

        for e in s.entities {
            tsnake := entity_helper(e)
            fmt.sbprintf(
                b,
                "\t{{type = %s_TYPE, name = %q, set = &%s_command_set, script_of = _%s_ent_make_%s, scenes = _%s_ent_scenes_%s[:]",
                strings.to_upper(tsnake),
                e.target,
                entity_descriptor_prefix(e),
                snake,
                tsnake,
                snake,
                tsnake,
            )

            if e.spawned != "" {
                fmt.sbprintf(b, ", spawned = _%s_ent_spawned_%s", snake, tsnake)
            }

            if e.freed != "" {
                fmt.sbprintf(b, ", freed = _%s_ent_freed_%s", snake, tsnake)
            }

            if e.has_tick {
                // The class ticks: the row carries its Sim_Set, so boot_lane's
                // factory puts every spawn on the sim lane — no game code.
                fmt.sbprintf(b, ", sim_set = &%s_sim_set", entity_descriptor_prefix(e))
            }

            if e.stream_hz > 0 {
                fmt.sbprintf(b, ", stream_hz = %d", e.stream_hz)
            }

            if e.avatar {
                w(b, ", avatar = true")
            }

            w(b, "},\n")
        }

        w(b, "}\n\n")

        // The install wrapper: the table AND the game's event dispatcher, handed
        // to boot in one typed call — the dispatcher is what lets the AUTHORITY's
        // own spawns be born at the send (boot_born: `<game>_entity_spawned`
        // fires inside boot_spawn_send, not from the next pump's batch). A class
        // that declares no session-event halves has no dispatcher to hand over;
        // it passes nil and keeps the queue path (nothing to dress at born).
        has_events :=
            len(s.event_halves) > 0 ||
            s.succ_backup != "" ||
            s.succ_took_over != "" ||
            s.succ_wiped != "" ||
            s.succ_migrating != "" ||
            s.embodied != ""

        for e in s.entities {
            if e.born != "" {
                has_events = true
            }
        }

        if has_events {
            fmt.sbprintf(
                b,
                "@(private = \"file\")\n_%s_events_thunk :: proc(game: rawptr, events: []ksess.Event) {{\n\t%s_events(cast(^%s)game, events)\n}}\n\n",
                snake,
                snake,
                cls,
            )
        }

        fmt.sbprintf(
            b,
            "// Install the generated entity factory on the boot. The generated net facade calls\n" +
            "// this; a custom shell calls it in ready(), after boot_attach. The kind table plus\n" +
            "// the class's event dispatcher means the authority's own\n" +
            "// spawns are BORN AT THE SEND — `%s_entity_spawned` runs inside\n" +
            "// kboot.boot_spawn_send, before it returns, never a frame later.\n" +
            "%s_entities :: proc(self: ^%s, b: ^kboot.Boot) {{\n" +
            "\tkboot.boot_entities(b, self, %s_entity_kinds[:], %s)\n" +
            "}}\n\n",
            snake,
            snake,
            cls,
            snake,
            has_events ? fmt.tprintf("_%s_events_thunk", snake) : "nil",
        )

        // The typed census — the registry/boot ledgers queried back, so the
        // hand-kept `map[Net_Id]^T` + owner + avatar_of mirrors become the
        // exception (genuinely game-shaped bookkeeping), not the tax. A
        // hand-written proc of the same name suppresses that accessor
        // (resolve_census) and keeps its own meaning.
        for e in s.entities {
            tsnake := entity_helper(e)

            if e.gen_ref || e.gen_of || e.gen_owned || e.gen_mine || e.gen_all || e.gen_despawn || e.gen_teleport {
                fmt.sbprintf(
                    b,
                    "// Census for %s: typed refs, lookup, ownership, and one-pass iteration —\n// no game-side maps or registry casts for the common shape.\n",
                    entity_type(e),
                )
            }

            if e.gen_ref {
                fmt.sbprintf(
                    b,
                    "%s_ref :: proc(id: knet.Net_Id) -> knet.Net_Ref(%s) {{\n\treturn {{id = id}}\n}}\n\n",
                    tsnake,
                    entity_type(e),
                )
            }

            if e.gen_of {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_of_id :: proc(b: ^kboot.Boot, id: knet.Net_Id) -> (^%s, bool) {{\n\te, ok := kboot.boot_entity(b, id, %s_TYPE)\n\treturn cast(^%s)e, ok\n}}\n\n" +
                    "@(private = \"file\")\n_%s_of_ref :: proc(b: ^kboot.Boot, ref: knet.Net_Ref(%s)) -> (^%s, bool) {{\n\te, ok := kboot.boot_entity(b, ref.id, %s_TYPE)\n\treturn cast(^%s)e, ok\n}}\n\n" +
                    "%s_of :: proc {{_%s_of_id, _%s_of_ref}}\n\n",
                    tsnake,
                    entity_type(e),
                    strings.to_upper(tsnake),
                    entity_type(e),
                    tsnake,
                    entity_type(e),
                    entity_type(e),
                    strings.to_upper(tsnake),
                    entity_type(e),
                    tsnake,
                    tsnake,
                    tsnake,
                )
            }

            if e.gen_owned {
                fmt.sbprintf(
                    b,
                    "%s_owned_by :: proc(b: ^kboot.Boot, owner: knet.Player_Id) -> (^%s, bool) {{\n\te, _, ok := kboot.boot_owned_entity(b, %s_TYPE, owner)\n\treturn cast(^%s)e, ok\n}}\n\n",
                    tsnake,
                    entity_type(e),
                    strings.to_upper(tsnake),
                    entity_type(e),
                )
            }

            if e.gen_mine {
                mine_body :=
                    e.gen_owned ? fmt.tprintf("return %s_owned_by(b, b.ses.me)", tsnake) : fmt.tprintf("e, _, ok := kboot.boot_owned_entity(b, %s_TYPE, b.ses.me)\n\treturn cast(^%s)e, ok", strings.to_upper(tsnake), entity_type(e))
                fmt.sbprintf(
                    b,
                    "%s_mine :: proc(b: ^kboot.Boot) -> (^%s, bool) {{\n\t%s\n}}\n\n",
                    tsnake,
                    entity_type(e),
                    mine_body,
                )
            }

            if e.gen_all {
                fmt.sbprintf(
                    b,
                    "%s_all :: proc(b: ^kboot.Boot, allocator := context.temp_allocator) -> []knet.Net_Entity(%s) {{\n\treturn kboot.boot_entity_rows(b, %s_TYPE, %s, allocator)\n}}\n\n",
                    tsnake,
                    entity_type(e),
                    strings.to_upper(tsnake),
                    entity_type(e),
                )
            }

            if e.gen_despawn {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_despawn_id :: proc(b: ^kboot.Boot, id: knet.Net_Id) -> bool {{\n" +
                    "\tif b.ses == nil || !b.ses.is_host {{return false}}\n" +
                    "\tif _, ok := kboot.boot_entity(b, id, %s_TYPE); !ok {{return false}}\n" +
                    "\tksess.session_despawn(b.ses, id)\n\treturn true\n}}\n\n" +
                    "@(private = \"file\")\n_%s_despawn_ref :: proc(b: ^kboot.Boot, ref: knet.Net_Ref(%s)) -> bool {{return _%s_despawn_id(b, ref.id)}}\n\n",
                    tsnake,
                    strings.to_upper(tsnake),
                    tsnake,
                    entity_type(e),
                    tsnake,
                )

                if e.has_net_id {
                    fmt.sbprintf(
                        b,
                        "@(private = \"file\")\n_%s_despawn_ptr :: proc(b: ^kboot.Boot, self: ^%s) -> bool {{return self != nil && _%s_despawn_id(b, self.net_id)}}\n\n" +
                        "%s_despawn :: proc {{_%s_despawn_id, _%s_despawn_ref, _%s_despawn_ptr}}\n\n",
                        tsnake,
                        entity_type(e),
                        tsnake,
                        tsnake,
                        tsnake,
                        tsnake,
                        tsnake,
                    )
                } else {
                    fmt.sbprintf(
                        b,
                        "%s_despawn :: proc {{_%s_despawn_id, _%s_despawn_ref}}\n\n",
                        tsnake,
                        tsnake,
                        tsnake,
                    )
                }
            }

            if e.gen_teleport {
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_teleport_id :: proc(b: ^kboot.Boot, id: knet.Net_Id) -> bool {{\n" +
                    "\tif b.ses == nil {{return false}}\n" +
                    "\tif _, ok := kboot.boot_entity(b, id, %s_TYPE); !ok {{return false}}\n" +
                    "\tksess.session_teleport(b.ses, id)\n\treturn true\n}}\n\n" +
                    "@(private = \"file\")\n_%s_teleport_ref :: proc(b: ^kboot.Boot, ref: knet.Net_Ref(%s)) -> bool {{return _%s_teleport_id(b, ref.id)}}\n\n",
                    tsnake,
                    strings.to_upper(tsnake),
                    tsnake,
                    entity_type(e),
                    tsnake,
                )

                if e.has_net_id {
                    fmt.sbprintf(
                        b,
                        "@(private = \"file\")\n_%s_teleport_ptr :: proc(b: ^kboot.Boot, self: ^%s) -> bool {{return self != nil && _%s_teleport_id(b, self.net_id)}}\n\n" +
                        "%s_teleport :: proc {{_%s_teleport_id, _%s_teleport_ref, _%s_teleport_ptr}}\n\n",
                        tsnake,
                        entity_type(e),
                        tsnake,
                        tsnake,
                        tsnake,
                        tsnake,
                        tsnake,
                    )
                } else {
                    fmt.sbprintf(
                        b,
                        "%s_teleport :: proc {{_%s_teleport_id, _%s_teleport_ref}}\n\n",
                        tsnake,
                        tsnake,
                        tsnake,
                    )
                }
            }

            if e.gen_spawn {
                variant_param :=
                    len(e.scenes) > 1 ? fmt.tprintf(", variant: %s = .Default", entity_variant_type(e)) : ""
                variant_arg := len(e.scenes) > 1 ? ", ksess.Scene_Variant(variant)" : ""
                // The typed spawn — the tag already knows the struct, so the
                // TYPE const and the rawptr cast stop existing at spawn sites.
                // Set the returned entity's fields, then boot_spawn_send(b, id).
                if e.has_tick {
                    fmt.sbprintf(
                        b,
                        "// Typed spawn for %s (ticking: role-routed) — the host mints the real\n" +
                        "// entity, a client a PREDICTED one flying this instant (a fired\n" +
                        "// projectile; the authority's spawn rekeys it). Set the spawn fields,\n" +
                        "// then kboot.boot_spawn_send(b, id).\n" +
                        "%s_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID%s) -> (^%s, knet.Net_Id) {{\n" +
                        "\te, id := kboot.boot_fire_spawn(b, %s_TYPE, owner%s)\n" +
                        "\treturn cast(^%s)e, id\n" +
                        "}}\n\n",
                        entity_type(e),
                        tsnake,
                        variant_param,
                        entity_type(e),
                        strings.to_upper(tsnake),
                        variant_arg,
                        entity_type(e),
                    )
                } else {
                    fmt.sbprintf(
                        b,
                        "// Typed spawn for %s — authority code (clients hear the result as\n" +
                        "// Ev_Spawned). Set the spawn fields, then kboot.boot_spawn_send(b, id).\n" +
                        "%s_spawn :: proc(b: ^kboot.Boot, owner := knet.PLAYER_ID_INVALID%s) -> (^%s, knet.Net_Id) {{\n" +
                        "\tassert(b.ses != nil && b.ses.is_host, \"%s_spawn mints a REAL entity — only the authority spawns\")\n" +
                        "\te, id := ksess.session_spawn_make(b.ses, %s_TYPE, owner%s)\n" +
                        "\treturn cast(^%s)e, id\n" +
                        "}}\n\n",
                        entity_type(e),
                        tsnake,
                        variant_param,
                        entity_type(e),
                        tsnake,
                        strings.to_upper(tsnake),
                        variant_arg,
                        entity_type(e),
                    )
                }
            }
        }
    }

    // ---- generated game-network facade ----------------------------------
    // A conventional shell has one direct Boot, Session, and Comms field; a
    // lane owner has one Lane too. Keep those public (games legitimately read
    // them), but make their routine lifecycle one call. The raw boot/session/
    // lane doors remain available when a game needs custom frame ordering.
    if s.net_attach || s.net_pump || s.net_frame || s.net_detach {
        w(b, "// ---- game-network facade: one attach, one frame pump, one detach ----\n\n")
        net_attach_name := net_facade_name(snake, "attach")
        net_pump_name := net_facade_name(snake, "pump")
        net_frame_name := net_facade_name(snake, "frame")
        net_detach_name := net_facade_name(snake, "detach")
        has_net_lane :=
            len(s.input_classes) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot)
        all_net_inputs_validated := true

        for ic in s.input_classes {
            if ic.validate == "" && len(ic.constraints) == 0 {
                all_net_inputs_validated = false
                break
            }
        }

        has_net_events := len(s.event_halves) > 0 || has_succ || s.embodied != ""

        for e in s.entities {
            if e.born != "" {
                has_net_events = true
            }
        }

        if s.net_attach {
            fmt.sbprintf(
                b,
                "// Attach the complete generated stack. `net_cfg` is a named, validated\n" +
                "// network profile plus any explicit field overrides; zero is Friends_Coop.\n" +
                "// Call once from ready.\n" +
                "@(require_results)\n%s :: proc(self: ^%s, opts: kboot.Options, net_cfg := kboot.Network_Config{{}}) -> bool {{\n",
                net_attach_name,
                cls,
            )
            fmt.sbprintf(
                b,
                "\tassert(self.%s.ses == nil, \"%s called on a live stack — call %s first\")\n",
                s.boot_field,
                net_attach_name,
                net_detach_name,
            )

            if has_net_lane {
                fmt.sbprintf(
                    b,
                    "\tcfg := kboot.network_configure(&self.%s, net_cfg, kboot.Network_Capabilities{{has_lane = true, all_inputs_validated = %s}})\n",
                    s.session_field,
                    all_net_inputs_validated ? "true" : "false",
                )
            } else {
                fmt.sbprintf(b, "\t_ = kboot.network_configure(&self.%s, net_cfg)\n", s.session_field)
            }

            fmt.sbprintf(
                b,
                "\tif !kboot.boot_attach(&self.%s, cast(gd.Node)self.owner, &self.%s, &self.%s, opts) {{return false}}\n",
                s.boot_field,
                s.session_field,
                s.comms_field,
            )

            if len(s.entities) > 0 {
                fmt.sbprintf(b, "\t%s_entities(self, &self.%s)\n", snake, s.boot_field)
            }

            if len(s.messages) > 0 {
                fmt.sbprintf(b, "\t%s_messages(self, &self.%s)\n", snake, s.session_field)
            }

            if len(s.net_events) > 0 {
                fmt.sbprintf(b, "\t%s_event_routes(self, &self.%s)\n", snake, s.session_field)
            }

            if has_net_lane {
                fmt.sbprintf(
                    b,
                    "\t%s_lane_init(self, &self.%s, &self.%s, cfg = cfg.lane)\n" +
                    "\tkboot.boot_lane(&self.%s, &self.%s)\n",
                    snake,
                    s.lane_field,
                    s.session_field,
                    s.boot_field,
                    s.lane_field,
                )
            }

            if has_succ {
                fmt.sbprintf(b, "\tkboot.boot_migration(&self.%s, self, %s_succ_hooks)\n", s.boot_field, snake)
            }

            w(b, "\treturn true\n}\n\n")
        }

        if s.net_pump {
            fmt.sbprintf(
                b,
                "// Pump transport/session/lane and forward every declared session event.\n" +
                "// The returned markers and ticks are the game-shaped work left this frame.\n" +
                "%s :: proc(self: ^%s, delta: f64, now: f64) -> kboot.Net_Frame {{\n" +
                "\tassert(self.%s.ses != nil, \"%s comes after %s\")\n" +
                "\tevents, marks, ticks := kboot.boot_pump(&self.%s, delta, now)\n",
                net_pump_name,
                cls,
                s.boot_field,
                net_pump_name,
                net_attach_name,
                s.boot_field,
            )

            if has_net_events {
                fmt.sbprintf(b, "\t%s_events(self, events)\n", snake)
            } else {
                w(b, "\t_ = events\n")
            }

            w(b, "\treturn {marks = marks, ticks = ticks}\n}\n\n")
        }

        if s.net_frame {
            fmt.sbprintf(
                b,
                "// The common complete frame: pump + event dispatch, then the cooperative\n" +
                "// authority step/edge pass when one is declared. Custom-order games keep\n" +
                "// calling the lower-level pump and step separately.\n" +
                "%s :: proc(self: ^%s, delta: f64, now: f64) -> kboot.Net_Frame {{\n" +
                "\tframe := %s(self, delta, now)\n",
                net_frame_name,
                cls,
                net_pump_name,
            )

            if s.step_boot {
                fmt.sbprintf(b, "\t%s_step(self, frame.ticks)\n", snake)
            }

            w(b, "\treturn frame\n}\n\n")
        }

        if s.net_detach {
            fmt.sbprintf(
                b,
                "// Tear down every network layer in dependency order; idempotent.\n" +
                "%s :: proc(self: ^%s) {{\n" +
                "\tkboot.boot_net_detach(&self.%s)\n" +
                "}}\n\n",
                net_detach_name,
                cls,
                s.boot_field,
            )
        }
    }

    // Generated acid probes — the driver's window into replicated state
    // (resolve_probes): probe_<kind>_<field>(id) with 0 = mine, plus
    // probe_<kind>_count() / probe_my_<kind>(). Registered @(gd_method)s, so
    // driver.gd reads what this peer SEES with no hand-written queries file;
    // a hand-written proc wearing a probe's name suppressed it upstream.
    if len(s.probes) > 0 {
        w(b, "// ---- generated acid probes (the test driver's replicated-state window) ----\n\n")

        for p in s.probes {
            upper_t := strings.to_upper(p.tsnake)

            switch p.form {
            case .Count:
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_%s :: proc(self: ^%s) -> gd.Int {{\n\treturn gd.Int(len(kboot.boot_entity_rows(&self.%s, %s_TYPE, %s)))\n}}\n\n",
                    snake,
                    p.name,
                    cls,
                    s.boot_field,
                    upper_t,
                    p.target,
                )
            case .My:
                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_%s :: proc(self: ^%s) -> gd.Int {{\n\tif self.%s.ses == nil {{return 0}}\n\t_, id, ok := kboot.boot_owned_entity(&self.%s, %s_TYPE, self.%s.ses.me)\n\treturn ok ? gd.Int(id) : 0\n}}\n\n",
                    snake,
                    p.name,
                    cls,
                    s.boot_field,
                    s.boot_field,
                    upper_t,
                    s.boot_field,
                )
            case .Field:
                ret := p.float ? "gd.Float" : "gd.Int"
                value := fmt.tprintf("%s(e.%s)", ret, p.access)

                if p.boolish {
                    value = fmt.tprintf("e.%s ? gd.Int(1) : gd.Int(0)", p.access)
                }

                fmt.sbprintf(
                    b,
                    "@(private = \"file\")\n_%s_%s :: proc(self: ^%s, id: gd.Int) -> %s {{\n" +
                    "\tif self.%s.ses == nil {{return 0}}\n" +
                    "\tnid := knet.Net_Id(id)\n" +
                    "\tif id == 0 {{\n" +
                    "\t\t_, mid, mok := kboot.boot_owned_entity(&self.%s, %s_TYPE, self.%s.ses.me)\n" +
                    "\t\tif !mok {{return 0}}\n" +
                    "\t\tnid = mid\n" +
                    "\t}}\n" +
                    "\traw, ok := kboot.boot_entity(&self.%s, nid, %s_TYPE)\n" +
                    "\tif !ok {{return 0}}\n" +
                    "\te := cast(^%s)raw\n" +
                    "\treturn %s\n" +
                    "}}\n\n",
                    snake,
                    p.name,
                    cls,
                    ret,
                    s.boot_field,
                    s.boot_field,
                    upper_t,
                    s.boot_field,
                    s.boot_field,
                    upper_t,
                    p.target,
                    value,
                )
            }
        }
    }

    // gd:"backup" host-local migration/save codec (version-hashed write/read).
    emit_backup(b, s)

    // Lifecycle literal includes a generated finalizer even without authored hooks.
    lc_lit := strings.builder_make()
    defer strings.builder_destroy(&lc_lit)
    strings.write_string(&lc_lit, "rt.Lifecycle{")
    has_finalizer := s.kit_stack && !s.kit_cleanup_manual

    for lc in s.lifecycles {
        if lc.keyword == "finalize" {
            has_finalizer = true
            continue
        }

        fmt.sbprintf(&lc_lit, "%s = _%s_lc_%s, ", lc.keyword, snake, lc.keyword)
    }

    if has_finalizer {
        fmt.sbprintf(&lc_lit, "finalize = _%s_lc_finalize", snake)
    }

    strings.write_string(&lc_lit, "}")

    // @(init) registration. rt.register_class walks the struct's TYPE INFO (field
    // offsets/sizes/types + the gd:"..." tags) to build the Export/Onready tables at
    // startup; Class_Info carries only what reflection cannot see.
    fmt.sbprintf(b, "@(init)\n_register_%s :: proc \"contextless\" () {{\n", snake)
    fmt.sbprintf(b, "\trt.register_class(\n\t\t%s,\n", cls)
    w(b, "\t\trt.Class_Info {\n")
    fmt.sbprintf(b, "\t\t\tname = %q,\n", s.struct_name)
    fmt.sbprintf(b, "\t\t\tpath = %q,\n", s.resource_path)

    if s.class_name != "" {
        fmt.sbprintf(b, "\t\t\tglobal_name = %q,\n", s.class_name)
    }

    fmt.sbprintf(b, "\t\t\tbase = %q,\n", s.base)

    if len(s.lifecycles) > 0 || has_finalizer {
        fmt.sbprintf(b, "\t\t\tlifecycle = %s,\n", strings.to_string(lc_lit))
    }

    if s.kit_stack {
        w(b, "\t\t\towns_state = true,\n")
    }

    // C-shaped member tables: pointer + count into the static backing arrays above.
    // An absent table stays at the Class_Info zero value (nil + 0).
    if len(s.methods) > 0 {
        fmt.sbprintf(b, "\t\t\tmethods = raw_data(_%s_methods[:]),\n", snake)
        fmt.sbprintf(b, "\t\t\tmethods_count = %d,\n", len(s.methods))
    }

    if len(s.connections) > 0 {
        fmt.sbprintf(b, "\t\t\tconnections = raw_data(_%s_connections[:]),\n", snake)
        fmt.sbprintf(b, "\t\t\tconnections_count = %d,\n", len(s.connections))
    }

    if len(s.groups) > 0 {
        fmt.sbprintf(b, "\t\t\tgroups = raw_data(_%s_groups[:]),\n", snake)
        fmt.sbprintf(b, "\t\t\tgroups_count = %d,\n", len(s.groups))
    }

    if len(s.rpcs) > 0 {
        fmt.sbprintf(b, "\t\t\trpcs = raw_data(_%s_rpcs[:]),\n", snake)
        fmt.sbprintf(b, "\t\t\trpcs_count = %d,\n", len(s.rpcs))
    }

    if len(s.exports) > 0 {
        fmt.sbprintf(b, "\t\t\tfields = raw_data(_%s_fields[:]),\n", snake)
        fmt.sbprintf(b, "\t\t\tfields_count = %d,\n", len(s.exports))
    }

    if s.tool {
        w(b, "\t\t\ttool = true,\n")
    }

    if s.icon != "" {
        fmt.sbprintf(b, "\t\t\ticon = %q,\n", s.icon)
    }

    if s.doc != "" {
        fmt.sbprintf(b, "\t\t\tdoc = %q,\n", s.doc)
    }

    w(b, "\t\t},\n")
    w(b, "\t)\n}\n")
}

# The ScriptLanguageExtension surface (Godot 4.6.2) — implementation reference

This implementation record describes the engine version named above and the
validation/completion work measured during that implementation. Its counts,
timings, and phase references retain that scope. For current script authoring
and editor setup, use [the authoring guide](../authoring-guide.md) and
[Workflow](../workflow.md).

The implementation plan covered three engine interfaces, extracted from the
pinned engine's `extension_api.json` and `gdextension_interface.h`:

- **`ScriptLanguageExtension`** — 60 virtual methods (the language singleton, `OdinLanguage`)
- **`ScriptExtension`** — 37 virtual methods (one per `.odin` resource, `OdinScript`)
- **`GDExtensionScriptInstanceInfo3`** — 26 function pointers (per-node instance dispatch)

The plan assigned each of the 123 entry points a tier: **MUST** (core behavior),
**SHOULD** (editor/tooling polish), or **STUB** (return a safe default — empty list / false /
nil). Phase numbers refer to PLAN.md. Cross-referenced against the miniml_godot reference,
which shipped with a working subset.

> `examples/hello/` verified the registration mechanism. `OdinLanguage` and
> `OdinScript` register as GDExtension classes derived from
> `ScriptLanguageExtension` / `ScriptExtension`. `get_virtual_func` maps each
> virtual name to a function pointer, as in the hello `_process` example.
> The per-instance vtable is passed to `script_instance_create3`.

---

## 1. `GDExtensionScriptInstanceInfo3` — per-node dispatch (the hot path)

Engine lifecycle, method, and signal calls enter Odin through this interface.
`call_func` dispatches method calls.

| fn ptr | tier | phase | notes |
|---|---|---|---|
| `call_func` | **MUST** | 2 | dispatch a method name → registered Odin proc; convert Variant args to typed params. `_process`/`_physics_process`/signal handlers/custom methods all arrive here. |
| `notification_func` | **MUST** | 2 | `NOTIFICATION_READY`(13)/`ENTER_TREE`/`EXIT_TREE`/etc. → lifecycle procs. **`_ready` arrives as a notification, not a call** (miniml: it's deferred a frame). |
| `get_owner_func` | **MUST** | 2 | return the node Object* (stored at instance create). |
| `get_script_func` | **MUST** | 1 | return the `OdinScript` Object*. |
| `get_language_func` | **MUST** | 1 | return the `OdinLanguage` singleton. |
| `free_func` | **MUST** | 2 | free the Odin instance struct + env. |
| `has_method_func` | **MUST** | 2 | does the registered class have this method? |
| `set_func` / `get_func` | **MUST** | 3 | `@export` property write/read (field at offset in the Odin struct). |
| `get_property_list_func` / `free_property_list_func` | **MUST** | 3 | report `@export` vars to Inspector/serializer. |
| `get_property_type_func` | SHOULD | 3 | Variant type of a property. |
| `get_method_list_func` / `free_method_list_func` | SHOULD | 3 | enumerate methods (editor/introspection). |
| `get_method_argument_count_func` | SHOULD | 3 | arg count for a method. |
| `property_can_revert_func` / `property_get_revert_func` | STUB | 3 | default value revert (return false). |
| `validate_property_func` | STUB | 3 | Inspector tweaks (no-op). |
| `to_string_func` | STUB | 6 | `"<OdinScript:Class>"`. |
| `refcount_incremented_func` / `refcount_decremented_func` | STUB | — | for RefCounted-based scripts; default. |
| `is_placeholder_func` | STUB | — | false (we instantiate real). |
| `set_fallback_func` / `get_fallback_func` | STUB | — | dynamic prop fallback (nil). |
| `get_class_category_func` | STUB | — | Inspector grouping (nil). |
| `get_property_state_func` | SHOULD | 3 | serialize live property values (for reload/save). |

---

## 2. `ScriptExtension` — one per `.odin` file (`OdinScript`, 37 virtuals)

| method | tier | phase | notes |
|---|---|---|---|
| `_get_language` | **MUST** | 1 | the `OdinLanguage` singleton. |
| `_can_instantiate` | **MUST** | 1 | true at runtime (false for tool-only in editor unless `@tool`). |
| `_instance_create` | **MUST** | 2 | build a script instance (ScriptInstanceInfo3 + Odin struct) for an owner node. |
| `_get_instance_base_type` | **MUST** | 2 | the `extends` base class name (e.g. `CharacterBody2D`). |
| `_has_source_code` / `_get_source_code` / `_set_source_code` | **MUST** | 1 | the `.odin` text. |
| `_reload` | **MUST** | 4 | recompile + re-bind live instances (hot reload). |
| `_has_method` | **MUST** | 2 | registered class has method? |
| `_is_tool` | **MUST** | 1 | `@tool` scripts run in editor. |
| `_is_valid` | **MUST** | 1 | compiled/registered OK? |
| `_get_script_property_list` | **MUST** | 3 | `@export` vars. |
| `_get_script_signal_list` / `_has_script_signal` | **MUST** | 3 | declared signals. |
| `_get_script_method_list` / `_get_method_info` / `_get_script_method_argument_count` | SHOULD | 3 | method introspection. |
| `_has_property_default_value` / `_get_property_default_value` | SHOULD | 3 | `@export` defaults. |
| `_get_base_script` / `_inherits_script` | SHOULD | 3 | script inheritance chain (likely nil — Odin extends engine classes, not other scripts, at least initially). |
| `_get_global_name` | SHOULD | 3 | `class_name`-equivalent for cross-script typing/autoload. |
| `_has_static_method` | SHOULD | 3 | static methods. |
| `_get_rpc_config` | SHOULD | 5 | multiplayer RPC annotations. |
| `_placeholder_instance_create` / `_placeholder_erased` / `_is_placeholder_fallback_enabled` / `_instance_has` | STUB | — | editor placeholder instances; default. |
| `_editor_can_reload_from_file` | SHOULD | 4 | true (enables editor reload). |
| `_is_abstract` | STUB | — | false. |
| `_get_member_line` | SHOULD | 6 | editor go-to-symbol (via `odin` source map). |
| `_get_constants` / `_get_members` | STUB | — | empty. |
| `_update_exports` | SHOULD | 3 | refresh Inspector after edit. |
| `_get_doc_class_name` / `_get_documentation` / `_get_class_icon_path` | STUB | 6 | docs. |

---

## 3. `ScriptLanguageExtension` — the singleton (`OdinLanguage`, 60 virtuals)

### Identity & registration — MUST (Phase 1)
`_get_name`("Odin"), `_get_type`("OdinScript"), `_get_extension`("odin"),
`_get_recognized_extensions`(["odin"]), `_get_reserved_words`(Odin keywords),
`_get_comment_delimiters`(["//","/* */"]), `_get_string_delimiters`(["\" \"","` `"]),
`_create_script`(→ OdinScript), `_init`, `_finish`, `_make_template`,
`_supports_builtin_mode`(false), `_can_inherit_from_file`(false at first),
`_is_using_templates`, `_get_built_in_templates`.

### Threading — MUST-stub (Phase 2)
`_thread_enter` / `_thread_exit` — set up/tear down the Odin `context` per engine thread
(or assert main-thread-only, like miniml). The resource loader runs off the main thread.

### Reload — Phase 4
`_reload_all_scripts`, `_reload_scripts`, `_reload_tool_script` — drive the recompile+swap.

### Editor tooling — SHOULD (Phase 6)
`_validate` (run `odin check`, map diagnostics to line/col), `_validate_path`, `_lookup_code`,
`_complete_code`, `_auto_indent_code`, `_find_function`, `_make_function`, `_can_make_function`,
`_open_in_external_editor`, `_overrides_external_editor`, `_preferred_file_name_casing`,
`_is_control_flow_keyword`, `_get_doc_comment_delimiters`, `_supports_documentation`,
`_has_named_classes`, `_frame` (miniml used this to register a syntax highlighter on the
editor main thread — deferred because UI isn't ready at init).

> `_lookup_code` (editor "Lookup Symbol") is a stub, but its Dictionary still
> requires both `result` and `type`. `ScriptLanguageExtension::lookup_code`
> executes `ERR_FAIL_COND_V(!ret.has("type"))` even on a failed lookup, so
> returning only `{result}` would log
> `Condition "!ret.has("type")" is true`. `lv_dict_result_failed` returns
> `{result: FAILED, type: LOOKUP_RESULT_SCRIPT_LOCATION(0)}`.

### Global classes / cross-script typing — SHOULD (Phase 3)
`_handles_global_class_type`, `_get_global_class_name` — enables `class_name`-style autoloads
and typed cross-script references (miniml did this via a `modules` project setting).

### STUB (safe defaults — empty/false/nil) unless we add a debugger later
`_get_public_functions`, `_get_public_constants`, `_get_public_annotations`,
`_add_global_constant`, `_add_named_global_constant`, `_remove_named_global_constant`,
all 12 `_debug_*` (stack/locals/expression eval — note: expression eval is impossible in
AOT Odin, so the debugger is structural only), all 5 `_profiling_*`.

---

<a id="key-design-implications"></a>

## Dispatch and registration requirements
1. **`_ready` is a notification, not a method call** — handle `NOTIFICATION_READY` in
   `notification_func`; `_process`/`_physics_process` come through `call_func` after
   `set_process(true)` (set when the registered class defines them).
2. **`@export` get/set work on struct field offsets** captured at registration — this is why
   the registry stores field layout, and why the generator's new *property* rendering
   (in flight) matters for reading/writing engine-side base-class properties.
3. **The whole language is one GDExtension class pair** (`OdinLanguage`/`OdinScript`) plus a
   per-instance vtable — not one classdb class per script. The `examples/hello/` classdb
   path proves the *primitives*; the script path composes them differently.
4. **Most of the 123 entry points are STUBs.** Real work concentrates in ~15 MUST methods:
   instance `call`/`notification`/`set`/`get`/`property_list`, script `instance_create`/
   `source`/`reload`/`base_type`, language identity + `create_script`.

---

## Editor developer-experience features (implemented)

The recorded editor features use the language singleton and run only natively
(`core/validate.odin`, `core/highlighter.odin`, `core/diag/`); the web build gets no-op
stubs (`core/devtools_web.odin`).

<a id="_validate--real-odin-compiler-squiggles"></a>

### `_validate` — compiler diagnostics
`OdinLanguage._validate(script, path, ...)` returns
`{ "valid": bool, "errors": [ { "line", "column", "message" } ] }` driving the editor's
inline error squiggles + the Errors panel.

- **Whole-package check.** A single `.odin` file is not a compile unit, so validation checks its
  package: globalize `path`, take its directory, and run
  `odin check <pkgdir> -collection:godot=<root> -no-entry-point -custom-attribute:gd_method`,
  parsing `‹file›(‹line›:‹col›) Error: ‹msg›` / `Syntax Error:` lines and keeping those whose
  basename matches the validated file. `valid = (errors == 0)`.
- **Unsaved buffer overlay.** `script` (arg 0) is the possibly-unsaved editor text. We copy the
  package dir to a temp overlay, overwrite the one edited file with `script`, then check —
  so errors update as you type, not only on save. The overlay's `*.gen.odin` siblings are
  the last-built ones (stale until the next scriptgen run); existing-code type errors still
  surface correctly.
- **Collection root config.** The `<root>` for `-collection:godot` is resolved as: project
  setting `odin_godot/root` -> env `ODIN_GODOT_ROOT` -> the repo default. **A consuming
  project must point one of these at wherever odin_godot lives.**
- **Tool-failure fallback.** Any failure (can't globalize/copy, `odin` missing, etc.)
  returns `{ valid:true, errors:[] }`.
- **Background validation and cache.** `_validate` runs on the editor's main
  thread after debounced edits. A synchronous `odin check` rechecked the whole
  `godot` binding and blocked the UI for seconds, up to 10-20s cold on a large
  collection. The implementation moved that work to a background thread:
  - The coordinator in `core/diag/async.odin` (`validate_async`) caches completed
    diagnostics by a content hash of `script`+`path`, guarded by `sync.Mutex`.
  - An exact cache hit returns immediately. A miss schedules
    `run_check_overlay` and returns the last completed result. The editor's
    next debounce retrieves updated diagnostics.
  - At most one worker runs, with one latest pending job. New edits replace
    that pending job. The worker uses a private heap+temp-arena context and
    stores `Diagnostic{line,col,message}` data without accessing Godot/gdext
    objects. The main thread resolves the `odin` binary and builds the Godot
    Dictionary. Recorded first-call latency was ~0.03 ms, compared with a
    ~34 ms warm (≈0.5 s cold) check; the main thread did not wait for the check.
  - The experiment also evaluated diagnostics through persistent `ols`.
    Its `src/server/check.odin`, configured by `odin_command` /
    `enable_checker_only_saved`, invoked the same `odin check` on the on-disk
    package. It was not incremental and showed no validation speed gain in
    this setup: the warm check was ~34 ms. `publishDiagnostics` also did not
    reliably arrive on open/change. Validation therefore retained the async
    worker, while persistent `ols` handled autocomplete to avoid indexing
    the `godot` collection on every completion request.
- **Reachability / test.** The virtual is engine-dispatched and cannot be called from GDScript,
  so the overlay/check/parse pipeline and async coordinator live in
  `core/diag/` and are checked by `tests/validate/`: clean fixture -> 0 errors; broken live
  buffer -> 1 error at the exact line/column; the async path is non-blocking (first-call
  latency « check duration), eventually correct (broken still flags after the worker finishes),
  and coalescing (rapid edits keep one worker + one pending). `core/validate.odin` builds the main-thread Godot response.

<a id="_complete_code--autocomplete-backed-by-a-persistent-ols-session"></a>

### `_complete_code` — autocomplete through a persistent `ols` session
`OdinLanguage._complete_code(code, path, owner)` returns
`{ "result": int(Error), "force": bool, "call_hint": String, "options": Array }` (the engine
asserts `result` is present). As the user types, the editor calls it with the full buffer + a
`U+FFFF` caret marker; we drive the `ols` Odin language server over an unsaved-buffer overlay of the
script's package and map its LSP `CompletionItem`s to Godot options (typing `gd.node2d_set_p`
offers `node2d_set_position`, etc.).

- **Required option fields.** Godot's `ScriptLanguageExtension::complete_code`
  (`core/object/script_language_extension.h`, ~L407-420) does `ERR_CONTINUE(!op.has("<key>"))` on
  each of `kind` (int), `display` (String), `insert_text` (String), `font_color` (Color),
  `icon` (Ref<Texture2D>, nil ok), `default_value` (Variant, nil ok), `location` (int) before
  reading it — a missing key drops the option and writes an editor error
  (`Condition "!op.has("font_color")" is true ... at: complete_code (...:413)`). The canonical key
  set is declared in `core/complete/option_shape.odin` (`Completion_Option_Field`); `core/complete.odin`
  builds each option by iterating it (so keys can't drift) and `tests/complete` asserts it covers the
  full required set. `font_color`/`icon` are placeholders here — the editor recomputes the shown
  color/icon in `CodeTextEditor::_complete_request`; only the keys' presence and types matter.

- **Persistent process.** The fresh-spawn path (`run_completion` in
  `core/complete/complete.odin`) starts `ols`, indexes the `godot` collection
  (~1059 files), answers one request, and exits. Recorded latency was
  ~0.5-1.25 s per request. The persistent path
  (`core/complete/session.odin`, `session_complete`) retains one subprocess
  over bidirectional stdio pipes using `core:os`. It performs `initialize`
  and the `ols.json` write once, then sends `didOpen`/`didChange` and
  `textDocument/completion` against the retained index. `tests/lsp` measured
  COLD first completion ~0.67 s and WARM completions ~17-19 ms, a
  ~35-40x speedup for that tested path.
- **Threading.** A dedicated reader thread owns `ols` stdout, parses every `Content-Length`
  frame, and hands the awaited response (correlated by request id) to the caller via a cond var;
  notifications (`logMessage`, `publishDiagnostics`) are ignored. Mutexes guard the single
  in-flight request, stdin writes, the shared session/doc state, and start/teardown. The reader
  runs on a private heap+temp-arena context and does not touch Godot/gdext. `session_complete` blocks the calling thread for the request round-trip
  (warm: tens of ms). The retained index avoids process startup and re-indexing
  on each completion.
- **Failure and timeout handling.** If `ols` can't start, dies, or a request times out, `session_complete`
  returns `ok=false` and the glue (`core/complete.odin`) falls back to fresh-spawn
  `run_completion`, so a failed persistent session can still attempt completion. A killed `ols` is detected
  (reader EOF) and the session restarts on the next call; a short retry backoff prevents
  repeated rapid process launches; a bogus `ols` binary fails in ~8 ms. The warn-once-if-`ols`-missing behavior and
  the `odin_godot/ols_bin` -> `OLS` -> PATH resolution are unchanged. `_finish` (`lv_finish_session`)
  kills the subprocess + reader + temp workspace on editor teardown.
- **Reachability / test.** The virtual is engine-dispatched, and `tests/lsp/` checks the persistent session for COLD vs WARM latency (asserts warm « cold and warm-avg < 300 ms),
  `node2d_set_position` present (generated godot procedures), crash recovery after killing the live `ols`,
  clean shutdown, and the bogus-`ols` fast-fail fallback. `tests/complete/` checks the
  fresh-spawn fallback (`run_completion`).

### Odin syntax highlighter
`OdinSyntaxHighlighter` (extends `EditorSyntaxHighlighter`) token-colors `.odin` in the
Script panel: `_get_name`->"Odin", `_get_supported_languages`->["Odin"] (matched against the
language name), `_create`-> a fresh clone, and `_get_line_syntax_highlighting(line)` ->
`{ start_col(int): { "color": Color } }`. The byte-based, rune-column-accurate tokenizer
covers keywords (control-flow distinct), `//` and single-line `/* */` comments, string/char
/raw-string literals, numbers, PascalCase types, and proc-call identifiers.

- **Deferred registration.** Registered on the first editor `_frame` (guarded by a one-time
  flag + editor-hint check + a ~30s attempt cap), accessing only `ScriptEditor`
  (`register_syntax_highlighter`) and avoiding `EditorHelp`, whose doc-gen paths crash on
  extension classes. The class itself is registered lazily there too, so an exported game
  (no editor) never registers an editor-only class.
- **Limitations.** Block comments are highlighted per-line (an unterminated `/*` colors to
  end-of-line); a `/* ... */` opened on a previous line is not tracked across
  lines. Colors use fixed dark-theme constants; reading them from
  `EditorSettings` remained a possible refinement. Checking the colors
  requires a display. `tests/editor_smoke` verifies registration in a headless
  editor without crashing; it does not check the rendered colors.

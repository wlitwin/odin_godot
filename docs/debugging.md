# Debugging Odin scripts

## What you see when the game crashes (from the editor)

A mistake in script code used to kill the game launched from the editor with **no
indication of what went wrong** — the editor's Output dock shows the child game's output
via Godot's debugger channel (push_error/print over TCP), *not* piped stderr, so anything
that only reached stderr was invisible (and a Finder-launched editor's stderr goes nowhere
at all). Both failure shapes now report themselves:

- **Odin `panic` / failed `assert`** (incl. failed type assertions) — the script context's
  assertion proc ([`runtime/panic_native.odin`](../runtime/panic_native.odin)) prints
  `ODIN_SCRIPT_PANIC <prefix>: <message> (file:line:col)` to stderr **and** push_errors the
  same line, so the **editor Output shows it red**, with the exact script location:

  ```
  ERROR: ODIN_SCRIPT_PANIC panic: no Hud attached (res://scripts/hud.odin:41:2)
  ```

- **Fatal signal** (SIGSEGV/SIGBUS/SIGILL/SIGFPE — the classic: calling an engine method on
  a nil object handle) — a crash reporter ([`core/crash.odin`](../core/crash.odin),
  macOS + Linux; installed only in the *game* process, never the editor) prints to stderr:

  ```
  ODIN_GODOT_CRASH: fatal signal SIGSEGV — crash in native code (Odin script or engine).
  ODIN_GODOT_CRASH at   pc 0x…  my_scripts::take_damage + 0x20  (…/libodinscripts.dylib)
  ODIN_GODOT_CRASH from lr 0x…  my_scripts::[enemy.gen.odin]::_enemy_m_on_hit + 0xac  (…)
  ODIN_GODOT_CRASH backtrace (backtrace_symbols_fd):
  0   libodin_godot.dylib   0x… core::[crash.odin]::crash_handler + 496
  1   libodinscripts.dylib  0x… my_scripts::[enemy.gen.odin]::_enemy_m_on_hit + 172
  2   Godot                 0x… _ZN6Object5callpE… + 184
  …
  ```

  The `at pc` line **names the faulting Odin proc** (pulled from the signal context —
  the stack walkers lose that frame across the signal trampoline). After reporting, it
  best-effort push_errors ONE red line toward the editor Output ("Odin: the game CRASHED
  in native code (SIGSEGV …)") and re-raises into **Godot's own crash handler**, whose
  engine backtrace still prints.

Where to look for the stderr report: launch the editor from a terminal (the child game
inherits its stderr), or run the game headless — test harnesses capture it directly. The
push_error lines are what you see inside the editor GUI.

**Symbolizing** a bare `module + offset` line: the build keeps a `.dSYM` beside the dll —

```sh
atos -o bin/libodinscripts.dylib.dSYM/Contents/Resources/DWARF/libodinscripts.dylib \
     -l <module load address> <pc address>
```

(on Linux: `addr2line -f -e bin/libodinscripts.so <offset>`). Usually unnecessary — the
Odin frames come out symbolized already, as above.

Honest limits: **Windows** crash capture is not implemented (SEH, not signals — script
*panics* still report; only the raw-signal net is missing); Odin **bounds-check** failures
bypass the assertion proc (a separate contextless runtime path) — they print to stderr and
trap, so they surface via the SIGILL/SIGTRAP crash path, without the pretty message; a
**stack-overflow** crash can't run the handler (no sigaltstack); and the mid-crash
push_error may not survive to the editor if the debugger link dies first — stderr always
carries the full report. Verified end-to-end by `tests/crash/run.sh` (sentinel
`CRASH_TEST_OK`).

## The one thing to internalize first

Odin scripts in odin_godot are **AOT-compiled native code** (a `.dylib`/`.so`/`.dll`),
loaded by the engine through the GDExtension boundary. There is **no interpreter**. That
single fact decides which tools work:

| Tool | Works for Odin scripts? |
| --- | --- |
| Godot **in-editor breakpoints** (gutter dots) | ❌ No — no interpreter to halt |
| Godot **step / pause / resume** of script lines | ❌ No |
| Godot **expression evaluation** in the debugger panel | ❌ No |
| Godot **remote scene tree / live property edit** | ✅ Yes (engine-side, not script-line) |
| `gd.print` / `gd.error` / `gd.warn` logging | ✅ Yes — your bread and butter |
| **native `lldb`** (breakpoints, `bt`, inspect memory) | ✅ Yes — full power, this is the real debugger |
| **crash backtraces** (signal 11) with Odin proc names | ✅ Yes — built with `-debug`, symbols present |

The Godot debugger panel is built around GDScript's bytecode VM. Your Odin proc is a
compiled C-ABI function the engine calls through a function pointer; the VM never sees it.
So the workflow is **logging + lldb + reading crash backtraces**, exactly like debugging a
native C library — because that is what a script dll is.

---

## 1. Logging and errors: `gd.print` / `gd.error` / `gd.warn`

Hand-written ergonomic helpers live in [`godot/Ergonomics_Debug.odin`](../godot/Ergonomics_Debug.odin)
(mirrored in `bindgen/upstream/godot/` so they survive binding regeneration). They collapse
the `cstring -> String -> Variant -> gd_*` dance into one call:

```odin
import gd "godot:godot"

gd.print("player ready")          // -> stdout + the editor Output panel
gd.print_int(score)               // i64
gd.print_float(delta)             // f64
gd.print_bool(on_floor)           // bool
gd.print_value(some_variant)      // any Variant, stringified like GDScript print()

gd.warn("coin value was 0, defaulting to 1")   // yellow, non-fatal (push_warning)
gd.error("Hud node missing")      // RED in Output/Debugger, WITH script context (push_error)
```

`gd.error` routes through Godot's `push_error`, so it shows in red in the editor Output and
Debugger **with the originating context**, and is delivered to any attached debugger. Use it
for genuine fault conditions; use `gd.print` for tracing.

### Formatted output

The helpers are deliberately tiny and `contextless`, and do **not** pull in `core:fmt`
(keeping the wasm/web footprint small). For formatted output, format with Odin's `core:fmt`
first, then print:

```odin
import "core:fmt"
import gd "godot:godot"

gd.print(fmt.ctprintf("score=%d at %v", score, self.owner_pos))  // ctprintf -> cstring (temp-allocated)
gd.print_str(fmt.tprintf("hp=%d/%d", hp, max_hp))                // tprintf -> string; print_str takes a string
```

`ctprintf` returns a temp-allocated `cstring` (freed at the next `free_all(context.temp_allocator)`),
which is exactly what `gd.print` wants. `tprintf` returns a temp `string` — pass it to
`gd.print_str` / `gd.error_str` / `gd.warn_str`.

---

## 2. Native debugging with `lldb`

Because the script dll is built with `-debug` (see `build/build_scripts.sh`), every Odin
proc is a real, named symbol with line tables. `nm` shows them:

```
$ nm tests/showcase/bin/libodinscripts.dylib | grep coin_collect
0000000000019…  T _showcase_scripts::coin_collect
```

So lldb debugs them like any C library. Use the launcher:

```bash
tools/lldb-godot.sh coin_collect tests/showcase --headless --script test_showcase.gd
```

then at the `(lldb)` prompt: `run`, and when the breakpoint fires, `bt`, `continue`, etc.

### Two macOS gotchas the launcher handles for you

1. **Breakpoint syntax — use a regex, not the qualified name.** lldb parses `::` as a C++
   qualified name and *fails to bind* `b showcase_scripts::coin_collect` (it stays "pending,
   0 locations"). A **regex** breakpoint binds and fires:

   ```
   (lldb) break set -r coin_collect          # ✅ binds + fires
   (lldb) b showcase_scripts::coin_collect   # ❌ stays pending, never hits
   ```

   The dll is `dlopen`'d at runtime, so the breakpoint is "pending" until Godot loads it —
   that is normal; lldb resolves it automatically on load.

2. **SIP blocks attaching to the installed Godot.** The system Godot is code-signed
   *without* the `get-task-allow` entitlement, so debugserver refuses:

   ```
   error: process exited with status -1 (attach failed (Not allowed to attach to process...))
   ```

   The fix (which `tools/lldb-godot.sh` does automatically, cached, without touching your
   install): make a copy of the Godot binary and ad-hoc re-sign it with `get-task-allow`:

   ```bash
   cp /Applications/Godot.app/Contents/MacOS/Godot /tmp/Godot-dbg
   codesign --remove-signature /tmp/Godot-dbg
   codesign --force --sign - --entitlements get-task-allow.entitlements /tmp/Godot-dbg
   ```

   where the entitlements plist sets `com.apple.security.get-task-allow` to `true`. The
   re-signed binary runs the project fine headless and is debuggable. (Inside the Nix shell,
   `/usr/bin/lldb` is an xcrun shim that breaks because Nix points `DEVELOPER_DIR` at an SDK
   with no lldb; the launcher resets `DEVELOPER_DIR` to a real Xcode/CLT install.)

### A real breakpoint hit (verified)

Running the showcase under lldb and driving a real **physics** coin collect, the breakpoint
fires *inside* the Odin proc with the full native call chain — Odin script frames at the top,
the engine's physics dispatch below:

```
(lldb) break set -r coin_collect
(lldb) run
Process … stopped
* thread #1, stop reason = breakpoint 1.1
    frame #0: libodinscripts.dylib`showcase_scripts::coin_collect
(lldb) bt
* frame #0: libodinscripts.dylib`showcase_scripts::coin_collect
  frame #1: libodinscripts.dylib`showcase_scripts::[coin.gen.odin]::_coin_m_collect + 208
  frame #2: libodin_godot.dylib`core::[instance.odin]::inst_call + 448
  frame #3: Godot`Object::callp(...) + 184
  frame #4: Godot`Object::emit_signalp(...) + 1568
  frame #5: Godot`Area2D::_body_inout(...) + 1268
  frame #6: Godot`GodotSpace2D::call_queries() + 216
  frame #7: Godot`Main::iteration() + 532
  …
```

### Inspecting `self` and arguments

Odin built with `-debug` emits line tables and unwind info, but **limited local-variable
DWARF** — at a function's prologue `frame variable` is often empty. Read arguments from
registers instead. On arm64 macOS the first integer argument (the script instance pointer,
i.e. `self`) is in **`x0`**, the second in `x1`:

```
(lldb) register read x0 x1
     x0 = 0x0000600003f96b60     ; self: ^Coin
     x1 = 0x0000000133926410     ; body: ^Node2d
(lldb) memory read --size 8 --format x --count 4 $x0
0x600003f96b60: 0x0000000133930c10  0x0000000000000005   ; owner=…  value=5
0x600003f96b70: 0x0000000000000000  …                    ; taken=false
```

The fields read straight out in struct order (`owner`, `value`, `taken`) — confirming
`self` points at the live `Coin`. Set a breakpoint a few instructions past the prologue (or
`next` a couple of times) and locals tend to materialize in `frame variable`.

---

## 3. Reading a crash backtrace (signal 11)

When an Odin script segfaults, the process dies with **SIGSEGV (signal 11)**. Because the
dll carries symbols, you get the Odin proc names directly — run the crashing scenario under
lldb (it stops at the fault automatically) and `bt`:

```
Process … stopped
* thread #1, stop reason = EXC_BAD_ACCESS (code=1, address=0x0)
    frame #0: libodinscripts.dylib`my_scripts::take_damage + 44
(lldb) bt
* frame #0: libodinscripts.dylib`my_scripts::take_damage + 44
  frame #1: libodinscripts.dylib`my_scripts::[enemy.gen.odin]::_enemy_m_on_hit + 120
  frame #2: libodin_godot.dylib`core::[instance.odin]::inst_call + 448
  frame #3: Godot`Object::emit_signalp(...) + 1568
  …
```

The top frame (`my_scripts::take_damage + 44`) is the faulting Odin proc; the `+44` is the
byte offset into it. Use `image lookup --address <pc>` for the source line, or `disassemble
--frame` to see the faulting instruction. Without lldb, a crash still prints a native
backtrace to stderr that includes these symbol names — grep it for your package name
(`my_scripts::`).

A no-lldb alternative for repeatable crashes: macOS writes a `.ips` crash report under
`~/Library/Logs/DiagnosticReports/`; its "Thread N Crashed" backtrace contains the same
`libodinscripts.dylib  <pkg>::<proc> + <off>` lines.

---

## 4. Native stack info: `_debug_get_current_stack_info`

`OdinLanguage` implements the `_debug_get_current_stack_info` script-language virtual with a
**real native backtrace** ([`core/debug.odin`](../core/debug.odin)), not an empty stub. When
called it:

1. Walks the native stack with libunwind's **`_Unwind_Backtrace`**.
2. Resolves each return address with **`dladdr`** → `dli_sname` (e.g.
   `showcase_scripts::coin_collect`) + `dli_fname` (the dll path).
3. Keeps only frames that belong to the scripts dll, and returns Godot's expected shape:
   `Array[ Dictionary{ "function": String, "line": int, "source": String } ]`.

### Why `_Unwind_Backtrace`, not `backtrace()`

Odin **omits frame pointers** and has no flag to keep them, so execinfo's classic
frame-pointer `backtrace()` returns only the *innermost* frame here. `_Unwind_Backtrace`
walks the DWARF/compact-unwind tables (the same info lldb uses) and recovers the **full**
chain even with frame pointers omitted. This is verified in `tests/debug/bt_probe.odin`
(`backtrace()` = 1 frame vs `_Unwind_Backtrace` = the whole chain).

### Line numbers are 0

Mapping an address to a source line needs DWARF line-table resolution at runtime (an
`addr2line`/`libdwarf` step) — out of scope. We report `"line": 0` and use the dll path as
`"source"`. The **function name** is accurate; the line is not. (lldb, by contrast, *does*
resolve lines — use it when you need them.)

### ⚠️ Honest limitation: when does this actually surface?

The native capture is **proven to work** (see "Verification" below): called mid-script it
yields the real Odin frames, e.g. `showcase_scripts::coin_collect`. **But** Godot only
*invokes* `_debug_get_current_stack_info` during an **active remote-debug session** — when
`EngineDebugger` is live and reporting an error/breakpoint to a connected debugger.

In a normal headless or editor-play run, the engine **does not call it**, so the Odin stack
does **not** automatically appear in the editor Output on a `gd.error`. We measured this
directly (`tests/debug/run.sh` part C runs the showcase with `ODIN_DEBUG_STACK_DUMP=1` and
observes that the virtual is never called):

```
== (C) integration: does Godot invoke _debug_get_current_stack_info in a normal run? ==
  RESULT: Godot did NOT call _debug_get_current_stack_info in this headless run.
```

So, to be precise about what is and isn't true:

- ✅ The native capture **works** and returns the correct Odin call chain when invoked.
- ✅ The virtual is wired, correctly typed, and returns a well-formed Array (no log spam).
- ❌ It does **not** surface a script-line stack in the editor on a plain error/crash,
  because the engine doesn't request it outside a remote-debug session. **Do not** rely on
  it as your day-to-day stack view — use **lldb `bt`** (section 2/3), which always works.

`backtrace()`/`dladdr` are POSIX-ish and present on darwin/linux. Windows and the web/wasm
build use a stub that returns an empty Array ([`core/debug_other.odin`](../core/debug_other.odin)).

---

## 5. Web / wasm builds

In the browser there is no `dlopen`, no native stack to walk, and no lldb. Debug web builds
with **logging** (`gd.print` → the JS console) and the browser devtools. The native
stack-info capture is stubbed to empty on wasm. See [`docs/exporting.md`](./exporting.md).

---

## Verification

Everything above is exercised by `tests/debug/run.sh` (wired into `tests/run_all.sh`,
sentinel `DEBUG_OK`):

- **(A) unit** — `tests/debug/bt_probe.odin` runs `_Unwind_Backtrace` + `dladdr` + the
  scripts-dll filter over its own call chain (prints `bt_probe::sim_coin_collect | …`) and
  `dlopen`s the **real** showcase dll to confirm `dladdr` reports
  `dli_sname=showcase_scripts::coin_collect`, `dli_fname=…/libodinscripts.dylib`. → `BTPROBE_OK`.
- **(B) lldb** — launches the real Godot under lldb, breaks on `coin_collect`, drives a real
  physics collect so the breakpoint **fires**, asserts `stop reason = breakpoint` + the
  function in `bt`. → `DEBUG_LLDB_OK`. (Gated: skipped if lldb is unavailable.)
- **(C) integration (honest)** — runs the showcase with `ODIN_DEBUG_STACK_DUMP=1` and reports
  whether Godot actually called the virtual (it does not, outside remote-debug).

Run it: `nix develop --command bash -c 'bash tests/debug/run.sh'`.

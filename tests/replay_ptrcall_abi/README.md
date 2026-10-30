# Godot ptrcall ABI regression

The generated public numeric type can be smaller than Godot's pointer-call slot.
Engine integer and enum returns occupy 64 bits, including methods whose API
metadata says `int8`, `int16`, `int32`, `uint32` or `char32`. Enum arguments also
use 64-bit slots even when the public Odin enum is 32 bits on WebAssembly.

The generator preserves public signatures and enum backing types. Engine-call
wrappers convert scalar/enum arguments into ABI-sized temporaries and receive
results into those temporaries before converting to the declared public type.
This avoids exposing undersized storage to Godot's pointer-call interface.

```sh
nix develop --command bash tests/replay_ptrcall_abi/run.sh
python3 tests/replay_ptrcall_abi/audit_test.py
ODIN_EXPORT_OPT=speed nix develop --command bash tests/replay_rtc/run.sh
```

The native fixture passes a guarded, aligned buffer to actual Godot methods and
observes eight written bytes for integer and enum results. It exercises the
generated wrappers with signed/unsigned 8-, 16- and 32-bit extrema, negative Node
priority, and a Node process-mode enum argument/return. The same checks run at
startup in the real RTC browser fixture, where public enum width is four bytes.
The standalone native runner supports macOS and Linux library naming; this
increment's recorded native execution is macOS.

`audit.py` enumerates the current API, checks every affected generated return and
enum argument, and rejects missing coverage. `audit_test.py` mutates disposable
source overlays to reject short/missing/wrong storage and unsafe enum handling.
The live test does not deliberately overrun a four-byte allocation: its 16-byte
canary buffer safely demonstrates the engine's actual write width. The prior
wrapper declarations plus that write width establish the storage mismatch.

The core behavior follows Godot's
[scalar/enum pointer encoding](https://github.com/godotengine/godot/blob/master/core/variant/method_ptrcall.h)
and [method return dispatch](https://github.com/godotengine/godot/blob/master/core/variant/binder_common.h).
A passing ABI regression does not establish multiplayer latency or freshness.

// The WEB-TARGET COMPILE PIN's fixture: a scripts package that force-imports the
// WHOLE shipped Odin surface — every godot:kit/* package plus the core extension,
// play and flowgd — and nothing else.
//
// It exists to be TYPE-CHECKED for freestanding_wasm32 (tests/kitwasm/run.sh), not
// to run. `@(require) import _` links a package for its side effects alone, which is
// exactly the shape build/build_web.sh's generated compose file uses to pull the core
// into a real project's wasm — so a package that only compiles natively is caught
// here, by the same reachability a web export has.
//
// ADD A ROW when a new top-level Odin package ships to users. The kit rows are the
// load-bearing ones: kit code is what a networked game imports, and `core:fmt`'s
// println family (fmt_os.odin, `#+build !freestanding !js !orca`) does not exist on
// this target — so an unguarded `fmt.printfln` anywhere in the kit breaks every
// user's web build while every native suite stays green.
package kitwasm_pin

@(require) import _ "godot:kit/ai"
@(require) import _ "godot:kit/boot"
@(require) import _ "godot:kit/combat"
@(require) import _ "godot:kit/comms"
@(require) import _ "godot:kit/fx"
@(require) import _ "godot:kit/interact"
@(require) import _ "godot:kit/items"
@(require) import _ "godot:kit/nav"
@(require) import _ "godot:kit/net"
@(require) import _ "godot:kit/netcfg"
@(require) import _ "godot:kit/netgd"
@(require) import _ "godot:kit/save"
@(require) import _ "godot:kit/session"
@(require) import _ "godot:kit/sim"
@(require) import _ "godot:kit/steamgd"
@(require) import _ "godot:kit/ui"
@(require) import _ "godot:kit/xfer"

// The rest of what a web side module links: the core GDExtension (its @(export)
// odin_godot_init entry + all registration), the engine-physics helpers, and the
// flow sequencer's Godot adapter.
@(require) import _ "godot:core"
@(require) import _ "godot:play"
@(require) import _ "godot:flowgd"

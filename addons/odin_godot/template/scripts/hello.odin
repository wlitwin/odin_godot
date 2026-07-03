//gd:extends Node
//gd:class Hello
package scripts

// A minimal odin_godot script — your starting point. Once the scripts dll is built,
// `Hello` shows up in Godot's "Attach Script" list; attach it to a Node, press Play,
// and watch the Output panel.
//
// The two `//gd:` markers are required:
//   //gd:extends Node   — the engine base class this script derives from
//   //gd:class Hello    — the class name Godot registers it under
// `hello_ready` is the `_ready` lifecycle hook — odin_godot calls `<class>_ready(self)`
// when the node enters the scene tree. (Other hooks: `<class>_process(self, delta)`, etc.
// — see the authoring guide.)

import gd "godot:godot"

Hello :: struct {
	owner: gd.Node, // the engine Node this script instance is attached to
}

hello_ready :: proc(self: ^Hello) {
	gd.print("Hello from Odin! Edit scripts/hello.odin and press Play again.")
}

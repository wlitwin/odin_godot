package script

// A stand-in for a compiled `.odin` scripts dll. The real one will, on load, run @(init)
// procs that self-register each script's ClassDesc into the core. This spike checks the two
// load-time mechanisms our design relies on:
//   1. @(init) procs RUN ON dlopen (so codegen'd self-registration works with no host call), and
//   2. a fallback explicit init export the core can call if @(init) does NOT auto-run.
// VERSION is build-time configurable so we can build two distinct dlls and swap them in-process.

VERSION :: #config(VERSION, 1)

@(private) g_init_marker: int   // set by @(init); 0 means @(init) never ran
@(private) g_counter:     int   // per-load mutable state; must reset to a fresh value on reload

@(init)
_auto_register :: proc "contextless" () {
	g_init_marker = 0xBEEF
	g_counter = 100
}

// Fallback the host can call explicitly if @(init) didn't fire on dlopen.
@(export)
script_boot :: proc "c" () {
	g_init_marker = 0xBEEF
	g_counter = 100
}

@(export)
get_init_marker :: proc "c" () -> int {
	return g_init_marker
}

@(export)
bump :: proc "c" () -> int {
	g_counter += 1
	return g_counter
}

@(export)
behavior_version :: proc "c" () -> int {
	return VERSION
}

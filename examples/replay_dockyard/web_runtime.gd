extends Node

# Godot's Web loop uses RAF, which stops in hidden tabs. A small timer worker
# wakes that same loop while hidden. All physics still runs in the original
# engine; a frozen/suspended document still cannot renew its hosting lease.
const INSTALL := """
(() => {
    if (globalThis.dockyardWebRuntimeV2) return true;
    const env = typeof engine !== 'undefined' ? engine.rtenv : null;
    if (!env?.MainLoop || typeof env.MainLoop.requestAnimationFrame !== 'function' ||
        typeof env._emscripten_pause_main_loop !== 'function' ||
        typeof env._emscripten_set_main_loop_timing !== 'function' ||
        typeof env._emscripten_resume_main_loop !== 'function') return false;
    const loop = env.MainLoop, originalRAF = loop.requestAnimationFrame;
    const url = URL.createObjectURL(new Blob([
        'onmessage = event => {const id = event.data; setTimeout(() => postMessage(id), 16);};'
    ], {type:'text/javascript'}));
    let worker;
    try {worker = new Worker(url);} finally {URL.revokeObjectURL(url);}
    let stopped = false;
    let serial = 0, pending = null;
    worker.onmessage = event => {
        if (stopped || event.data !== serial || !pending) return;
        const callback = pending; pending = null;
        callback();
    };
    loop.requestAnimationFrame = callback => {
        if (!stopped && document.visibilityState === 'hidden') {
            pending = callback; worker.postMessage(++serial);
        } else originalRAF.call(loop, callback);
    };
    const update = () => {
        if (stopped || !loop.func || !loop.running) return;
        // Invalidate the outstanding callback before waking the same engine
        // loop again. Old RAF callbacks cannot create a second simulation loop.
        ++serial; pending = null;
        env._emscripten_pause_main_loop();
        env._emscripten_set_main_loop_timing(1, 1);
        env._emscripten_resume_main_loop();
    };
    document.addEventListener('visibilitychange', update);
    globalThis.dockyardWebRuntimeV2 = {
        mode() {return document.visibilityState === 'hidden' ? 'worker' : 'raf';},
        close() {
            stopped = true; ++serial; pending = null;
            document.removeEventListener('visibilitychange', update);
            loop.requestAnimationFrame = originalRAF;
            worker.terminate(); worker = null;
            delete globalThis.dockyardWebRuntimeV2;
        }
    };
    if (document.visibilityState === 'hidden') update();
    return true;
})()
"""

func _ready() -> void:
	if OS.has_feature("web") and not bool(JavaScriptBridge.eval(INSTALL, true)):
		push_error("Dockyard Web runtime does not expose the required loop scheduling API.")

func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("globalThis.dockyardWebRuntimeV2?.close()", true)

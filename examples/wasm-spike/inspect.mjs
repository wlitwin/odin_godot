// Inspect + instantiate the Odin SIDE_MODULE standalone, providing the minimal
// Emscripten dynamic-linking imports, then call add(2,3) and sum_to(5).
import { readFileSync } from "node:fs";

const bytes = readFileSync(new URL("./spike.wasm", import.meta.url));
const mod = new WebAssembly.Module(bytes);

console.log("=== IMPORTS ===");
for (const i of WebAssembly.Module.imports(mod)) console.log(`  ${i.module}.${i.name} : ${i.kind}`);
console.log("=== EXPORTS ===");
for (const e of WebAssembly.Module.exports(mod)) console.log(`  ${e.name} : ${e.kind}`);

// Minimal SIDE_MODULE environment: a shared memory/table plus the relocation
// bases the module reads to place its data/functions. For a leaf module with
// no relocations these can be zero.
const memory = new WebAssembly.Memory({ initial: 256, maximum: 256 });
const table = new WebAssembly.Table({ initial: 0, element: "anyfunc" });

const env = {
  memory,
  __indirect_function_table: table,
  __memory_base: 0,
  __table_base: 0,
  __stack_pointer: new WebAssembly.Global({ value: "i32", mutable: true }, 65536),
};
const GOTmem = new Proxy({}, { get: () => new WebAssembly.Global({ value: "i32", mutable: true }, 0) });
const GOTfunc = new Proxy({}, { get: () => new WebAssembly.Global({ value: "i32", mutable: true }, 0) });

const inst = new WebAssembly.Instance(mod, {
  env,
  "GOT.mem": GOTmem,
  "GOT.func": GOTfunc,
  wasi_snapshot_preview1: new Proxy({}, { get: () => () => 0 }),
});

const ex = inst.exports;
if (typeof ex.__wasm_call_ctors === "function") ex.__wasm_call_ctors();
const add = ex.add, sum_to = ex.sum_to;
console.log("=== CALLS ===");
console.log("  add(2,3)   =", add(2, 3));
console.log("  sum_to(5)  =", sum_to(5));

const ok = add(2, 3) === 5 && sum_to(5) === 15;
console.log(ok ? "RESULT: PASS" : "RESULT: FAIL");
process.exit(ok ? 0 : 1);

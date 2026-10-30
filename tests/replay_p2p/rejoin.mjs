import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const [wasm, native] = process.argv.slice(2);
const module = new WebAssembly.Module(readFileSync(wasm));
assert.deepEqual(WebAssembly.Module.imports(module), []);
const {exports: e} = new WebAssembly.Instance(module, {});
const cases = [...readFileSync(native, 'utf8').matchAll(/P2P_REJOIN_CASE seed=(\d+) hash=(\d+)/g)];
assert.equal(cases.length, 4);
for (const [, seed, hash] of cases) {
  assert.equal(BigInt.asUintN(64, e.verify(Number(seed))).toString(), hash);
  console.log(`P2P_REJOIN_TARGET_EQUAL seed=${seed} hash=${hash} restarts=2 seats=3`);
}

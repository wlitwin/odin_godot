import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const [wasmPath, referencePath, target = 'wasm'] = process.argv.slice(2);
const module = new WebAssembly.Module(readFileSync(wasmPath));
assert.deepEqual(WebAssembly.Module.imports(module), [], 'the corpus must not delegate simulation to JavaScript');
const instance = new WebAssembly.Instance(module, {});
const e = instance.exports;
for (const line of readFileSync(referencePath, 'utf8').trim().split('\n')) {
  const [seed, hash, shots, hits, left, right] = line.trim().split(' ');
  const result = BigInt.asUintN(64, e.run_corpus(Number(seed))).toString();
  assert.equal(result, hash, `state/event corpus hash for seed ${seed}`);
  assert.equal(e.shots(), Number(shots)); assert.equal(e.hits(), Number(hits));
  assert.equal(e.kills(0), Number(left)); assert.equal(e.kills(1), Number(right));
  console.log(`DUEL_TARGET_EQUAL target=${target} seed=${seed} hash=${hash} shots=${shots} hits=${hits} kills=${left},${right}`);
}
console.log('REPLAY_DETERMINISTIC_TARGETS_OK');

import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const [wasmPath, directory] = process.argv.slice(2);
const module = new WebAssembly.Module(readFileSync(wasmPath));
assert.deepEqual(WebAssembly.Module.imports(module), [], 'archive replay must execute in WASM');
const {exports: e} = new WebAssembly.Instance(module, {});
for (const line of readFileSync(join(directory, 'recordings.txt'), 'utf8').trim().split('\n')) {
  const [name, error, ...fields] = line.split(' ');
  const bytes = readFileSync(join(directory, `${name}.rply`));
  new Uint8Array(e.memory.buffer, e.input_address(), bytes.length).set(bytes);
  assert.equal(e.verify(bytes.length), Number(error), `${name}: status`);
  fields.forEach((value, index) => assert.equal(BigInt.asUintN(64, e.field(index)).toString(), value, `${name}: field ${index}`));
  console.log(`DUEL_ARCHIVE_TARGET_EQUAL recording=${name} bytes=${bytes.length} error=${error} head=${fields[2]} mismatch_tick=${fields[5]}`);
  const view = new Uint8Array(e.memory.buffer, e.input_address(), bytes.length);
  view[bytes.length - 1] ^= 1;
  assert.equal(e.verify(bytes.length), e.invalid_error(), `${name}: corruption must fail`);
}
console.log('REPLAY_P2P_ARCHIVE_TARGETS_OK');

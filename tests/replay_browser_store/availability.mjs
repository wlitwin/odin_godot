import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const file=new URL('../../replay/godot/browser_store.odin',import.meta.url);
const source=fs.readFileSync(file,'utf8').match(/BROWSER_STORE_JS :: `([\s\S]*?)`/)[1];
assert.equal(vm.runInNewContext(source,{}),0);
const denied={};Object.defineProperty(denied,'indexedDB',{get(){throw new Error('SecurityError');}});
assert.equal(vm.runInNewContext(source,denied),0);
console.log('REPLAY_BROWSER_STORE_AVAILABILITY_OK');

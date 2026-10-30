import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1],m[2]]));
const rows = ['host','client','observer'].map(role => {
  const log = readFileSync(`${process.argv[2]}/${role}.log`, 'utf8');
  assert.match(log, /REPLAY_SCRAPYARD_COMBAT_PEER_OK/);
  const result = fields(log.match(/^RSY_REVIVE_RESULT .+$/m)[0]);
  assert.equal(result.revives, '1'); assert.ok(Number(result.hp1)>0 && Number(result.hp2)>0);
  return fields(log.match(/^RSY_COMBAT_HASH .+$/m)[0]);
});
for (const row of rows) for (const key of ['tick','hash']) assert.equal(row[key], rows[0][key]);
console.log(`RSY_REVIVE_CHECK_OK tick=${rows[0].tick} hash=${rows[0].hash}`);

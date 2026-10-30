import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const rows = ['host', 'client', 'observer'].map(role => {
  const log = readFileSync(`${process.argv[2]}/${role}.log`, 'utf8');
  assert.match(log, /REPLAY_SCRAPYARD_ARENA_PEER_OK/);
  const result = fields(log.match(/^RSY_ARENA_RESULT .+$/m)[0]);
  const arena = fields(log.match(/^RSY_ARENA .+$/m)[0]);
  assert.equal(result.d1, '1'); assert.equal(result.d2, '1'); assert.equal(result.players, '2');
  assert.equal(result.effects, '2');
  return {result, arena};
});
for (const row of rows) {
  assert.deepEqual(row.arena, rows[0].arena);
  for (const key of ['x1', 'x2']) assert.ok(Math.abs(Number(row.result[key]) - Number(rows[0].result[key])) <= 1, key);
}
console.log(`RSY_CHECK_OK sum=${rows[0].arena.sum} x1=${rows[0].result.x1} x2=${rows[0].result.x2}`);

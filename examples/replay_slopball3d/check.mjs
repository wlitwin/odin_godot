import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const results = ['host', 'client', 'observer'].map(role => {
  const log = readFileSync(join(process.argv[2], `${role}.log`), 'utf8');
  assert.match(log, /REPLAY_SLOPBALL3D_PEER_OK/);
  const matches = [...log.matchAll(/^RS3_RESULT .+$/gm)]; assert.equal(matches.length, 1);
  const result = fields(matches[0][0]);
  assert.ok(Number(result.handoffs) > 0, `${role}: owner transfer`);
  assert.ok(Number(result.peak_y) > 0.23 && Number(result.peak_spin) > 0.1, `${role}: loft and tumble`);
  assert.equal(result.goals, '1', `${role}: one goal occurrence`);
  return result;
});
for (const result of results) {
  for (const key of ['owner', 'revision', 'left', 'right', 'won', 'handoffs']) assert.equal(result[key], results[0][key], key);
  assert.ok(Math.hypot(Number(result.x) - Number(results[0].x), Number(result.y) - Number(results[0].y), Number(result.z) - Number(results[0].z)) < 0.1, 'settled ball convergence');
}
assert.equal(results[1].owner, results[1].seat, 'striker owns the ball');
assert.ok(Number(results[1].kicks) > 0, 'client solver kicked');
assert.equal(results[1].won, '2', 'client team scored');
console.log(`RS3_CHECK_OK owner=${results[0].owner} won=${results[0].won} handoffs=${results[0].handoffs}`);

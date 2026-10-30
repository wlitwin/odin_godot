import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const results = ['host', 'client', 'observer'].map(role => {
  const log = readFileSync(join(process.argv[2], `${role}.log`), 'utf8');
  assert.match(log, /REPLAY_SLOPBALL_PEER_OK/);
  const matches = [...log.matchAll(/^RSL_RESULT .+$/gm)]; assert.equal(matches.length, 1);
  const result = fields(matches[0][0]);
  assert.ok(Number(result.handoffs) > 0, `${role}: owner transfer`);
  assert.equal(result.goals, '1', `${role}: one goal occurrence`);
  return result;
});
for (const result of results) {
  for (const key of ['owner', 'revision', 'left', 'right', 'won', 'handoffs']) assert.equal(result[key], results[0][key], key);
  assert.ok(Math.hypot(Number(result.x) - Number(results[0].x), Number(result.y) - Number(results[0].y)) < 4, 'settled ball convergence');
}
assert.equal(results[1].owner, results[1].seat, 'striker owns the ball');
assert.ok(Number(results[1].kicks) > 0, 'client solver kicked');
assert.equal(results[1].won, '2', 'client team scored');
console.log(`RSL_CHECK_OK owner=${results[0].owner} won=${results[0].won} handoffs=${results[0].handoffs}`);

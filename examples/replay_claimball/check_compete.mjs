import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const directory = process.argv[2];
function log(role) { return readFileSync(`${directory}/${role}.log`, 'utf8'); }
function row(role, prefix) {
  const lines = log(role).split('\n').filter(line => line.startsWith(prefix + ' '));
  assert.equal(lines.length, 1, `${role}: ${prefix}`);
  return Object.fromEntries([...lines[0].matchAll(/(\w+)=(-?\d+(?:\.\d+)?)/g)].map(([, k, v]) => [k, Number(v)]));
}
const roles = ['server', 'striker', 'challenger', 'observer'];
const results = roles.map(role => row(role, 'RCB_RESULT'));
const authority = results[0];
assert.ok(authority.tick >= 2520);
for (const [index, role] of roles.entries()) {
  assert.ok(log(role).includes('REPLAY_CLAIMBALL_PROCESS_OK'));
  for (const key of ['left', 'right', 'winner', 'kicks', 'spikes']) assert.equal(results[index][key], authority[key], `${role}: ${key}`);
  assert.ok(Math.abs(results[index].vx) < 0.01 && Math.abs(results[index].vy) < 0.01, 'ball must settle after inputs stop');
  assert.ok(Math.abs(results[index].x - authority.x) < 0.1 && Math.abs(results[index].y - authority.y) < 0.1, `${role}: settled pose`);
}
const kicksBySeat = [1, 2].map(seat => [...log('server').matchAll(new RegExp(`RCB_KICK seat=${seat} tick=`, 'g'))].length);
for (const [index, role] of ['striker', 'challenger'].entries()) {
  assert.ok(kicksBySeat[index] > 0, `${role} must actually kick on authority`);
  const result = results[index + 1];
  assert.ok(result.speculative_kicks > 0);
  assert.equal(result.local_kicks - result.local_canceled, kicksBySeat[index], `${role}: local reconciliation`);
  assert.equal(result.remote_kicks, kicksBySeat[1 - index], `${role}: remote effects`);
  const group = row(role, 'RCB_GROUP');
  assert.equal(group.predicted_members, 1); assert.equal(group.max_claim, 1);
  assert.ok(group.predicted_samples > 0 && group.watched_samples > 0);
  assert.ok(group.predicted_error < 0.001 && group.watched_error < 0.001);
  assert.ok(row(role, 'RCB_CONTEST').remote_kicks_while_claimed > 0, `${role}: competing claim interaction`);
  const profile = row(role, 'RCB_PROFILE');
  assert.ok(profile.samples > 0 && profile.total_us > 0 && profile.max_depth > 0);
  assert.equal(profile.clock_errors, 0);
}
assert.equal(results[3].remote_kicks, authority.kicks);
if (process.env.RCB_REQUIRE_FAULTS === '1') {
  const faults = roles.map(role => row(role, 'RCB_CONTEST'));
  assert.ok(faults.reduce((sum, row) => sum + row.dropped, 0) > 0, 'loss injection must execute');
  assert.ok(faults.reduce((sum, row) => sum + row.duplicated, 0) > 0, 'duplication injection must execute');
}
console.log(`RCB_COMPETE_CHECK_OK kicks=${kicksBySeat.join(',')} score=${authority.left}-${authority.right}`);

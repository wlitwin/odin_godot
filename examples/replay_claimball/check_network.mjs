import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const directory = process.argv[2];
function log(role) { return readFileSync(`${directory}/${role}.log`, 'utf8'); }
function row(role, prefix) {
  const lines = log(role).split('\n').filter(line => line.startsWith(prefix + ' '));
  assert.equal(lines.length, 1, `${role}: ${prefix}`);
  return Object.fromEntries([...lines[0].matchAll(/(\w+)=(-?\d+(?:\.\d+)?)/g)].map(([, k, v]) => [k, Number(v)]));
}
const roles = ['server', 'striker', 'idle', 'observer'];
const results = roles.map(role => row(role, 'RCB_RESULT'));
for (const [i, result] of results.entries()) {
  assert.ok(log(roles[i]).includes('REPLAY_CLAIMBALL_PROCESS_OK'));
  assert.equal(result.left, 0); assert.equal(result.right, 1); assert.equal(result.winner, 2);
  assert.equal(result.x, 320); assert.equal(result.y, 180);
  assert.equal(result.kicks, results[0].kicks); assert.equal(result.spikes, 0);
}
assert.ok(results[1].speculative_kicks > 0);
assert.equal(results[1].local_kicks - results[1].local_canceled, results[0].kicks);
for (const index of [2, 3]) assert.equal(results[index].remote_kicks, results[0].kicks);
const striker = row('striker', 'RCB_GROUP');
assert.equal(striker.predicted_members, 1, 'partial simulation, not only mixed drawing');
assert.equal(striker.max_claim, 1);
assert.ok(striker.fast_far > 0 && striker.predicted_samples > 0);
assert.ok(striker.predicted_error < 0.001, 'claimed Godot pose must match prediction');
for (const role of ['idle', 'observer']) {
  const group = row(role, 'RCB_GROUP');
  assert.equal(group.predicted_members, role === 'idle' ? 1 : 0);
  assert.equal(group.max_claim, 0);
  assert.ok(group.watched_samples > 0 && group.watched_error < 0.001);
}
console.log(`RCB_CHECK_OK kicks=${results[0].kicks} fast_far=${striker.fast_far}`);
if (process.env.RCB_STALL_MS) {
  assert.ok(log('idle').includes('RCB_STALL '));
  const metrics = row('idle', 'RCB_METRICS');
  assert.ok(metrics.catchups > 0, 'the paused client must adopt an ahead snapshot');
  assert.equal(metrics.resyncs, 0, 'retained facts must avoid a destructive resync');
}

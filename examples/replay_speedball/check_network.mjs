import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const directory = process.argv[2];
function log(role) { return readFileSync(`${directory}/${role}.log`, 'utf8'); }
function row(role, prefix) {
  const lines = log(role).split('\n').filter(line => line.startsWith(prefix + ' '));
  assert.equal(lines.length, 1, `${role}: ${prefix}`);
  return Object.fromEntries([...lines[0].matchAll(/(\w+)=(-?\d+(?:\.\d+)?)/g)].map(([, k, v]) => [k, Number(v)]));
}
const roles = ['server', 'striker', 'spiker', 'observer'];
const results = roles.map(role => row(role, 'RSB_RESULT'));
for (const [i, result] of results.entries()) {
  assert.ok(log(roles[i]).includes('REPLAY_SPEEDBALL_PROCESS_OK'));
  assert.equal(result.left, 0); assert.equal(result.right, 1); assert.equal(result.winner, 2);
  assert.equal(result.x, 320); assert.equal(result.y, 180);
  assert.equal(result.kicks, results[0].kicks); assert.equal(result.spikes, 2);
}
assert.ok(results[1].local_kicks > 0 && results[1].speculative_kicks > 0, 'striker kicks must predict');
assert.equal(results[1].local_kicks - results[1].local_canceled, results[0].kicks, 'local kick reconciliation');
assert.equal(results[2].remote_kicks - results[2].remote_canceled, results[0].kicks, 'predicted remote kick reconciliation');
assert.ok(results[3].remote_kicks > 0, 'true observer must present authoritative kicks');
assert.equal(results[3].remote_kicks, results[0].kicks, 'observer must present each kick once');
assert.equal(results[2].accepted, 2); assert.equal(results[2].rejected, 0);
const local = row('spiker', 'RSB_SPIKE_LOCAL');
assert.ok(local.ticks <= 4 && local.ms < 120, JSON.stringify(local));
assert.ok(log('spiker').includes('acknowledged=false'), 'spike displacement must precede acknowledgement');
console.log(`RSB_CHECK_OK kicks=${results[0].kicks} spikes=2 spike_ticks=${local.ticks} spike_ms=${local.ms}`);

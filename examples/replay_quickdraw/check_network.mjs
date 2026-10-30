// Assert receipts from the real Godot scene, including predicted node visibility.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

function row(path, prefix) {
  const lines = readFileSync(path, 'utf8').split('\n').filter(line => line.startsWith(prefix + ' '));
  assert.equal(lines.length, 1, `${path}: ${prefix}`);
  return Object.fromEntries([...lines[0].matchAll(/(\w+)=(\d+)/g)].map(([, k, v]) => [k, Number(v)]));
}

const [phase, server, watcher, attacker] = process.argv.slice(2);
const [truth, remote, local] = [server, watcher, attacker].map(path => row(path, 'RQ_RESULT'));
for (const key of ['shots', 'hits', 'lobs', 'lands', 'buys', 'invalid']) {
  assert.equal(truth[key], remote[key], `${phase}: observer ${key}`);
  assert.equal(truth[key], local[key], `${phase}: attacker ${key}`);
}
assert.equal(truth.invalid, 0, `${phase}: invalid historical query`);
if (phase === 'lobs') {
  const metrics = row(attacker, 'RQ_METRICS');
  assert.equal(truth.buys, 2);
  assert.ok(truth.lobs >= 8);
  assert.equal(truth.lobs, truth.lands);
  assert.equal(local.predicted_lobs, truth.lobs);
  assert.equal(metrics.visible_lobs, truth.lobs);
  assert.ok(metrics.lob_visible_max_ms < 120, JSON.stringify(metrics)); // less than one injected network leg
} else {
  assert.ok(truth.shots >= 15);
  assert.equal(local.local, truth.shots, `${phase}: local shot effects`);
  assert.equal(remote.watched, truth.shots, `${phase}: watched shot effects`);
  assert.equal(local.watched, 0);
  assert.equal(remote.local, 0);
}
console.log(`REPLAY_QUICKDRAW_PHASE_OK phase=${phase}`);

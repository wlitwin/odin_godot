import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const directory = process.argv[2];
const results = ['listen', 'dial'].map(role => {
  const log = readFileSync(`${directory}/${role}.log`, 'utf8');
  assert.ok(log.includes('REPLAY_DUEL_PEER_OK'));
  const lines = log.split('\n').filter(line => line.startsWith('RDP_RESULT '));
  assert.equal(lines.length, 1);
  return Object.fromEntries([...lines[0].matchAll(/(\w+)=([\d,]+)/g)].map(([, k, v]) => [k, v]));
});
for (const key of ['tick', 'hash', 'shots', 'hits', 'kills']) assert.equal(results[0][key], results[1][key], key);
assert.equal(results[0].tick, process.argv[3] ?? '600');
for (const result of results) {
  assert.ok(Number(result.rollbacks) > 0 && Number(result.replayed) > 0);
  assert.ok(Number(result.dropped) > 0 && Number(result.duplicated) > 0);
  assert.ok(Number(result.hits) > 0);
}
console.log(`RDP_CHECK_OK hash=${results[0].hash} shots=${results[0].shots} hits=${results[0].hits}`);

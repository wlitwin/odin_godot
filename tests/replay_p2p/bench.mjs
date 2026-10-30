import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const lines = readFileSync(process.argv[2], 'utf8').trim().split('\n');
const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const samples = lines.filter(l => l.startsWith('RDP_BENCH ')).map(fields);
assert.equal(samples.length, 30);
assert.equal(new Set(samples.map(s => s.hash)).size, 1, 'every case must execute the same world and events');
const median = xs => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];
const results = [];
for (const name of ['lan_d2', 'fault_d2', 'fault_d8']) {
  const selected = samples.filter(s => s.case === name);
  const off = selected.filter(s => s.profiled === '0'), on = selected.filter(s => s.profiled === '1');
  assert.equal(off.length, 5); assert.equal(on.length, 5);
  const first = off[0];
  for (const sample of selected) {
    for (const key of ['ticks', 'cycles', 'hash', 'tx_bytes', 'rollbacks', 'replayed', 'stalls', 'max_depth']) assert.equal(sample[key], first[key], `${name} ${key}`);
    assert.ok(Number(sample.cpu_us) > 0 && Number(sample.wall_us) > 0);
  }
  const cpu = median(off.map(s => Number(s.cpu_us))), measured = median(on.map(s => Number(s.cpu_us)));
  results.push({case: name, trials: 5, ticks: Number(first.ticks), virtual_cycles: Number(first.cycles),
    cpu_us_median: cpu, wall_us_median: median(off.map(s => Number(s.wall_us))), profiled_cpu_us_median: measured,
    instrumentation_cpu_ratio: measured / cpu, tx_bytes: Number(first.tx_bytes), rollbacks: Number(first.rollbacks),
    replayed_ticks: Number(first.replayed), waiting_attempts: Number(first.stalls), max_replay_depth: Number(first.max_depth), hash: first.hash});
}
for (const line of lines.filter(l => l.startsWith('RDP_BENCH_WORK '))) assert.equal(fields(line).errors, '0');
console.log(JSON.stringify({scope: 'two peers plus deterministic Memory transport; accelerated virtual time; setup/reference/cleanup excluded', results}, null, 2));

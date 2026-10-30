import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=(\S+)/g)].map(m => [m[1], m[2]]));
const rows = [];
let hash;
for (const delay of [2, 8]) {
  const log = readFileSync(join(process.argv[2], `delay-${delay}.log`), 'utf8');
  const peers = new Map(); let peer;
  for (const line of log.split('\n')) {
    if (line.startsWith('RDP_RESULT ')) {
      const result = fields(line); peer = {result, metrics: {}};
      assert.ok(!peers.has(result.seat)); peers.set(result.seat, peer);
    } else if (line.startsWith('RDP_PROFILE_CONFIG ')) {assert.ok(peer); peer.config = fields(line);}
    else if (line.startsWith('RDP_PROFILE ')) {assert.ok(peer); const metric = fields(line); peer.metrics[metric.metric] = metric;}
  }
  assert.equal(peers.size, 2);
  for (const [seat, p] of peers) {
    hash ??= p.result.hash; assert.equal(p.result.hash, hash, 'matched inputs must give identical final worlds');
    assert.equal(p.config.delay, String(delay)); assert.equal(p.config.neutral, '8');
    assert.equal(p.metrics.Step.samples, '600'); assert.equal(p.metrics.Hash.samples, '600');
    assert.equal(p.metrics.Input_Latency.samples, String(600 - delay));
    for (const metric of Object.values(p.metrics)) assert.equal(metric.errors, '0');
    const latency = p.metrics.Input_Latency;
    rows.push({delay_ticks: delay, seat: Number(seat), nominal_delay_ms: delay * 1000 / 60,
      capture_to_step_mean_ms: Number(latency.total_us) / Number(latency.samples) / 1000,
      capture_to_step_p95_upper_ms: Number(latency.p95_upper_us) / 1000,
      capture_to_step_max_ms: Number(latency.max_us) / 1000,
      replay_wall_us: Number(p.metrics.Replay.total_us), replay_p95_upper_us: Number(p.metrics.Replay.p95_upper_us),
      step_wall_us: Number(p.metrics.Step.total_us), hash_wall_us: Number(p.metrics.Hash.total_us), pump_wall_us: Number(p.metrics.Pump.total_us),
      rollbacks: Number(p.result.rollbacks), replayed_ticks: Number(p.result.replayed), waiting_attempts: Number(p.result.stalls),
      max_replay_depth: Number(p.config.max_replay_depth), elapsed_ms: Number(p.config.elapsed_ms), dropped_clock_ms: Number(p.config.dropped_clock_ms),
      tx_bytes: Number(p.result.tx), hash});
  }
}
console.log(JSON.stringify({scope: 'real ENet peers; capture-to-first-simulation latency, not physical-device/display latency; operation times overlap', rows}, null, 2));

# Retained catalog fixture

`without-pulses.checkpoint` is the current-format migration of the tick-12
pre-Stormcaller save. Its catalog retains zero pulse definitions. Tests decode it
directly and verify that current defaults do not silently change saved content.
The original checkpoint and [migration receipt](../../../docs/replay/results/usability-legacy-2026-11-16/scrapyard/receipt.json)
remain historical evidence.

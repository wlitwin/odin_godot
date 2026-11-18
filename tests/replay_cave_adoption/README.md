# Cavecrawl old-host adoption acceptance

```sh
REPLAY_CAVE_ADOPTION_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_adoption/run.sh
REPLAY_CAVE_ADOPTION_WEB_OUT=/absolute/fresh/web-output nix develop --command bash tests/replay_cave_adoption/web_run.sh
```

The native gate runs core/model tests, fifteen C1–C7 conversions and fresh resumes,
planned/crash old-host carrier takeovers, the four successor/guest carrier
regressions, and full normal/faulted campaigns. `migrations.py` reads the actual
first committed authority frame at recovered tick + 1, requiring adoption to
seat 2 with one version increment. Surviving processes then observe continued
carrying and the successor's fresh release. The returning host keeps seat 1.

The browser gate extends the RTC party/social scenario: host seat 1 carries first,
the successor becomes carrier after handoff, and all three peers observe the
successor release it. Test probes only read authority observations; drivers use
ordinary actions. Prepared source/framework and binary/export identities are
retained with results. No original project is edited.

The retained host-carrier checkpoint uses the current schema under
`tests/replay_cave/fixtures/current`. Its original frame and peer metadata are
preserved by the migration receipt under
`docs/replay/results/usability-legacy-2026-11-16/cavecrawl`.

See [the policy contract](../../replay/net/authority.md) and
[game behavior](../../examples/replay_cavecrawl/adoption.md).

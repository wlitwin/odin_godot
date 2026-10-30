# Editor workflow acceptance

`REPLAY_WORKFLOW_OUT=/absolute/fresh/output nix develop --command bash tests/replay_editor_workflow/run.sh`

Builds an isolated project; tests enemy/ability refresh and rejected edits, real
ability admission/casting/recording, existing editor scenes, and the actual editor
plugin's validate/clickable issue/fix/bake workflow. Commands then create/build/
preview actor and ability drafts, refuse overwrite, run a draft correction and
checkpoint takeover, and launch two real peers at 150 ms. Tests check cancellation
and preservation, and run model/native/WASM regressions. Logs survive failures.

`ui.gd` additionally exercises the full F6 workbench UI: preview → encounter →
recording → preview → correction command. Recording files are development artifacts
under the project's user data directory; verification uses the existing recording
CLI. This does not claim browser execution of native editor/Python jobs.

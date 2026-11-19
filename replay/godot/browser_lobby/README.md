# Player-hosted Web rooms

`begin` starts a short-code Replay Party for a specific service, namespace and
content ID. The host selects the number of guest uses. Pump `poll` while the
operation is pending and throughout the game so the relay keeps its credentials
current. Once granted, pass the result of `options` to `room_open` or
`physics.authored_room_open`. Call `room_frame` to run that Session. The lobby
must stay at a stable address until after the Room closes. `code` returns the
creator's shareable invitation after the service issues it.

This policy uses one browser host, player invitations, separate browser-tab seats,
and the existing signaling and TURN service. Closing the host ends the game.
A managed physics Room needs an exact owner for the Lobby's `party.relay` field.

`build/install_browser_lobby.sh PROJECT` installs the Godot room-code/copy UI and
hidden-tab runtime. `build/export_itch_game.py PROJECT SLUG [--box3d]` stages a
standalone source-checkout game with its own `build.sh` and Web preset, selects the
verified Godot RTC template, and writes `out/SLUG-html5.zip`. Enroll the game's
cohort on its service route, publish the HTML5 channel and enable SharedArrayBuffer
in the itch embed settings.

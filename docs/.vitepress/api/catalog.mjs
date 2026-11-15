export const layers = ['Odin and Godot', 'Kit', 'Replay', 'Box3D', 'Libraries']

export const roots = {
  godot: 'Odin and Godot', runtime: 'Odin and Godot',
  gdext: 'Odin and Godot', libgd: 'Odin and Godot',
  kit: 'Kit', replay: 'Replay', box3d: 'Box3D',
  events: 'Libraries', flow: 'Libraries', flowgd: 'Libraries', play: 'Libraries',
}

export const guides = {
  godot: ['scripting/index.md', 'Scripting guide'],
  runtime: ['authoring-guide.md', 'Script authoring'],
  gdext: ['contributing/native-boundary.md', 'Native boundary'],
  libgd: ['contributing/native-boundary.md', 'Native boundary'],
  kit: ['kit/index.md', 'Kit guide'],
  replay: ['replay/index.md', 'Replay guide'],
  box3d: ['box3d/index.md', 'Box3D guide'],
  events: ['events.md', 'Events guide'],
  flow: ['libraries/flow.md', 'Sequences guide'],
  flowgd: ['libraries/flowgd.md', 'Tween guide'],
  play: ['kit/play.md', 'Gameplay components'],
}

export const descriptions = {
  godot: 'Authored engine helpers, typed signals, strings, and Variants.',
  runtime: 'Script registration, typed script access, and runtime contracts.',
  gdext: 'GDExtension ABI types and engine function pointers. Advanced.',
  libgd: 'Binding support and native engine integration. Advanced.',
  'kit/net': 'Entity fields, codecs, commands, and replication.',
  'kit/session': 'Session lifecycle, roster, admission, and reconnect.',
  'kit/sim': 'Fixed ticks, input history, prediction, and reconciliation.',
  'kit/boot': 'Lobby-to-game lifecycle and generated networking integration.',
  'kit/netcfg': 'Named network profiles and configuration validation.',
  'kit/physics': 'Complete Box3D state for Kit simulation.',
  replay: 'Frames, timelines, history, pools, RNG, and occurrences.',
  'replay/net': 'Authoritative models, controls, actions, and correction.',
  'replay/godot': 'Godot Session, Party, Room, and presentation integration.',
  'replay/godot/physics': 'Optional copied presentation frames from complete Box3D checkpoints.',
  'replay/physics': 'Complete Box3D checkpoints and Replay codecs.',
  'replay/play': 'Value-based gameplay helpers for restorable Worlds.',
  box3d: 'Worlds, bodies, shapes, queries, characters, joints, and snapshots.',
  'box3d/authoring': 'Definitions, baking, construction, catalogs, and artifacts.',
  'box3d/presentation': 'Copied physics frames and presentation values.',
  events: 'Typed event subscriptions and direct callback dispatch.',
  flow: 'Timed, sequential, and parallel action trees.',
  flowgd: 'Godot Tween steps for flow.',
  play: 'Embeddable Kit gameplay components and presentation helpers.',
  'play/sim': 'Predicted cooldown and movement components.',
}

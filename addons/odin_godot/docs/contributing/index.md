# Contributing

Use this section when changing the SDK, its build tools, or its documentation.
For game development, start with [Scripting](../scripting/index.md) and the
framework guides instead.

## Source map

| Directory | Responsibility |
| --- | --- |
| `bindgen/`, `godot/` | Generated engine bindings and hand-written engine helpers |
| `gdext/`, `libgd/` | GDExtension C ABI support |
| `core/` | Language registration, script loading, instances, reload, editor tooling, export |
| `runtime/` | Contract shared by core and compiled scripts |
| `scriptgen/` | Script declarations and generated registration/protocol code |
| `build/` | Native/web compilation, addon packaging, export helpers |
| `kit/`, `play/` | Kit sessions, replication, simulation, and gameplay blocks |
| `replay/` | Frame history, network runners, Godot adapters, recovery, and gameplay helpers |
| `box3d/`, `addons/box3d_authoring/` | Native physics, adapters, collision authoring, editor tooling |
| `events/`, `flow/`, `flowgd/` | Event and sequencing libraries |
| `examples/`, `tests/` | Example games and regression/integration fixtures |
| `docs/` | Maintained user documentation and contributor guides |

## Validate a change

Enter `nix develop` and run the focused test or example for the behavior you
changed. The full headless suite is:

```sh
nix develop --command bash tests/run_all.sh
```

Browser tests require their browser setup. Native Box3D tests require a coherent
backend built from the current inputs; use the corresponding fixture README.
Some test directories retain historical names containing `spike`; the suite still
uses those as regression coverage.

## Documentation

The site uses VitePress and an explicit sidebar for each layer. Guides stay in
Markdown; built HTML, caches, and dependency directories are ignored. GitHub
Pages builds and publishes the site from source.

```sh
cd docs
npm ci
npm run check
npm run build
npm run dev
```

Open `http://localhost:5173/odin_godot/` for live preview. `npm run preview` serves
the production build. Follow [Writing documentation](writing-docs.md) for page
types, working examples, code verification, and link rules.

## Architecture and releases

- [Core and scripts boundary](native-boundary.md): compatibility, callbacks, and ownership.
- [SDK architecture](architecture.md): build, load, reload, and export responsibilities.
- [Documentation maintenance](documentation.md): publication, link checks, and adding tutorials.
- [Publishing the addon](../publishing.md): release-branch and Asset Library procedure.

Detailed physics contracts and raw validation records remain beside their source
and tests. They are engineering material rather than a game developer's learning
path. Keep obsolete proposals and progress journals in Git history.

# Writing documentation

This page is the standard for everything under `docs/`. Read it before adding or
editing a page.

## Who reads these docs

A game developer who knows Godot and can program, and who has never used
odin_godot. They may be new to Odin. They are here to build a game, and they
arrived at this page from a search result or a sidebar link, not from the page
before it.

Write so that reader can act on the page without knowing how the SDK was
developed, which milestones it passed, or what an earlier version did.

## How the docs are organised

The docs follow the layers of the SDK. The scripting bridge is the foundation.
Kit and Replay are independent alternatives; Box3D also works offline. A reader
can learn one of these without adopting the others.

| Section | Directory | Covers |
| --- | --- | --- |
| Scripting | `docs/scripting/` | Writing Godot scripts in Odin: install, script structs, exports, signals, the editor loop, debugging, export. No multiplayer framework required. |
| Kit | `docs/kit/` | The Kit multiplayer framework: sessions, replicated fields, commands, the simulation lane, and Kit's gameplay packages. |
| Replay | `docs/replay/` | The Replay multiplayer framework: a replayable World, timelines, sessions, rooms, peer-to-peer rollback, and Godot presentation. |
| Box3D | `docs/box3d/` | Box3D physics: authoring worlds and bodies in the editor, stepping, queries, characters, joints, and using it with Kit or Replay. |
| Libraries | `docs/libraries/` | Small standalone packages: `events`, `flow`, `flowgd`, `play`. |
| Examples | `docs/examples/` | The example games, ordered as a learning ladder. |
| Contributing | `docs/contributing/` | How the SDK itself is built: architecture, internals, tests, releases, and this page. |

Established root guides keep their paths, including `authoring-guide.md`,
`workflow.md`, and `events.md`. Their sidebars place them in the relevant layer;
do not create a second copy to match a directory name. The Learn section links
to finished tutorials and explanations across these layers.

Every section has the same shape, in this sidebar order:

1. **Overview** (`index.md`): what the layer is, when to use it and when not to,
   what the reader should know first, the mental model in a few paragraphs, and a
   map of the section.
2. **Tutorial**: one start-to-finish build that ends with something running.
3. **Guides**: one task or topic per page.
4. **Reference**: tables of every option, tag, procedure, and limit.

### Page types

Decide which of these a page is before writing it, and keep it to that type.

**Tutorial.** The reader follows numbered steps and ends with a working result.
State the result and the prerequisites at the top. Show every file in full the
first time it appears and every command with its expected output. Explain only
what the reader needs for the next step, and link to guides for the rest. A
tutorial must be reproducible: build it yourself from an empty project before
publishing.

**Guide.** The reader has a task ("replicate a field", "bake a collision mesh").
Open with one or two sentences that say what the page lets them do. Then give the
smallest complete example, then the variations and the limits. Guides assume the
section's tutorial.

**Concept.** The reader wants to understand a design ("the two timelines",
"who owns an entity"). Explain the mechanism and its consequences for game code.
Use a diagram when there is a flow or a relationship between more than two
things. Do not include step-by-step instructions.

**Reference.** The reader is looking something up. Use tables and consistent
entries: name, signature, what it does, defaults, limits. No narrative. Every
public procedure, tag, attribute, and setting belongs in a reference page.

A page that needs two types should be two pages that link to each other.

## What does not belong in the docs

The docs describe the SDK as it is now. Leave these out:

- **Project history.** Plans, roadmaps, progress logs, milestone or gate names,
  phase numbers, "originally", "previously", "we found", "after the rewrite".
  Git history holds the record.
- **Evidence and receipts.** Test names, markers, dates, hashes, run counts,
  "verified by", "validated at", "passes N tests". If behaviour is supported,
  say it is supported. If it has a limit, state the limit.
- **Comparisons with earlier implementations.** Describe what a framework does,
  not how it differs from an earlier port of the same game.
- **Defensive qualifiers.** "This does not claim", "is not evidence of",
  "remains a separate gate". State the supported configurations and the known
  limits once, in a "Limits" or "Platform support" section, in plain terms.
- **Promotion.** Adjectives that rate the SDK. Describe the property.

Design rationale that helps a contributor change the SDK belongs in
`docs/contributing/`, written as how the system works today.

## Prose

Start with the behaviour or the task, show the mechanism, then explain the
consequence. Use concrete nouns and active verbs. Name the object that owns or
changes a value. Define a framework term where the reader first needs it, and
use the same word for the same thing throughout.

Use connected paragraphs for explanation, numbered steps for procedures, and
tables for comparisons. Keep the command or code a step needs next to the step.

Remove intensifiers, rhetorical questions, slogans, and canned transitions:
"simply", "just", "seamlessly", "powerful", "robust", "leverage", "unlock", "it
is worth noting", "in short". Judge each word in context: a precise "only" that
states a restriction stays.

Edit the paragraph, not only its vocabulary. A paragraph built on a metaphor or
a coined label still fails after the conspicuous words are replaced. Name the
operation, its preconditions, and the work left to the game. For example,
replace "the block ships the verb, the game keeps the 'and then'" with "The
component implements the target mutation. The game handles accepted cross-entity
changes in `<verb>_then`."

Avoid "not X, but Y" constructions and absolutes such as "you never need" or
"everything works automatically". Keep restrictions that define trust,
correctness, compatibility, or supported configurations.

Headings are sentence case and say what the section contains. No emphasis in
ALL CAPS in prose or in code comments.

## Terms

| Term | Use |
| --- | --- |
| odin_godot | The SDK and repository. Use Odin for the language and Godot for the engine. |
| Script state / Godot node | For node scripts, `self` addresses script data and `self.owner` is the engine node. Resource scripts hold an engine Resource. |
| Entity owner | The player allowed to write an entity's owner-controlled fields. Qualify ownership when a node or allocation owner could be confused with it. |
| Authority | The process allowed to accept shared gameplay results. Say host or server when discussing that particular network role. |
| Kit command | A generated request to validate and mutate an entity target. |
| Replay World | Mutable gameplay state supplied by the game. Use `World` for the type name and world for the general concept. |
| Frame | Simulation state at a particular tick. |
| Snapshot | A network or storage representation of state. It may be filtered for a recipient. |
| Runner | The runtime that schedules simulation steps and manages input and history. |
| Occurrence | A recorded gameplay event with an identity used to match it across replay. |
| Prediction | Speculative local simulation before the authority has settled that state. |
| Correction | Application of accepted authority state followed by replay of the remaining predicted ticks. |
| Confirmation | The authority or commit protocol has settled a tick. |
| Presentation | The state and effects drawn or played for a selected display time. |

## Code

- Fence Odin as `odin`, GDScript as `gdscript`, shell as `sh`, scene and
  resource text as `ini`.
- Every snippet must compile, or be an excerpt of code that does. Prefer excerpts
  from the examples and name the file: "From `examples/slopball/scripts/ball.odin`".
  When an example changes, the page changes with it.
- Check every procedure name, tag, attribute, field, and default against the
  source before publishing. If you cannot find it in the source, it does not go
  on the page.
- Show imports the first time a package appears on a page.
- Comments in snippets explain the line to the reader. No shouting, no history.
- Show expected output for commands when the reader needs it to know the step
  worked.
- When a concept maps to something a Godot developer knows, show the GDScript
  equivalent beside the Odin.

## Links, callouts, and images

- Link between pages with relative paths that end in `.md`:
  `[exports](exports.md)`, `[Kit sessions](../kit/session.md#joining)`. These work
  on the site, on GitHub, and in the copy of the docs that ships in the addon.
- Link to files outside `docs/` with a full GitHub URL:
  `https://github.com/wlitwin/odin_godot/tree/main/examples/slopball` for a
  directory, `.../blob/main/examples/slopball/README.md` for a file.
- Prefer linking to a page over linking to a heading inside it. When you do link
  to a heading, the heading must contain only letters, digits, and spaces. The
  site and GitHub build anchors differently from anything else (underscores,
  backticks, punctuation, a leading digit), and `npm run check` rejects an
  anchor that resolves in only one of them. For an established heading, an
  explicit HTML anchor can preserve its existing incoming links.
- Callouts use GitHub alert syntax, which renders on GitHub and on the site:

  ```md
  > [!NOTE]
  > Background the reader can skip.

  > [!TIP]
  > A better way to do the thing just described.

  > [!WARNING]
  > A mistake that costs time or corrupts state.
  ```

  Use them sparingly. A page with a callout in every section has none.
- Put images beside the page in an `img/` directory and reference them
  relatively. Give every image alt text that says what it shows. Diagrams are
  SVG or a `mermaid` fence.
- End a page with a short "Next" list only when there is a natural next page.

## Adding a page

For API declarations, write a comment directly before the declaration and use
field or enum-member comments for member-specific behavior. State ownership,
defaults, errors, and restrictions where they affect callers. The generated
[API reference](../api/index.md) takes its signatures and notes from source;
do not maintain a second copy of a function declaration in a reference page.

1. Put the file in the section's directory. File names are lowercase words
   joined by hyphens.
2. Start with one `#` heading. The first paragraph says what the page covers
   and who needs it.
3. Add the page to the section's sidebar file, `docs/.vitepress/sidebar/<section>.ts`.
   The sidebar order is the reading order, so place the page deliberately.
   List it once in [the site map](../site-map.md), with a short description of
   its topics. The link check rejects missing or duplicate entries.
4. Check the links and build the site. Both fail on a broken internal link.

   ```sh
   cd docs
   npm ci
   npm run check    # links, assets, navigation, and heading anchors
   npm run build    # the site, into .vitepress/dist
   npm run dev      # live preview at http://localhost:5173/odin_godot/
   ```

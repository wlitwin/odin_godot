# Documentation style

Write for a developer who can read code and understands structs, callbacks,
builds, and basic game development, but has not used odin_godot, Kit, or Replay.
Explain the framework's decisions and contracts. Do not turn a setup guide into
an introduction to programming or require the reader to know the project's history.

## Prose

Start with the behavior or task, show the mechanism, then explain its consequence.
Use concrete nouns, active verbs, and examples drawn from the repository. Name the
object that owns or changes a value. Explain a framework term before relying on it.

Prefer connected paragraphs for explanations, numbered steps for procedures, and
tables for comparisons. Keep the commands and code needed to complete a task near
their explanation. Link to a reference when the detail is outside the page's scope.

Remove empty intensifiers, promotional claims, rhetorical questions, and canned
transitions. Common candidates include “simply,” “just,” “seamlessly,” “powerful,”
“robust,” “leverage,” “unlock,” “it is worth noting,” “importantly,” and “in short.”
Judge each use in context: a technical restriction or a precise use of “only”
must survive editing. State the actual property in place of a vague adjective.

Edit the paragraph, not only its vocabulary. Replacing a few conspicuous words
leaves the same problem when a paragraph still relies on slogans, metaphors,
dramatic fragments, or claims that the reader cannot check. Name the operation,
its preconditions, and the work still left to the game.

For example, replace “the block ships the verb, the game keeps the ‘and then’”
with “The component implements the target mutation. The game handles accepted
cross-entity changes in `<verb>_then`.” Replace a “fingerprint door” with the
actual admission check and its incompatibility result. A “write-guard walk” can
usually be described as comparing client fields with framework-applied values.
Keep a specialized term when it names a real API or protocol concept, and define
it where the reader first needs it.

Avoid repetitive “not X, but Y” explanations and unsupported absolutes such as
“you never need” or “everything works automatically.” Preserve restrictions that
define trust, correctness, compatibility, or supported configurations.

## Terms

| Term | Use |
| --- | --- |
| odin_godot | The SDK and repository. Use Odin for the language and Godot for the engine. |
| Script state / Godot node | For node scripts, `self` addresses script data and `self.owner` is the engine node. Resource scripts hold an engine Resource. |
| Entity owner | The player allowed to write an entity's owner-controlled fields. Qualify ownership when a node or allocation owner could be confused with it. |
| Authority | The process allowed to accept shared gameplay results. Say host or server when discussing that particular network role. |
| Kit command | A generated request to validate and mutate an entity target. Explain the authority hook when the action has cross-entity consequences. |
| Replay World | Mutable gameplay state supplied by the game. Use `World` for the type name and world for the general concept. |
| Frame | Simulation state at a particular tick. Describe the relevant simulation group when its extent matters. |
| Snapshot | A network representation of state. It may be filtered for a recipient and need not contain enough state for authority recovery. |
| Runner | The runtime that schedules simulation steps and manages the relevant input/history policy. |
| Occurrence | A recorded gameplay event with an identity used to match it across replay. Distinguish it from its typed event payload or a Godot callback. |
| Prediction | Speculative local simulation before the authority has settled that state. |
| Correction | Application of accepted authority state followed by replay of the remaining predicted ticks. |
| Confirmation | The authority or commit protocol has settled a tick. Revising local input alone does not confirm it. |
| Presentation | The state and effects drawn or played for a selected display time. A presentation claim changes the displayed pose, not who judges gameplay. |

## Technical fidelity

Keep API names, identifiers, commands, configurations, schemas, executable code,
receipts, and numeric limits intact during a prose pass. Natural-language code
comments may be edited, but preserve functional directives, string literals,
output, and executable-line order and indentation. Verify examples with comments
removed; report any source-verified code correction separately. Check a claim
against its source before changing its meaning. Preserve linked headings or
provide an anchor alias. Edit source Markdown and authored templates, then
regenerate the site; generated reference copies are not editorial inputs.

Use a precise heading in place of a rhetorical or slogan-like one. When renaming
a published heading, retain its old fragment with an explicit named anchor so
existing links and bookmarks still work. Third-party documentation and generated
distribution copies should be reviewed against their own sources rather than
rewritten as SDK-owned prose.

Tutorials describe current behavior and next actions. Dated design, audit, and
comparison records retain their scope, dates, and results. Give those records a
short explanation of what they cover rather than presenting their chronology as
instructions for a new user. Do not turn one passing test into a general support claim.

## Prose references

These posts illustrate concrete engineering explanations; they are style
references, not sources for SDK API claims:

- [Jane Street: type-safe reference counting between OCaml and Python](https://blog.janestreet.com/oxcaml-typesafe-reference-counting-python/)
- [Meta: Ax and adaptive experimentation](https://engineering.fb.com/2025/11/18/open-source/efficient-optimization-ax-open-platform-adaptive-experimentation/)
- [Linear: reducing CI bottlenecks](https://linear.app/now/ci-bottleneck-reworked)

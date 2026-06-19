# Comments Guide

The bar for a comment is high and the default is **none**. Good code explains
itself through names and structure; a comment is what you reach for only after
naming and structure have failed. Read this before writing any comment or
JSDoc.

## The ladder — exhaust these before writing a comment

A comment is the **last** rung, not the first. Work down this ladder and stop at
the first rung that makes the code clear on its own:

1. **Rename.** Can a clearer function, variable, or parameter name make the
   intent obvious? `daysUntilExpiry` needs no comment; `d` with a comment does.
   Rename, delete the comment.
2. **Extract.** Is the function complex or hard to follow? **Split it into
   smaller functions with clear, human-readable names** — the names become the
   explanation. A 40-line function with five `// now we…` comments is five
   functions wearing a trench coat. `validateAddress`, `normalizePhone`,
   `chargeCard` read top-to-bottom like prose; the comments vanish because the
   call sequence says what they said.
3. **Restructure.** Can an early return, a guard clause, or a well-named
   intermediate value remove the confusion the comment was patching?
4. **Only then — comment.** If the WHY genuinely cannot live in a name or
   structure, write the smallest comment that carries it.

If you're writing a comment to explain *what* the code does, you skipped rung 1
or 2. Go back.

## When a comment is warranted

A comment earns its place only if it satisfies **all three**:

1. **Encodes WHY, not WHAT.** The code already says what it does. The comment
   records a reason the reader could not infer — a hidden constraint, a subtle
   invariant, a workaround for a specific bug, a surprising runtime behavior, a
   race the structure doesn't telegraph.
2. **Reads timeless.** It must make sense to a reader years from now who has no
   idea who wrote it, when, or what task produced it. No "now", no "recently",
   no reference to the change that introduced it.
3. **Is brief.** One line is the target. Multi-line only when an invariant
   genuinely needs the room.

Legitimate cases: a non-obvious WHY; a warning the reader would otherwise miss
("must run before X", "do not memoize — must re-run per render"); a sanctioned
section marker (below).

## Sanctioned exception: section markers

The 3-line JSDoc **section markers** the style guides mandate are not subject to
the rules above — they are required structure, not commentary, and the
"restating the name / content-free" bans do **not** apply to them. Keep them
exactly as `.claude/guides/REACT-GUIDE.md` defines:

```tsx
/**
 * @imports
 */
```

Top-level markers (`@imports`, `@constants`, `@types`, `@component` /
`@function`, `@helpers`) and in-component markers (`@state`, `@derived`,
`@callbacks`, `@effects`, `@render`) are always the 3-line form with a blank
line directly above — never collapsed to one line. They are the only comments
that are *expected* to be present without encoding a WHY; their job is to give
the reader's eye a fixed scan target. The marker token (`@imports`) is the whole
content — do not add prose after it. Full marker list and ordering live in
`.claude/guides/REACT-GUIDE.md`.

Single-line **import-group labels** (`// components`, `// hooks`, `// lib -
schemas`, `// services`, `// utils`, …) are sanctioned for the same reason — they
label a block of imports. The one rule: a label is only valid above a **non-empty**
group; remove the label in the same edit that removes its last import. An empty
labeled gap is noise and falls back under the bans above.

## Banned — delete on sight

The recurring failure here is **comments tied to ephemeral context** — they rot
the instant that context is gone, and they're noise to everyone who reads the
code afterward.

- **AI-chat / agent-session references.** "as discussed with the assistant",
  "from the Claude session", "the model suggested", a pasted conversation
  fragment. The chat is gone; the comment is litter.
- **Superpowers / plan / spec references.** "implementing step 3 of the research
  spike", "per `docs/superpowers/plans/2026-…`", "this fulfills the plan",
  "TODO from the brainstorming doc". Plans are ephemeral working artifacts; code
  is permanent. A path into a plan file is dead the moment the plan is archived.
- **`ponytail:` tags.** `// ponytail: global lock, per-account locks if
  throughput matters` and any other `// ponytail:` / `# ponytail:` marker. They
  name a deliberate shortcut left by [Ponytail mode](./PONYTAIL.md) — process
  scaffolding, not a fact about the code. If the shortcut has a real, timeless
  WHY or a known ceiling worth recording, restate it as a plain factual comment
  **without** the `ponytail:` prefix; otherwise delete it. Track deferrals with
  the `/ponytail-debt` skill during a session, not with tags in committed source.
- **Task / PR / review / change narrative.** Any reference to the conversation,
  ticket, PR, reviewer, refactor, or migration that produced the line.
- **Banned phrases** (each one is narrating change, not stating fact — rewrite
  or delete): *now, previously, was, used to be, old, new, recently, originally,
  v1/v2/v3, migration, refactor, refactored, renamed, replaces, replaced,
  swapped, moved from, ported, the new pattern, after the rewrite, validates the
  migration, mirrors the production X, see #123, per review, per feedback, we
  decided.*
- **Restating the name.** `// Append an error` above `appendError`.
- **Line-by-line narration.** Describing what each statement does.
- **Filler verbs.** "handles X", "manages Y", "utility for Z" above a function
  whose name already says it.
- **External file/symbol references.** "mirrors `providers/client.tsx`", "see
  `/components/foo.tsx`" — those paths rename and rot. Provenance lives in git
  and the PR, not the source.

## The timelessness test

Read the comment as if written years ago by a stranger. Does it still help? If
it reads as history — "the migration target", "after the refactor", "the new
pattern", "implementing the plan" — delete it. The git log and PR description
are where provenance belongs; the comment is for facts that outlive the change.

## JSDocs

Every rule above applies, plus:

- **State what the code IS** — not what it was, will be, or how it changed.
- **One sentence is the target.** A second sentence only for a non-obvious
  invariant or a contract the caller must honor. A paragraph belongs in a PR
  description or external doc, never the JSDoc.
- **Parameters: only what the name and type can't say.** Don't `@param` an
  argument whose name is already obvious. Document one only for an ambiguous
  name, a non-obvious expected shape, or a constraint the type can't express
  ("must be lowercase", "milliseconds since epoch", "never null for `CREATE`").
- **No chat / review / task / plan provenance.** It rots the moment the work
  lands.

```ts
// Bad — provenance + restates the obvious
/**
 * Returns the active user's id. Originally took a session object but we
 * simplified it after the review discussion (see the plan doc).
 */

// Good — states what it is, one sentence
/** Returns the active user's id. */
```

## Acceptable vs. anti-pattern

```ts
// GOOD — a non-obvious WHY the code can't show
// First snapshot (incl. empty collection) always runs, suppressing later
// metadata-only snapshots that report no document changes.

// GOOD — a warning the reader would miss
// Do not memoize — must re-run per render to read the live ref.
```

```ts
// BAD — restates the name
// Subscribes to a query.
function subscribeToQuery<T>(...)

// BAD — ephemeral plan reference
// Step 3 of the research spike; see docs/superpowers/plans/2026-06-17.
export const ingest = ...

// BAD — change narrative
// Switched from useState to Disclosure for ARIA correctness.
export function Section(...)
```

## Default posture

When uncertain, **delete the comment and improve the name or structure instead.**
Trust naming. The reader can always ask for a comment; they can't un-read noise.

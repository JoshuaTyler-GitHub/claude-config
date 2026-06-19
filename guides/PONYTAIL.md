# Ponytail Mode

Ponytail is a behavioral mode that forces the **laziest solution that actually
works** — simplest, shortest, most minimal. It channels a senior developer who
has seen every over-engineered codebase and been paged at 3am for one. Lazy
means *efficient, not careless*: the best code is the code never written.

Use it to fight bloat, boilerplate, speculative abstraction, and needless
dependencies. Pairs with [Caveman](./CAVEMAN.md) — caveman governs how you
*talk*, ponytail governs what you *build*.

## Toggle

| Action | Command |
| ------ | ------- |
| Turn on (default level) | "ponytail", "be lazy", "lazy mode", "simplest solution", "yagni" |
| Set level | `/ponytail lite` · `/ponytail full` (default) · `/ponytail ultra` |
| Turn off | "stop ponytail" / "normal mode" |

Once on, it persists every response until turned off — it does not drift back to
over-building.

## The ladder — stop at the first rung that holds

1. **Does this need to exist at all?** Speculative need → skip it, say so in one
   line. (YAGNI)
2. **Stdlib does it?** Use it.
3. **Native platform feature covers it?** `<input type="date">` over a picker
   lib, CSS over JS, a DB constraint over app code.
4. **Already-installed dependency solves it?** Use it. Never add a new dep for
   what a few lines can do.
5. **Can it be one line?** One line.
6. **Only then:** the minimum code that works.

Two rungs work → take the higher one and move on. The first lazy solution that
works is the right one. The ladder is a reflex, not a research project.

## Rules

- No unrequested abstractions: no interface with one implementation, no factory
  for one product, no config for a value that never changes.
- Deletion over addition. Boring over clever — clever is what someone decodes at
  3am. Fewest files, shortest working diff.
- Complex request? Ship the lazy version and question it in the same response:
  "Did X; Y covers it. Need full X? Say so."
- Two stdlib options the same size → take the one correct on edge cases. Lazy
  means writing less code, not picking the flimsier algorithm.

## Output shape

Code first. Then at most three short lines: what was skipped, when to add it.
No essays, no feature tours. If the explanation is longer than the code, delete
the explanation.

```
[code] → skipped: [X], add when [Y].
```

## When NOT to be lazy

Never simplify away: input validation at trust boundaries, error handling that
prevents data loss, security measures, accessibility basics, hardware
calibration knobs, or anything explicitly requested. User insists on the full
version → build it, no re-arguing.

Lazy code without its check is unfinished: non-trivial logic (a branch, a loop,
a parser, a money/security path) leaves **one** runnable check behind — the
smallest thing that fails if the logic breaks. Trivial one-liners need no test;
YAGNI applies to tests too.

## `ponytail:` comments — overridden in committed code

The ponytail skill normally marks deliberate simplifications with a
`// ponytail:` comment naming the shortcut and its upgrade path. **In this
org's committed code that convention is OFF** — see `.claude/guides/COMMENTS-GUIDE.md`,
which bans `ponytail:` tags. The laziness still applies; the *tag* does not. If a
shortcut has a real, timeless WHY or a known ceiling worth recording, write it as
a plain factual comment without the `ponytail:` prefix; if it's only process
scaffolding, delete it. Use the `/ponytail-debt` skill during a working session
to track deferrals instead of leaving tags in the source.

## Companion skills

- `/ponytail-review` — review a diff for over-engineering only: what to delete,
  what stdlib/native replaces it.
- `/ponytail-audit` — same, whole-repo: a ranked list of bloat to cut.
- `/ponytail-debt` — harvest deferred shortcuts into a ledger so "later" doesn't
  become "never".
- `/ponytail-help` — quick reference card.

# SonarQube & Lint Cleanup Guide

The repeatable playbook for clearing SonarQube findings in a Next.js +
TypeScript + Zod + HeroUI codebase. Each rule records **what it flags**, **the
fix**, an **example**, and — where relevant — **when to leave it**. Mechanical
fixes batch/parallelize; judgment fixes go one file at a time;
behavior-changing refactors get human sign-off. The repo's standard `.claude/`
conventions apply (alphabetical ordering, `@` alias imports, helpers at bottom,
`eslint --fix` hook auto-formats every edit).

## Process

1. **Find.** Get the real issue list — don't guess. Run the scanner
   (`npx @sonar/scan -Dsonar.host.url=… -Dsonar.token=…`) and read the
   facets by rule:
   `sonar api get "/api/issues/search?components=<key>&resolved=false&facets=rules,types,severities&ps=1"`.
2. **Triage.** Split by rule into three lanes: **bugs** (fix first), **safe
   mechanical** (batch), **judgment** (one at a time). Defer **cognitive
   complexity** (S3776) for human review — it restructures control flow.
3. **Fix mechanical in parallel.** Group files into batches, hand each batch +
   this cookbook to a subagent. Deterministic transforms; the compiler is the
   safety net.
4. **Fix judgment items yourself**, after the mechanical pass (so no two passes
   touch the same file concurrently). Re-locate by content, not stale line
   numbers.
5. **Verify with commands — never by inspection:** `npx tsc --noEmit` →
   `npm run test:unit` → `npm run lint` → re-scan and confirm the count dropped
   and `new_violations` is clean.
6. **Exclude vendor files** (bundled third-party CSS/JS) rather than editing
   them: add to `sonar.exclusions` in `sonar-project.properties`.

## Hard rules

- **Never delete an exported symbol** to satisfy a rule. Re-export fixes change
  *syntax*, not the export surface. (Starter-kit/library code especially.)
- **Preserve behavior.** Every fix here is equivalence-preserving unless the
  item is an actual bug.
- **Let the formatter format.** Make correct edits; the `eslint --fix` hook
  handles import/export ordering and spacing.
- **Leave a rule rather than regress.** When the rule and the code's intent
  genuinely disagree (see "When to leave it" entries), keep the code and record
  why. A green metric bought with a behavior change is a defect in disguise.

---

## Bugs (fix first)

### S3923 — conditional with identical branches
A ternary/`if` returns the same value both ways — almost always a copy-paste
slip. Find the intended difference; if the branches really are identical,
collapse to the single value (the live state is being driven elsewhere, e.g. a
`className`).
```tsx
// before — both branches 'tertiary'; the active state is set via className
variant={isHidden ? 'tertiary' : 'tertiary'}
// after
variant={'tertiary'}
```

### S3403 — strict equality with dissimilar types ("always true/false")
The analyzer infers a type whose index/return signature excludes `undefined`,
so `=== undefined` looks constant — even though at runtime it can be undefined
(empty array, missing map key). Express the real intent with an operator the
analyzer can't flag.
```ts
// before                              // after
if (positionals[0] === undefined)      if (positionals.length === 0)
if (devices[input] !== undefined)      if (Object.hasOwn(devices, input))
```

---

## Deprecated APIs — S1874

### Zod 4: `z.nativeEnum(E)` → `z.enum(E)`
Zod 4 folded native-enum support into `z.enum`. Drop-in, type-identical.
```ts
status: z.nativeEnum(PostStatus)   →   status: z.enum(PostStatus)
```

### React 19: `MutableRefObject<T>` → `RefObject<T>`
React 19 unified the two; `RefObject<T>` is now the mutable `{ current: T }`.
Rename the import and all uses.

> General approach for S1874: read the deprecation message, find the modern
> replacement in the library's current docs, confirm the version supports it,
> apply, and let `tsc` verify.

---

## Safe mechanical fixes (batchable)

### S7763 — re-exports should use `export…from`
Barrels that `import` a symbol then re-`export` it should re-export directly.
**Split by source module and by value-vs-type**; drop the now-unused import
(unless the symbol is also used in the file body). Getting value/type wrong
breaks the build, so `tsc` is the check.
```ts
// before
import { ThemedTable, ThemedTableProps } from './themed-table';
import { TableEvent, TableHooks } from './types';
export { TableEvent, ThemedTable };
export type { TableHooks, ThemedTableProps };
// after
export { ThemedTable } from './themed-table';
export type { ThemedTableProps } from './themed-table';
export { TableEvent } from './types';
export type { TableHooks } from './types';
```

### S7764 — prefer `globalThis` over `window`/`self`/`global`
Follow the message **literally**, because it protects SSR semantics:
- "Prefer `globalThis` over X" → replace the token with `globalThis`
  (`self.crypto` → `globalThis.crypto`, `window.location` → `globalThis.location`).
- "Prefer `globalThis.window` over `window`" → replace with `globalThis.window`.
  This is emitted for SSR guards: `typeof window` → `typeof globalThis.window`
  (still `'undefined'` on the server). **Never** turn `typeof window` into
  `typeof globalThis` — `globalThis` is always defined, which breaks the guard.

> **Follow-on (S7741):** once a guard reads `typeof globalThis.window ===
> 'undefined'`, SonarQube then flags the `typeof` as unnecessary — because
> `globalThis.window` is a *safe property access* that returns `undefined`
> rather than throwing like a bare undeclared `window` would. Finish the job:
> ```ts
> typeof globalThis.window === 'undefined'   →   globalThis.window === undefined
> typeof globalThis.window !== 'undefined'   →   globalThis.window !== undefined
> ```

### S7735 — negated condition with an `else`
Flip the condition and **swap the branches** (behavior identical):
```ts
if (!c) { A } else { B }            →   if (c) { B } else { A }
if (x !== y) { A } else { B }       →   if (x === y) { B } else { A }
!c ? a : b                          →   c ? b : a
```
**When to leave it:** an idiomatic existence check in JSX
(`href !== undefined ? <a> : <button>`) where flipping to "if no href, render
button" reduces readability. Positive-first reads better; keep it.

### S7781 — `replaceAll` over `replace` with a global regex
`s.replace(/re/g, x)` → `s.replaceAll(/re/g, x)`. Keep the regex and flags;
only touch global (`g`) calls.

### S7773 — `Number` static methods
`parseInt`/`parseFloat` → `Number.parseInt`/`Number.parseFloat` are 100%
equivalent. `isNaN(x)`/`isFinite(x)` → `Number.isNaN(x)`/`Number.isFinite(x)`
**only when `x` is already a number** — the global versions coerce, the
`Number.*` versions don't. If `x` might be a string, leave it.

### S7772 — `node:` protocol for built-ins
`from 'fs'` → `from 'node:fs'`, `require('path')` → `require('node:path')`.
Node built-ins only (fs, path, os, url, crypto, child_process, …).

### S7723 — call built-in constructors with `new`
`Error(...)` → `new Error(...)`, `RegExp(...)` → `new RegExp(...)`.
If a regex **literal** is being wrapped (`RegExp(/…/i)`), drop the wrapper
entirely — the literal is already a regex.

### S7755 — `.at(…)` for end-relative indexing
`arr[arr.length - 1]` → `arr.at(-1)`. **Caveat:** `.at()` returns `T | undefined`
(unlike `arr[i]` under default `noUncheckedIndexedAccess: false`). If the value
flows into a non-optional parameter, narrow it — replace a `length === 0` guard
with a `target === undefined` guard, which both fixes the type and reads better.

### S7753 — `indexOf` over `findIndex` for equality
`arr.findIndex((x) => x === key)` → `arr.indexOf(key)`.

### S7776 — `Set` for existence checks
An array built only for `.includes()` lookups should be a `Set` with `.has()`:
```ts
const keys = list.map((i) => i.key);      const keys = new Set(list.map((i) => i.key));
… && keys.includes(k)              →      … && keys.has(k)
```

### S6759 — React props should be read-only
`function C(props: P)` → `function C(props: Readonly<P>)` (or wrap an inline
prop type in `Readonly<…>`).

### S6594 — `RegExp.exec()` over `String.match()`
`str.match(re)` → `re.exec(str)` for a single (non-global) match. Both return
`null` on no-match and the same capture array; preserve the null check.
**Caveat:** `match` with a `/g` regex returns *all* matches — don't convert
those.

### S4624 — no nested template literals
Extract the inner template into a `const` above the outer one.
```ts
`… ${cond ? `, skip=[${list.join(', ')}]` : ''} …`
// →
const skipPart = cond ? `, skip=[${list.join(', ')}]` : '';
`… ${skipPart} …`
```

### S4325 — remove redundant casts / non-null assertions
If `x as T` doesn't change `x`'s type, delete it. `tsc` confirms it was
redundant (if it errors, the cast was load-bearing — restore it).

### S4043 — array-mutating method used as a value
`arr.filter(...).sort(...)` mutates the filtered array. Prefer the non-mutating
`.toSorted(...)` (ES2023 — confirm the tsconfig `lib`), or move the sort to its
own statement.

### S7780 — `String.raw` for escaped backslashes
A string literal full of `\\` should be a `String.raw\`…\`` template.

### S7785 — top-level `await`
In an ESM module, replace a top-level `main().catch(…)` promise chain with
`try { await main() } catch { … }`.

---

## Judgment fixes

### S6481 — Context Provider value must be stable
An inline object `value={{ … }}` re-creates every render, busting every
consumer. Wrap it in `useMemo` with all referenced fields as deps.
```tsx
const ctx = useMemo(() => ({ a, b, c }), [a, b, c]);
return <Ctx.Provider value={ctx}>…</Ctx.Provider>;
```

### S6479 — no array index as React `key`
Use a stable unique value (`key={item.id}`, `key={indices.join('-')}`).
**When to leave it:** the list has no stable id (e.g. a `string[]` that can
contain duplicates) and rows are positionally identified by design. Forcing a
content key risks duplicate-key collisions — leave it and note the design.

### S6564 — redundant type alias
`type S = UiState` used as a local shorthand adds indirection — inline the real
type and delete the alias. **Leave** genuinely-useful generic aliases
(`type S = EditorState<T>`) — those aren't redundant and SonarQube won't flag
them.

### S3358 — no nested ternary
Extract the inner ternary into a named `const` so each level is single. In JSX,
pull the branch into a variable above the return:
```tsx
const labelVisual = label === undefined ? null : <span>{label}</span>;
… icon === undefined ? labelVisual : <Svg src={icon} />
```

### S2004 — functions nested too deep (>4)
Extract the deepest inner function to a higher scope. **When to leave it:** the
inner closures capture local state so tightly that extraction means heavy
parameter threading with no real benefit (common in test/script harnesses).

### S4144 — functions with identical implementations
Usually a real duplicate to merge. **When to leave it:** two functions are
*type-distinct public API* whose bodies coincide only because an underlying call
is overloaded (e.g. `subscribeToDocument` vs `subscribeToQuery` over Firestore's
overloaded `onSnapshot`) — merging would lose the type-safe signatures.

### S7758 — Unicode-aware string methods
`charCodeAt` → `codePointAt`. **When to leave it:** a function deliberately
implements a spec that mandates UTF-16 code units (e.g. Java's `String.hashCode`)
— switching changes the output and breaks any persisted values.

### S5843 — regular expression too complex
Simplify only if you can do so *provably* equivalently. **When to leave it:** a
marginal overage (e.g. 22 vs 20) on a parser regex where any change risks
silent mis-parsing — the readability win isn't worth the correctness risk.

### S6848 — non-interactive element with an interactive handler
A `<div>` with handlers needs a role + keyboard support, or the interaction
belongs on a real control. For drag-and-drop zones this is a genuine a11y task
(pair with a file `<input>`), not a one-liner — treat as a tracked follow-up,
not a quick fix.

### S1135 — `TODO` comment
INFO-level. Can't be "fixed" without doing the TODO; leave it for the owner.

---

## Cognitive complexity — S3776 (human sign-off)

These restructure control flow, so they're reviewed individually, not batched.
The fix is never "delete logic" — Cognitive Complexity penalizes **nesting and
branching density**, so you **extract a self-contained branch into a named
function**, which lowers the score and clarifies intent.

Common shapes and their extractions:
- **CLI `for`+`switch` arg-parsers** → `parseXxxCliArgs(argv): Overrides`.
- **read→parse→validate config blocks** → `readXxxConfigFile(path): Config`.
- **recursive equality / traversal** → split the array branch and object branch
  into `arraysDeepEqual` / `objectsDeepEqual`; the entry point dispatches.
- **dry-run vs real-write procedures** → `runDryRun(...)` / `runWrite(...)`,
  with the entry point doing `if (dryRun) … else await …`.
- **repetitive guard blocks** (four `if (typeof x !== 'string') x = fallback`)
  → `applyFallbacks(obj)`.

Reuse types via `ReturnType<typeof builder>` and `SomeReport['stats']` to avoid
inventing new type names. `tsc` + the existing tests are the safety net; every
target should have test coverage before you refactor it.

---

## Quality-gate note

The default "Sonar way" gate guards **new code**. After a large cleanup you may
see the gate go ERROR on **`new_coverage < 80%`** — that's the absence of a
coverage report on changed lines, not a defect. Options: run tests with
`--coverage` and re-scan, relax that condition, or set a New Code baseline.
Distinct from code quality; report it as such, don't chase it with edits.

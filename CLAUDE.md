# Project Instructions

This file is loaded every session; the guides below are **not** — they load
only when you `Read` one. So this file states each rule in one line and points
to the guide that owns the worked example, the migration map, the full
skeleton. Read the guide before doing the work it covers.

## Guides & docs — read before the matching work

| Read before… | File |
| ------------ | ---- |
| Any work in the repo | `README.md`, `PROJECT.md` (architecture, services, routes, tenancy) |
| Touching data models / tenancy | `database/README.md`, `database/PLAN.md` |
| Touching Cloud Functions | `firebase/functions/README.md` |
| Resolving a media URL or touching `services/*-service.ts` storage paths | `.claude/guides/FIREBASE-GUIDE.md` (client/service/hook boundaries, `DynamicDocument` + schema, Cloud Storage media layout, `originals` vs `ingests`) |
| Writing or restructuring a component | `.claude/guides/REACT-GUIDE.md` (file structure, full skeleton, section markers, JSX / locale / hooks / state) |
| Using or migrating a HeroUI component | `.claude/guides/HEROUI-GUIDE.md` (v3 API + v2→v3 migration map + composition patterns) |
| Touching colors, fonts, spacing, theme tokens | `.claude/guides/UI-STYLE-GUIDE.md` (token surface, brand defaults, typography, radius, a11y) |
| Designing or changing an HTTP/RPC endpoint or service-method shape | `.claude/guides/GOOGLE-API-DESIGN-GUIDE.md` (resource-oriented design, Google AIPs) |
| Touching `widgets/google-maps-widget/` or embedding a map | `.claude/guides/GOOGLE-MAPS-GUIDE.md` (marker anchoring/sizing, the `.button svg` 16px trap) |
| Screenshotting / visually verifying the app | `.claude/guides/SCREENSHOT-GUIDE.md` (`npm run shot -- <route>` or `playwright` MCP) — **use sparingly**; for small high-confidence edits, `tsc` + `eslint` + tests suffice |
| Clearing SonarQube / lint findings | `.claude/guides/SONARQUBE-GUIDE.md` (rule-by-rule fix playbook) |
| Running graphify or citing its output | `.claude/guides/GRAPHIFY-GUIDE.md` (output lives in `.graphify/` only — never a `graphify-out/` sibling; query before rebuild) |
| Resuming work; checking what's queued/decided | `.claude/memories/` (backlog, plans, decisions — gitignored, local) |
| Writing a comment or JSDoc | `.claude/guides/COMMENTS-GUIDE.md` (refactor-before-comment ladder; timeless, factual, brief; no AI-chat / plan / change-narrative references) |
| Working token-lean (terse replies) | `.claude/guides/CAVEMAN.md` (caveman mode — toggle, levels, boundaries) |
| Avoiding over-engineering / deciding when to simplify | `.claude/guides/PONYTAIL.md` (ponytail mode — the laziness ladder, when not to be lazy) |
| Implementing from a Figma mockup, or making architecture diagrams | `.claude/guides/FIGMA.md` (Figma MCP for design context; translate values to tokens, not raw px) |
| Installing / toggling a skill or plugin | `.claude/guides/SKILLS.md` (lean-by-default; manifest + installer in `.claude/skills/`) |
| Connecting or toggling an MCP server | `.claude/guides/MCP.md` (standalone vs plugin-bundled; default ON/OFF set; manifest in `.claude/mcp/`) |
| Reading/extracting from a non-plain-text doc (PDF, docx, xlsx, image, audio…) | `.claude/guides/MARKITDOWN.md` (convert to markdown first; process via context-mode, never raw bytes) |
| Editing any folder | its nested `README.md` — and update it when the folder's contract changes |

## Code style

Examples for the React/HeroUI rules live in `.claude/guides/REACT-GUIDE.md` and
`.claude/guides/HEROUI-GUIDE.md`; this list is the rule, the guide is the worked case.

- **Alphabetical order everywhere** — keys, imports, helpers, props. No
  `// alphabetical` comments.
- **Class variables before class functions.**
- **`@` alias imports only** (`@components`, `@lib`, `@services`, `@redux`, …).
  Never `./` or `../`.
- **Respect `.prettierrc`.**
- **File layout: imports → constants → main export → helpers.** Helpers sit at
  the bottom under `@helpers`, never above the main export. Top-level marker
  order: `@imports` (grouped by source with `// group-name` comments),
  `@constants`, `@types`, `@component` / `@function`, `@helpers`. In-component
  body order: `@state` → `@derived` → `@callbacks` → `@effects` → `@render`.
  Full skeleton in `.claude/guides/REACT-GUIDE.md`.
- **Import-group comments only when the group has imports.** Remove the `//
  group` comment in the same edit that removes its last import — empty labeled
  gaps are noise.
- **Section markers are always the 3-line JSDoc form (`/**` · `* @section` ·
  `*/`), with a blank line directly above.** Never the one-line form — the
  blank-line + 3-line shape is what the reader's eye scans for. Every marker,
  top-level and in-function.
- **Components hold rendering logic only.** Date math, money / byte / string
  formatting, and any reusable computation live in `utils/` (`date-utils`,
  `money-utils`, …) or `lib/` — never in a component. Module-level numeric
  constants like `MS_PER_HOUR` live in `date-utils`. The `@helpers` block is
  for view-specific glue only; the moment a helper looks reusable, move it to a
  util.
- **Prefer component defaults; pass props only when they differ.** Shared
  components (`Flex` / `FlexRow` / `FlexColumn`, `Section`, `Card`,
  `TextField`, pickers, …) have thoughtful defaults — don't restate them at the
  call site. Same for `className`: add only classes that override or extend the
  component's own. The fewer props, the louder the deviations. If you keep
  writing the same override, the default is wrong — fix the default, not the
  call sites.
- **No inline arrow functions in JSX event-handler props.** Handler-shaped
  props (`onPress`, `onClick`, `onChange`, `onValueChange`, `onSelect`,
  `onSubmit`, `onFocus`, `onBlur`, `onKeyDown`, …) reference a `useCallback`
  from `@callbacks` or a stable direct reference (`onPress={toggle}`) — inline
  arrows allocate per render and defeat `React.memo`. Does **not** apply to
  transform callbacks (`.map`/`.filter`/`.then`). A list-row that must capture
  row data gets extracted to its own component so the handler can be a
  `useCallback` there.
- **Render-phase sync over `setState`-in-`useEffect`.** To react to a prop/state
  change, track the previous value in its own `useState` and call setters
  during render inside an `if` — not from an effect (synchronous setState in an
  effect cascades renders and trips `react-hooks/set-state-in-effect`). Effects
  stay correct for *external* sync (Firestore snapshots, DOM observation, async
  fetches). Example: the **State** section of `.claude/guides/REACT-GUIDE.md`.
- **HeroUI `Button` for interactive buttons — never native `<button>`.** Anything
  that fires an action on press uses `Button` from `@heroui/react` with
  `onPress`. For non-standard footprints, neutralize HeroUI's shape with
  className overrides rather than dropping to `<button>`. Native `<button>` is
  acceptable only for `role='button'` keyboard semantics where the primary
  interaction isn't a discrete press (drag handles, focus-shifters). Override
  example in `.claude/guides/HEROUI-GUIDE.md` → **Composition patterns**.
- **Single corner-radius: `rounded-3xl`.** Every container, panel, sheet, or
  rounded surface uses it, to line up with HeroUI's surface components (all on
  `--radius-3xl`). Not `rounded-lg`/`-md`/`-2xl`. Exceptions: `rounded-full`
  (circles, pills) and `rounded-none` (full-bleed overlays, grouped buttons,
  list-row dividers).
- **Tailwind utilities use whole-number scale steps only.** No fractional steps
  (`h-3.5`, `p-2.5`, `gap-1.5`) — pick the nearest whole step. Arbitrary values
  (`h-[14px]`) are banned for sizing/spacing unless the scale genuinely can't
  express it. (Full rule + table: `.claude/guides/UI-STYLE-GUIDE.md`.)
- **No magic-number sizing to make things line up — let flex/grid auto-fit.** A
  measured value copied between two places (an overlay sized to match a footer,
  a strip sized to a gap, a negative margin cancelling a parent's padding, an
  arbitrary `top-[88px]`) is a magic number — it breaks the moment either side
  changes. Instead: center with `items-center`/`justify-center`; equal-height
  with `flex-1`/`items-stretch`/`h-full`; place a control beside text as a real
  flex sibling (`justify-between`, title `flex-1 min-w-0`), not an absolute
  overlay; reserve text with `line-clamp-N`; fix sticky-header gaps structurally,
  not with a pixel cover. If a layout truly can't be auto-expressed, surface it.
- **Flex child overflows a narrow container? Add `min-w-0`.** An
  intrinsically-sized flex child (`TextField`/`Input`, `next/image`, `<canvas>`,
  a map) won't shrink below its content width. Fix the flex chain (not `max-w-*`):
  `min-w-0` on each flex item from constraining container down to the child,
  plus `w-full` on intermediate containers in a flex-**column** parent. Write-up
  in `.claude/guides/HEROUI-GUIDE.md` → **Input / TextField**.
- **Icons come from [Bootstrap Icons](https://icons.getbootstrap.com/).** Files
  in `public/icons/` are default-export TSX wrapping the raw 16×16 SVG body
  (`fill='currentColor'`); paste the inner shape unchanged — no wrapper, no
  `forwardRef`, no props. Consume via `<Svg src={icon_name} />` from
  `@components/svg`. Template in `public/icons/README.md`.
- **`??` for defaults, `||` for booleans only.** `||` treats `''`/`0`/`false`/
  `NaN` as missing — almost never wanted. Enforced by
  `@typescript-eslint/prefer-nullish-coalescing`.
- **No `!!` or `Boolean()` coercion.** Use explicit comparisons or lodash
  (`!isNil(x)`, `!isEmpty(x)`, `x !== ''`, `x > 0`). Implicit boolean coercion
  in `if`/`for`/`while`/ternary heads is also discouraged.
- **Optional-parameter shorthand: `param?: T`, not `param: T | undefined`.** Same
  for properties whose absence equals `undefined`. Keep the explicit form only
  when the key MUST be present (a discriminated-union slot).
- **No padding blank lines between statements.** Default tight — no blanks
  before `return`, before declarations, or between a conditional and the next
  statement. Blank lines belong only between **multi-line** expressions. The
  `padding-line-between-statements` rule is off and stays off.
- **Default to no comments.** Write one only for a non-obvious WHY, a hidden
  invariant, or a warning the reader would miss — and rename/extract before you
  reach for one. Full rule, the refactor-before-comment ladder, and the
  ephemeral-reference ban (no AI-chat / plan / change narrative) in
  `.claude/guides/COMMENTS-GUIDE.md`.
- **Auto-format on every AI edit.** `.claude/settings.json` runs `npx eslint
  --fix` after every Edit/Write — don't disable it. If you change ESLint config
  in a way that affects formatting, do a one-off Edit to confirm sane output.
- **Never add an import in an edit that doesn't also use it.** The `eslint --fix`
  hook strips unused imports on save (`unused-imports/no-unused-imports`), so an
  import whose consumer isn't yet in the file vanishes the instant you save.
  Land the import and its first use in the same edit; if incremental, write the
  consumer first. Same trap for a partial `{ A, B }` when the edit only uses `A`.

## Reuse before building

Before writing a new component, grid, list, form control, or utility, check
whether one exists. Reaching for the canonical building blocks first is the
single highest-leverage way to avoid review rework. When you catch yourself
hand-rolling a grid, a search/sort bar, a color picker, a file upload, or an
icon button, stop and find the existing one.

- **Browsable grid of records** → `CardGrid` (`@components/card-grid`) +
  `FilterToolbar` (`@components/filter-toolbar`); each card is a
  `PressableSurface` (`@components/pressable-surface`).
- **Search / sort / filter bar over a record list** → `SearchBar`
  (`@components/search-bar`).
- **Color picking** → `ColorSwatchPicker` (`@components/color-swatch-picker`).
  Don't hand-build swatch grids or hue sliders.
- **File upload** → `FileUploadWidget` (`@widgets/file-upload-widget`). To
  persist an image and reference it by id, dispatch an action whose listener
  calls `ImageService.createImage(file)` (a component must not call the service
  directly — see the dispatched-events invariant).
- **Icon-only / share buttons** → `IconButton` (`@components/icon-button`),
  `ShareButton` (`@components/share-button`). Never a raw `<Svg>` inside a
  `Button` — it won't center.
- **Surfaces** → `Section` / HeroUI `Card`; single radius `rounded-3xl`.
- **Max-width-capped, centered content column** → `Container`
  (`@components/container`) — a `FlexColumn` that centers (`mx-auto`), fills
  available width, and caps at a `size` from the Tailwind `max-w-*` scale
  (`2xs`…`7xl` / `full`, default `sm`). Use it instead of hand-writing
  `mx-auto w-full max-w-*`. Sizing detail in `.claude/guides/UI-STYLE-GUIDE.md`.

**Share at the component/utility layer — not by widening core types.** When
something needs the same *behavior* as a core entity but isn't the same *kind*
of thing, reuse the **components** and give it its own type — don't widen a core
union just to reuse a grid or filter, since that cascades through routing,
listeners, schemas, and Cloud Functions. Make the shared logic generic over a
small structural shape if needed.

**Build new things to be reused.** If a second caller is even plausible, make it
a small component in `components/<name>/` with an `index.ts`, configurable via
props/slots — not inlined in a page. Default to extracting the first time.

## Architectural invariants

- **Money: USD only, Stripe-shaped.** Integer cents in `amountCents` paired with
  `currency: z.literal('usd')`. Use `@utils/money-utils` (`formatMoney`,
  `toStripeAmount`, `fromStripeAmount`) for every conversion — never hardcode
  `* 100` / `/ 100` or `$${...}`. Reuse `type Stripe from 'stripe'`; don't
  redeclare. Don't reintroduce a `currency` parameter — when multi-currency
  lands, expand the helpers and remove the literal in one pass.
- **Top-level collections, field-based tenancy.** Tenant-scoped docs live at the
  top of Firestore (`/items/{id}`) with a `platformId` field. No
  `platforms/{pid}/…` nesting, no `DynamicDocument.scoped` flag —
  `isTenantScoped(doc)` is derived from the schema.
- **Scope, not platformContext.** Repositories and services accept a `Scope`
  from `@lib/firebase/platform-context` — `SingleScope` for entity ops,
  `MultiScope` / `AllScope` for collection ops.
- **Media storage: read `originals` / `resizes` / `processed`, never `ingests`.**
  Objects live at `{kind}/{stage}/{file}` (kinds: `audios`, `images`,
  `panoramas`, `videos`). `ingests/` is the transient upload entry point that
  fires the pipeline — not a runtime-readable asset; it's consumed/cleaned up
  and 404s on migrated data. Persistent original is `{kind}/originals/{id}.{type}`;
  derived `resizes/` are always `.jpeg`; playable audio is
  `audios/processed/{id}.{type}` (playable video under `videos/resizes/`).
  Resolve through each service's `getSources` + `@repositories/storage`
  `Storage.get` (a `getDownloadURL` RPC — no result cache, don't loop it). Full
  map in `.claude/guides/FIREBASE-GUIDE.md`; on-disk source of truth is
  `firebase/functions/src/lib/paths.ts` (mirrors `firebase/storage.rules`).
- **Denormalized two-way references are mandatory.** When A references B, B lists
  A back. Both sides update in the same batch — only `idSet` / `rankedSet` / id
  strings, never embedded full data. The reconcile pass repairs legacy drift but
  is not a substitute for write-side correctness.
- **Mutating service calls go through dispatched events, not direct calls from
  components.** Components / hooks / providers must NOT import `XService` and
  call `.create` / `.update` / `.delete` / `.upload`. Dispatch a typed
  `ClientActions.X_SET_Y({...})` via `useAppDispatch()`; a listener in
  `store/middleware/listeners/<entity>-listener.ts` calls the service. **Why:**
  writes must be observable for analytics, audit, optimistic updates, error
  funneling, cascades — a direct call bypasses all of it. Read-only calls
  (`getAll`, `count`, `get`) from components are fine. New mutation: enum entry
  → action creator → listener → register in `register-listeners.ts` → dispatch.
  Reference: `PLATFORM_MEMBERSHIP_SET_ROLE`. If the component needs the result,
  the listener dispatches `SystemActions.X_SAVED` / `NetworkActions.X_FAILED`
  back — don't `await` the dispatch.
- **Audit trail is server-only.** Client never writes `audit_events/{id}`. Cloud
  Function triggers emit one event per tenant-scoped mutation: a root event for
  user-initiated writes (uid from `metadata.updatedBy`) and cascade events
  (`automation: true`, `parentEventId` chained) for trigger-driven downstream
  writes. Cascade triggers stamp `metadata.updatedBy = __system__{originUid}` so
  the next layer detects cascades and avoids recursion. Don't reintroduce a
  `_lastEventId` field. Bare `__system__` (no suffix) is for
  scheduler / migration writes only.
- **Tailwind v4 + HeroUI v3 (CSS-first).** Theme tokens live in
  `styles/global.css` via `@import`, `@source`, `@theme`. No
  `tailwind.config.js` plugin entry. Migration map in `.claude/guides/HEROUI-GUIDE.md`;
  stylesheet layout + the two override patterns in `PROJECT.md` → **Styles**.
  Append new variant overrides to the bottom of `styles/global.css`.

## Error handling

- **Never swallow a caught error.** `.catch(() => undefined)`, `.catch(() => {})`,
  bare `catch {}`, and any catch that drops the error are **banned**. Every catch
  does all three:
  1. **Reports it** — `logger.error(...)` (or `logger.warn(...)` for recoverable
     degradation) via `createLogger('Name')` from `@log`. The logger mirrors to
     analytics, making a logged error the `UNHANDLED_EXCEPTION`-class signal we
     hunt regressions with. Minimum bar everywhere — services, repositories,
     listeners, plain functions, not just React.
  2. **Surfaces it when a UI exists** — a generic `toast.danger(message)`
     (`import { toast } from '@heroui/react'`) with a friendly, non-technical
     message. Never put the raw error or stack in the toast.
  3. **Keeps control flow honest** — re-throw, return a typed failure, or fall
     back with a logged reason. Never pretend it succeeded.
- **Mutation failures funnel through Redux.** The listener that catches a failed
  service call dispatches `NetworkActions.X_FAILED`; a reducer/selector drives
  the `toast.danger` + analytics. Components never silently drop a rejected
  dispatch.
- **Tolerable-degradation pattern.** When a missing resource is an expected,
  recoverable state, still catch-and-log (`logger.warn(...)` with enough
  identity to trace it) before falling back — never `.catch(() => undefined)`.
- **The one allowed silent catch is the error reporter itself** — the trailing
  `.catch` in `mirrorToAnalytics`, so reporting a failure can't recurse. Nowhere
  else.

## Testing

- **Default suite — `npm run test`** runs three fast unit suites in parallel
  (Ink TUI in `scripts/test.tsx`): `test:unit` (root jest), `test:functions:unit`
  (functions jest), `test:storybook` (vitest browser). Must stay green for any
  merge. Integration tests are deliberately **not** in this run.
- `test:unit` — root jest (jsdom); excludes `__tests__/stories/` and
  `__tests__/integration/`.
- `test:storybook` — Storybook interaction tests via vitest browser
  (`--project=storybook`); `:watch` for authoring.
- `test:functions:unit` — functions jest, no emulator.
- **Integration runs separately:** `test:integration` (root
  `__tests__/integration/**`, `TEST_INTEGRATION=true`) and `test:functions`
  (boots the Firebase emulator; won't run in a sandbox). Split out on purpose —
  the e2e tooling is still being built and must never gate everyday `npm run test`.

## Install

- `npm install --legacy-peer-deps` — required for an ESLint 10 peer-dep
  conflict. Drop the flag when upstream resolves.

## AI agents & isolated workspaces

- Delegate to specialized subagents when a task splits across domains; run
  independent agent calls in parallel. Don't delegate a one-shot lookup — `Read`
  / `Bash` beat a subagent there.
- **Never use git worktrees.** When work needs isolation, or multiple agents
  work different features at once, use a per-agent dev container:
  `npm run agent:new -- <name>` clones into `.agents/<name>/` on branch
  `agent/<name>` (gitignored, excluded from jest/tsc/eslint). Setup + egress
  firewall in `.devcontainer/README.md`.

## Memory & project state

Two stores, separate lanes, both local (neither shared via git):

- **`.claude/memories/`** — durable project working state in the tree:
  `next-steps.md` (backlog), `completed/`, `decisions/`, and plan files.
  Gitignored, so local to this checkout. Canonical home for project
  plans/decisions. See `.claude/memories/README.md`.
- **Per-user auto-memory** — Claude Code's `MEMORY.md` + `memory/` outside the
  repo. Personal preferences, feedback, recall hooks.

When a topic lives in both, the `memories/` file is canonical and the
auto-memory entry is a short pointer. Don't record project facts that
`CLAUDE.md`, `PROJECT.md`, a guide, or `git log` already answers.

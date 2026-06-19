# Screenshot Guide — capturing pages & features for visual review

Two ways for an agent to capture the running app. Both rely on the
**local auth bypass** (`NEXT_PUBLIC_AUTH_BYPASS='true'` +
`ENVIRONMENT='local'` in `.env.local`): every protected route renders as
the seeded platform (`PLATFORM_ID='cpa'`) with **no OAuth**, so any
`/admin/...` page is directly reachable.

(Reserve visual capture for large feature changes or tricky bugs — see
`CLAUDE.md` → "use it sparingly".)

## Prerequisite: a running server

Neither tool starts the server. Launch it once in the background, then capture:

```bash
npm run dev          # app routes  → http://localhost:3000
npm run storybook    # stories     → http://localhost:6006
```

Start it with a background Bash call (`run_in_background: true`) and poll
until the port answers before the first capture. Turbopack's first compile
of a route is slow — the first navigation to a cold route can take 20–40s;
the script's 60s default timeout covers it.

## Option A — the `shot` script (deterministic, scriptable)

Best for repeatable single captures. Run it, then `Read` the printed PNG path
(the Read tool renders images).

```bash
npm run shot -- items                  # gallery items page, current theme
npm run shot -- items --full           # full scrollable page
npm run shot -- items --theme both     # writes -light.png AND -dark.png
npm run shot -- admin --width 390 --height 844 --out admin-mobile
```

Output lands in `.screenshots/` (gitignored) and the absolute path is
printed on success — `Read` that path.

### Page names — the route convention

There are **three** surfaces for the same content, and "the items page" almost
always means the public **gallery** (the one that renders images). The script
encodes this so you don't grab the wrong one:

| You type | Resolves to | Surface |
| --- | --- | --- |
| `items` | `/platforms/<pid>/items` | **Gallery** (public, has images) |
| `collections`, `persons`, `map`, `info`, `landing` | `/platforms/<pid>/<name>` | Gallery |
| `editor:items` | `/platforms/<pid>/editor/items` | Platform editor |
| `admin:items` | `/admin/platforms/<pid>/items` | Admin (platform-scoped) |
| `admin:users`, `admin:analytics` | `/admin/<name>` | Admin (global) |
| `admin`, `editor`, `gallery` | surface home | — |
| `/anything/with/a/leading/slash` | unchanged | literal route |

`<pid>` defaults to `NEXT_PUBLIC_PLATFORM_ID` (`cpa`); override with
`--platform <id>`. Detail pages work too: `items/<itemId>`,
`editor:items/<itemId>`. The three surfaces differ — the gallery renders
real thumbnails (`ContentTiles` → `ContentImage`); the editors are
title-only browse/edit views. Don't reach for `admin:items` expecting
photos.

### Capturing a modal / drawer / single element

HeroUI overlays render in a portal at the document root. Open the overlay with
`--click`, wait for it, then shoot the whole page or isolate the overlay with
`--select`:

```bash
# Just the dialog/drawer, not the page behind it
npm run shot -- editor:items \
  --click "button:has-text('New item')" \
  --wait "[role=dialog]" \
  --select "[role=dialog]" \
  --out new-item-drawer
```

Common selectors: `[role=dialog]` (Modal/Drawer), `[role=menu]`
(Dropdown), `[data-slot=base]` for a specific HeroUI component instance.
Prefer a stable `data-testid` when one exists.

### Device profiles

`--device <name>` emulates a real device — viewport **plus** device-scale
factor, user-agent, and touch/mobile flags (which drive the app's responsive
breakpoints), not just width/height. Output filenames include the device, so
a matrix of devices doesn't overwrite.

```bash
npm run shot -- items --device "iPhone 16 Pro Max"
npm run shot -- items --device "iPad Mini" --landscape
npm run shot -- items --device "MacBook Pro 16" --theme dark
npm run shot -- --list-devices            # every preset + its dimensions
```

`--list-devices` prints the full set across phone / tablet / desktop / watch
/ presentation (iPhone SE→16 Pro Max, Pixel 7, Galaxy S24, Galaxy Z Fold 5,
iPad Mini/Air/Pro 11/Pro 13, Galaxy Tab S9, MacBook Air 13/Pro 14/Pro 16,
Desktop presets, Apple Watch, 16:9). Names are case/spacing-insensitive, and
any Playwright device name (e.g. `"Pixel 5"`) also works verbatim. Profiles
Playwright lacks (iPhone 16 family, Z Fold 5, iPad Pro 13", MacBooks) are
defined in the `DEVICES` table at the top of `scripts/screenshot.mjs` — edit
there to add or tune one (foldable dimensions are approximate). `--width` /
`--height` still override the device's viewport if you need a custom size.

### Storybook stories

```bash
npm run shot -- --storybook components-button--primary --theme dark
```

The story id is the kebab path from the sidebar URL (`?id=...`). Theme is
forced via `localStorage['theme']`, same as the app.

### Key flags

| Flag | Meaning |
| --- | --- |
| `--device <name>` | Emulate a device (viewport + DPR + UA + touch) |
| `--landscape` | Rotate the device (swap width/height) |
| `--list-devices` | Print all device presets and exit |
| `--theme light\|dark\|both\|system` | Force theme; `both` emits two files |
| `--full` | Whole scrollable page (default: viewport only) |
| `--select <css>` | Capture one element/overlay |
| `--click <css>` | Click before capture (repeatable — chain a flow) |
| `--wait <css>` | Wait for selector visible before capture |
| `--no-images` | Skip the image-load wait (faster; may capture blank media) |
| `--width` / `--height` | Viewport size; overrides `--device` (default 1440×900) |
| `--settle <ms>` | Extra delay after the waits below (default 500) |
| `--out <name>` | Output basename |

Run `npm run shot -- --help` for the full list.

### What the script waits for (and what it can't)

Before capturing, the script automatically: (1) waits for every HeroUI loading
spinner (`[data-slot="spinner"]`) to disappear, then (2) waits for image
requests to go idle — media loads lazily (a card resolves a Storage URL on
scroll-into-view via framer `useInView`, *then* fetches the `next/image`). Each
wait is best-effort: it prints a `⚠` and captures anyway on timeout, so a stuck
page still yields a screenshot.

`--full` doesn't use Playwright's `fullPage` — the app scrolls an inner
`<main>`, so `fullPage` (document height) would capture only the viewport.
Instead it grows the viewport to the content height, which also forces every
lazy `useInView` row into view to load, then waits for images again. Capped
at ~16k px (Chromium's single-shot limit); taller pages are truncated.

> **Never wait on `networkidle`.** Firestore `onSnapshot` holds a long-poll
> connection open forever, so the network never idles. The script keys on
> image-resource requests specifically (ignoring XHR), plus the spinner
> signal. If you script Playwright directly, do the same.

> **An empty card body is not always a load failure — check the surface.**
> The **gallery** (`items`, `/platforms/<pid>/items`) renders real thumbnails
> via `ContentTiles` → `ContentImage`. The **editor** surfaces (`editor:items`,
> `admin:items`) render title-only link cards (`ContentCard` with just
> `title` + `href`) — **no thumbnails by design**. If you wanted photos and
> got blank cards, you're probably on an editor surface; switch to the bare
> gallery name. Don't "fix" it by waiting longer.

> **Editor/detail pages may not finish loading headless.** The item editor
> dispatches `item-load` and waits for a Redux result that (per the
> in-progress editor-Redux migration) may never arrive without a real
> client session, leaving it on "Loading . . ." — you'll see the spinner
> `⚠`. That's an app-wiring state, not a tooling bug; no `--settle` fixes it.

## Option B — Playwright MCP server (interactive)

Wired in `.mcp.json` (server name `playwright`). Approve it when the
session prompts, then drive the browser with `browser_*` tools — best when
a feature needs several steps before the shot (navigate → fill form →
open drawer → screenshot), or when you need to read the accessibility
snapshot to find selectors.

```text
browser_navigate("http://localhost:3000/platforms/cpa/items")   # gallery
browser_snapshot()                       # a11y tree → find the control
browser_click("...")
browser_take_screenshot({ filename: "items-gallery.png" })
```

The MCP takes full URLs, so the `shot` page-name convention doesn't apply —
map it yourself: gallery `=> /platforms/<pid>/<page>`, platform editor
`=> /platforms/<pid>/editor/<page>`, admin `=> /admin/platforms/<pid>/<page>`
(or `/admin/<page>` for global admin pages). The gallery is the
image-bearing one; the editors are title-only.

### Device emulation in the MCP

The stock server emulates a device **per launched session** (not per call)
via its launch flags — `--device`, `--viewport-size`, `--user-agent`. To run
an interactive mobile session, add a second entry to `.mcp.json` and approve
it once:

```json
"playwright-mobile": {
  "command": "npx",
  "args": ["-y", "@playwright/mcp@latest", "--browser", "chromium",
           "--device", "iPhone 15"]
}
```

Caveats: `--device` accepts only **Playwright registry** names (no MacBooks /
iPhone 16 / Z Fold — those are script-only), and the whole session is locked
to that one device. Mid-session, `browser_resize` changes only width/height
(not DPR/UA/touch). **For a real per-device matrix or any custom profile, use
the `shot` script (`--device`) — that's the authoritative path.**

Use Option A when you know exactly what you want — and for all device
profiles; Option B when you need to explore or interact first.

## Which page is which

`cpa` is the seeded tenant (the alias default). The three surfaces:

- **Gallery** (public, image-bearing) — `items`, `collections`, `persons`,
  `map`, `info`, `landing` → `/platforms/cpa/<page>`
- **Platform editor** — `editor:items`, `editor:collections`,
  `editor:persons`, `editor:users`, `editor` → `/platforms/cpa/editor/<page>`
- **Admin** — `admin` (shell), `admin:items` / `admin:collections` /
  `admin:persons` / `admin:storage` (platform-scoped),
  `admin:users` / `admin:analytics` / `admin:commerce` (global)

Standalone routes are literals: `/landing`, `/sign-in`, `/dev/...`. Full
route map: `PROJECT.md`.

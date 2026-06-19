# `.claude/` — agent context

A reusable Claude Code config: project instructions, on-demand domain guides, the
skills/plugins/MCP servers they depend on, and an installer. Drop it into a
project's `.claude/` directory and every session inherits the standards.

## Quick start

```bash
# From your project root — get this config into .claude/:
git clone <this-repo-url> .claude          # or copy its contents into an existing .claude/

# Install the skills, plugins, and MCP servers the guides depend on:
.claude/install.sh                         # idempotent — safe to re-run

# Restart Claude Code (or run /mcp) so the new servers connect.
```

That's it. `CLAUDE.md` loads automatically every session; the guides load only
when a task needs one.

## How it works

**`CLAUDE.md` is the only always-loaded file.** It's a lean index of one-line
rules plus a table that points to the guides. Everything deep — worked examples,
API maps, full skeletons — lives in `guides/` and loads **only when an agent
`Read`s it**, triggered by a "read before X" pointer.

- **Keep `CLAUDE.md` lean.** Every line costs context on every session. A new rule
  goes in as one line + a pointer; the depth goes in the guide.
- **Never `@`-import a guide from `CLAUDE.md`.** A `@guides/FOO.md` line force-loads
  that file into every session — the exact cost the pointer model avoids. Reference
  guides by path in prose, not with `@`.
- **`skills/` and `mcp/` are manifests, not vendored dumps.** Third-party plugins
  install from their marketplaces (staying in sync with upstream); only loose,
  team-owned skills (`graphify`, `markitdown`) are copied in. `install.sh` wires
  up all three install mechanisms — see `skills/README.md` and `mcp/README.md`.

### Adding a guide

1. Write `guides/<NAME>.md` — one topic, self-contained, with the worked examples.
2. Add a row to the table in `CLAUDE.md` (`Read before… | .claude/guides/<NAME>.md`)
   and to the `guides/` table below.
3. If it depends on a skill/plugin/MCP server, add that to `skills/` or `mcp/` and
   to `install.sh`.

### Updating / contributing

This is a shared template — change a standard with a PR to this repo, not by
editing a copy in one project. Keep the `CLAUDE.md` table and the `guides/` table
below in sync with the files on disk.

## Layout

### Root

| File | What it is |
| ---- | ---------- |
| `CLAUDE.md` | Project instructions: code style, architectural invariants, error handling, testing. **Always loaded** — keep it lean; depth lives in `guides/`. |
| `settings.json` | Shared Claude Code settings (incl. the format-on-edit hook). |
| `settings.local.json` | Per-developer settings overrides (gitignored). |
| `memories/` | Project working state — backlog, plans, decisions. Gitignored / local (see below). |
| `skills/` | The skills/plugins the guides depend on (manifest + vendored `graphify`, `markitdown`) — see `skills/README.md`. |
| `mcp/` | The MCP servers the team uses (manifest + `mcp.json`) — see `mcp/README.md`. |
| `install.sh` | One-shot installer: adds marketplaces, installs plugins, vendors loose skills, registers MCP servers. Idempotent. |

### `guides/` — read before the matching work

| File | What it is | Read before… |
| ---- | ---------- | ------------ |
| `FIREBASE-GUIDE.md` | Firestore client/service/hook boundaries, `DynamicDocument` + schema pattern, Cloud Storage media layout. | Resolving a media URL or touching `services/*-service.ts` storage paths. |
| `REACT-GUIDE.md` | React component file structure, section markers, JSX/locale/hooks/state conventions. (TS baseline = Google TS Style Guide.) | Writing or restructuring a component. |
| `UI-STYLE-GUIDE.md` | The design system: HeroUI v3 token surface, brand defaults, typography, radius, accessibility. | Touching colors, fonts, spacing, or theme tokens. |
| `HEROUI-GUIDE.md` | HeroUI v3 component API reference + v2→v3 migration map + composition patterns. | Using or migrating a HeroUI component. |
| `GOOGLE-API-DESIGN-GUIDE.md` | Resource-oriented API design standard (Google AIPs): names, methods, fields, errors, versioning, compatibility. | Designing or changing an HTTP/RPC endpoint or service-method shape. |
| `GOOGLE-MAPS-GUIDE.md` | Custom map widget, marker anchoring/sizing gotchas. | Touching `widgets/google-maps-widget/` or embedding a map. |
| `SCREENSHOT-GUIDE.md` | Capturing a running page/feature for visual review (`npm run shot` / `playwright` MCP). | Screenshotting the app or verifying a change visually. |
| `SONARQUBE-GUIDE.md` | Rule-by-rule playbook for clearing SonarQube / lint findings without suppressing them. | A SonarQube or lint cleanup pass. |
| `GRAPHIFY-GUIDE.md` | Running graphify; its output store lives in `.graphify/` only (never a `graphify-out/` sibling); query the existing graph before rebuilding. | Running graphify in a repo or citing its output. |
| `MARKITDOWN.md` | Converting non-plain-text docs (PDF, docx, xlsx, pptx, images, audio…) to markdown; process via context-mode, never raw bytes. | Reading/extracting from a rich or binary document. |
| `COMMENTS-GUIDE.md` | When (rarely) to comment: refactor-before-comment ladder, timeless/factual/brief rule, and the ban on ephemeral references (AI chats, plans, change narrative, `ponytail:` tags). | Writing a code comment or JSDoc. |
| `CAVEMAN.md` | Caveman mode — terse, token-lean replies: toggle, levels, auto-clarity, boundaries. | Working token-lean. |
| `PONYTAIL.md` | Ponytail mode — the laziest-that-works ladder, when *not* to be lazy. | Deciding how much to build / fighting over-engineering. |
| `FIGMA.md` | Figma for designs, mockups, and architecture diagrams; the Figma MCP for design context; translating frame values to design-system tokens. | Implementing from a Figma mockup or making a diagram. |
| `SKILLS.md` | What skills/plugins the team depends on, lean-by-default policy, how they install. | Installing or toggling a skill/plugin. |
| `MCP.md` | MCP servers: standalone vs plugin-bundled, the default ON/OFF set, toggling on demand. | Connecting or toggling an MCP server. |

## `memories/` vs. per-user auto-memory

Two memory stores in separate lanes — both local, neither shared via git (full
rule in `CLAUDE.md` → **Memory & project state**):

- **`memories/`** (here, in the working tree) — durable project working state:
  `next-steps.md` (backlog), `completed/`, `decisions/`, and plan files. The
  canonical home for facts about *the project*. **Gitignored** (`.gitignore`),
  so local to this checkout.
- **Per-user auto-memory** (Claude Code's `MEMORY.md` + `memory/`, outside the
  repo) — personal preferences, feedback, and recall hooks.

When a topic appears in both, the `memories/` file is canonical for project
facts and the auto-memory entry is a short pointer.

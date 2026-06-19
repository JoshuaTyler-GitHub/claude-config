# MCP Servers Guide

An **MCP server** gives the agent tools and resources from an external process
(a browser, a docs index, a database). They cost context — each connected server
injects its instructions and tool list every session — so the rule is **lean by
default, toggle on demand**. The machine-readable manifest and the installer
live in [`../mcp/`](../mcp/README.md).

## Two kinds, two install paths

- **Standalone servers** — registered directly with Claude Code via
  `claude mcp add <name> <command>` (user scope). The only one this repo
  configures is **markitdown** (`markitdown-mcp`, stdio). Definitions live in
  `mcp/mcp.json`.
- **Plugin-bundled servers** — provided by an installed plugin, not registered
  separately. `context7`, `firebase`, `serena`, `playwright`, `sonarqube`, and
  `context-mode` all arrive this way. Install/toggle them as plugins (see
  [SKILLS.md](./SKILLS.md)), not with `claude mcp add`.

## Lean policy — what's on by default

| State | Servers |
| ----- | ------- |
| **Default ON** (dev core) | `context-mode`, `context7`, `firebase`, `serena`, `sequential-thinking` |
| **Default OFF** (enable per task) | `chrome-devtools`, `playwright` |
| **User-scoped, toggle via `/mcp`** | `markitdown` (active), `memory`, `sonarqube` |

## Toggling on demand

MCP connections bind at startup — flipping a flag does **not** hot-swap a server
into the current turn. To use a default-OFF server: enable it (plugin flag or
re-add the server), then `/mcp` to reconnect (or restart), and disable it again
when the task is done. Never *remove* a server to disable it — disabling must be
reversible.

## Configure

The combined installer (`./install.sh` at the repo root) registers the
standalone servers from `mcp/mcp.json`. Optional parked servers (their commands
are in `mcp/README.md`) stay off until you add them deliberately.

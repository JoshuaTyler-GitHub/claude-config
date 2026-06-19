# skills/

The skills and plugins the guides depend on, plus the installer that sets them
up. Lean-by-default rationale and per-skill detail: [`../guides/SKILLS.md`](../guides/SKILLS.md).

This is a **manifest, not a vendor dump** — third-party plugins install from
their marketplaces (so they stay in sync with upstream) rather than being copied
in. The one exception is `graphify`, a loose skill vendored here as a directory.

## Manifest

| Name | Type | Source | Install |
| ---- | ---- | ------ | ------- |
| `caveman` | plugin (3rd-party) | `JuliusBrussee/caveman` | marketplace add + install |
| `ponytail` | plugin (3rd-party) | `DietrichGebert/ponytail` | marketplace add + install |
| `context-mode` | plugin (3rd-party) | `mksglu/context-mode` | marketplace add + install |
| `playwright` | plugin (official) | `claude-plugins-official` | install |
| `sonarqube` | plugin (official) | `claude-plugins-official` | install |
| `firebase` | plugin (official) | `claude-plugins-official` | install |
| `serena` | plugin (official) | `claude-plugins-official` | install |
| `context7` | plugin (official) | `claude-plugins-official` | install |
| `figma` | plugin (official) | `claude-plugins-official` | install |
| `graphify` | loose skill (vendored) | `./graphify/` | copied to `~/.claude/skills/` |
| `markitdown` | loose skill (vendored) | `./markitdown/` | copied to `~/.claude/skills/` |

`claude-plugins-official` is a default marketplace, so official plugins need no
`marketplace add`.

## Install

From the repo root:

```bash
./install.sh
```

It adds the third-party marketplaces, installs every plugin above, copies
`graphify/` into `~/.claude/skills/`, and registers the standalone MCP servers
from [`../mcp/`](../mcp/README.md). Idempotent — safe to re-run.

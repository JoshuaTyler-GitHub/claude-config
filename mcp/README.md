# mcp/

The MCP servers the team uses, in the same manifest style as [`../skills/`](../skills/README.md).
Policy, default ON/OFF set, and toggling: [`../guides/MCP.md`](../guides/MCP.md).

`mcp.json` holds the **standalone** server definitions registered with
`claude mcp add`. Plugin-bundled servers (`context7`, `firebase`, `serena`,
`playwright`, `sonarqube`, `context-mode`) are *not* here — they install with
their plugin (see [`../skills/`](../skills/README.md)).

## Manifest

| Server | Transport | Provided by | Default | Defined in |
| ------ | --------- | ----------- | ------- | ---------- |
| `markitdown` | stdio (`markitdown-mcp`) | standalone | on (user scope) | `mcp.json` |
| `context-mode` | stdio | plugin | on | plugin |
| `context7` | stdio | plugin | on | plugin |
| `firebase` | stdio | plugin | on | plugin |
| `serena` | stdio | plugin | on | plugin |
| `sequential-thinking` | stdio | plugin | on | plugin |
| `playwright` | stdio | plugin | off (enable per task) | plugin |
| `chrome-devtools` | stdio | plugin | off (enable per task) | plugin |
| `figma` | stdio (Dev Mode) | plugin | on-demand (needs Figma desktop) | plugin |

## Optional / parked standalone servers

Not registered by default; add deliberately when needed:

```bash
# memory — persistent knowledge graph
claude mcp add memory npx -- -y @modelcontextprotocol/server-memory
#   env MEMORY_FILE_PATH=~/.claude/mcp-memory.json

# sonarqube as a standalone server (alternative to the plugin)
claude mcp add sonarqube sonar -- run mcp
```

## Install

From the repo root, `./install.sh` registers every server in `mcp.json`.
Idempotent — safe to re-run.

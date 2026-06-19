# Skills Guide

A Claude Code **skill** is a packaged capability the agent invokes on demand —
loaded from `.claude/skills/<name>/SKILL.md`, from an installed **plugin**, or
vendored in this repo. This guide covers what the team relies on and how it's
installed; the machine-readable manifest and the installer live in
[`../skills/`](../skills/README.md).

## Lean by default

Skills and plugins cost context — each one injects instructions and a tool
listing every session. Keep only the dev-core set active and reach for the rest
per task. Prefer a skill over re-deriving work by hand (graphify over re-reading
files, context-mode over dumping large output into context), but don't keep a
heavy plugin enabled when nothing in the current task needs it. Toggle with
`claude plugin enable <name>` / `disable <name>`, or `/plugin` in the TUI.

## What the guides depend on

| Skill / plugin | Why the team needs it | Referenced by |
| -------------- | --------------------- | ------------- |
| `caveman` | Terse, token-lean replies | [CAVEMAN.md](./CAVEMAN.md) |
| `ponytail` | Anti-over-engineering discipline | [PONYTAIL.md](./PONYTAIL.md) |
| `context-mode` | Process large output in a sandbox; only the answer enters context | Project token policy |
| `graphify` | Answer architecture questions from a knowledge graph | [GRAPHIFY-GUIDE.md](./GRAPHIFY-GUIDE.md) |
| `playwright` | Drive a headless browser for screenshots / visual checks | [SCREENSHOT-GUIDE.md](./SCREENSHOT-GUIDE.md) |
| `sonarqube` | SonarQube/lint findings surfaced in-session | [SONARQUBE-GUIDE.md](./SONARQUBE-GUIDE.md) |
| `firebase` | Firestore / Functions / Storage operations | [FIREBASE-GUIDE.md](./FIREBASE-GUIDE.md) |
| `figma` | Pull design/mockup context into code; author diagrams | [FIGMA.md](./FIGMA.md) |
| `serena`, `context7` | Symbol search; live library docs | Project-wide |

## How they install

Three mechanisms — the installer (`skills/install.sh`) handles all of them:

- **Official-marketplace plugins** (`playwright`, `sonarqube`, `firebase`,
  `serena`, `context7`): `claude plugin install <name>@claude-plugins-official`.
- **Third-party-marketplace plugins** (`caveman`, `ponytail`, `context-mode`):
  add the marketplace first (`claude plugin marketplace add <owner/repo>`), then
  `claude plugin install <name>@<marketplace>`.
- **Vendored loose skill** (`graphify`): copied from `skills/graphify/` into
  `~/.claude/skills/` — self-contained in this repo, no marketplace.

MCP servers are a separate concern — see [MCP.md](./MCP.md) and
[`../mcp/`](../mcp/README.md).

Run the combined installer from the repo root: `./install.sh`.

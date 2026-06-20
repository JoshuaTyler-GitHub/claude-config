#!/usr/bin/env bash
# Install the skills, plugins, and MCP servers the guides depend on.
# Manifests: skills/README.md, mcp/README.md. Idempotent — safe to re-run.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "error: 'claude' CLI not found on PATH." >&2
  exit 1
fi

note() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# Third-party marketplaces (owner/repo) -> plugin name to install from each.
THIRD_PARTY_MARKETPLACES=(
  "JuliusBrussee/caveman"
  "DietrichGebert/ponytail"
  "mksglu/context-mode"
)
THIRD_PARTY_PLUGINS=(
  "caveman@caveman"
  "ponytail@ponytail"
  "context-mode@context-mode"
)
OFFICIAL_PLUGINS=(
  "superpowers@claude-plugins-official"
  "playwright@claude-plugins-official"
  "sonarqube@claude-plugins-official"
  "firebase@claude-plugins-official"
  "serena@claude-plugins-official"
  "context7@claude-plugins-official"
  "figma@claude-plugins-official"
)

note "Adding third-party marketplaces"
for m in "${THIRD_PARTY_MARKETPLACES[@]}"; do
  claude plugin marketplace add "$m" || echo "  (already added: $m)"
done

note "Installing plugins"
for p in "${THIRD_PARTY_PLUGINS[@]}" "${OFFICIAL_PLUGINS[@]}"; do
  claude plugin install "$p" || echo "  (skipped: $p)"
done

note "Vendoring loose skills into ~/.claude/skills/"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$REPO_DIR"/skills/*/; do
  name="$(basename "$skill_dir")"
  rm -rf "$HOME/.claude/skills/$name"
  cp -R "$skill_dir" "$HOME/.claude/skills/$name"
  echo "  $name -> ~/.claude/skills/$name"
done

note "Setting up crawl4ai venv (web fetch/search off the harness throttle)"
CRAWL_VENV="$HOME/.venvs/crawl4ai"
CRAWL_SKILL="$REPO_DIR/skills/crawl4ai"
PYBIN="$(command -v python3.12 || command -v python3 || true)"
if [ -z "$PYBIN" ]; then
  echo "  (skipped: no python3 on PATH)"
else
  [ -d "$CRAWL_VENV" ] || "$PYBIN" -m venv "$CRAWL_VENV"
  if "$CRAWL_VENV/bin/pip" install -qU crawl4ai; then
    "$CRAWL_VENV/bin/crawl4ai-setup" || echo "  (crawl4ai-setup had issues — run crawl4ai-doctor)"
    cp "$CRAWL_SKILL/fetch_md.py" "$CRAWL_SKILL/search.py" "$CRAWL_VENV/"
    echo "  crawl4ai -> $CRAWL_VENV"
  else
    echo "  (skipped: crawl4ai pip install failed)"
  fi
fi

note "Registering standalone MCP servers from mcp/mcp.json"
# Parse mcp.json with the bundled python3 and register each stdio server.
python3 - "$REPO_DIR/mcp/mcp.json" <<'PY'
import json, shlex, subprocess, sys
servers = json.load(open(sys.argv[1])).get("mcpServers", {})
for name, cfg in servers.items():
    cmd = ["claude", "mcp", "add", name, cfg["command"]]
    args = cfg.get("args") or []
    if args:
        cmd += ["--"] + args
    print("  +", name, "->", shlex.join(cmd[3:]))
    subprocess.run(cmd, check=False)
PY

note "Done"
echo "Restart Claude Code or run /mcp to connect the new servers."

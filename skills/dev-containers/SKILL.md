---
name: dev-containers
description: Use when work needs isolation from the host or the main workspace, when multiple agents or features run in parallel, or when about to reach for a git worktree — set up or enter a dev container instead.
---

# Dev containers

## Overview

A dev container is an isolated Docker environment that runs Claude Code, the
terminal, and build tools *inside the container* while your repo is bind-mounted
in, so edits still appear on the host. **This is the mandated isolation
mechanism — git worktrees are forbidden** (project + global rule). Anything that
proposes a worktree (including `superpowers:using-git-worktrees`) is overridden;
substitute the steps below.

## When to use

- Work must not touch the current workspace (risky migration, throwaway spike).
- Two or more agents/features run at once and would collide on one tree.
- You were about to create a git worktree → stop, do this instead.

## Fresh-device setup (one time)

Reproduce the full preferred setup on a new machine in three steps:

1. **Add the `.devcontainer/devcontainer.json` template** (below) at the repo root.
2. **Add the two scripts** (`scripts/new-devcontainer.sh`, `scripts/prune-devcontainers.sh`
   below), `chmod +x` both.
3. **Gitignore the agent checkouts**: append `.agents/` to `.gitignore`.

Then `scripts/new-devcontainer.sh <task-slug>` creates and opens an isolated
container, idempotently. Prereqs: Docker Desktop running, VS Code **Dev
Containers** extension (`ms-vscode-remote.remote-containers`) installed.

## Naming — after the task, not the agent

Use a short kebab-case slug describing the work — `token-metering-spike`,
`fix-auth-redirect`, `audit-logs` — so the folder, branch (`agent/<slug>`), and
VS Code window title say what's running at a glance. With several containers open
at once, generic names (`agent-2`, `sandbox`, `test`, `tmp`) make them
indistinguishable and easy to edit in the wrong tree. Match an existing
ticket/branch name if there is one.

## The `.devcontainer/devcontainer.json` template

```json
{
  "name": "<repo-name>",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/java:1": { "version": "21" },
    "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {}
  },
  "remoteUser": "vscode",
  "shutdownAction": "stopContainer",
  "runArgs": ["--label", "com.docker.compose.project=devcontainers"],
  "mounts": [
    "source=claude-code-config-shared,target=/home/vscode/.claude,type=volume"
  ]
}
```

Each line encodes a preference:

- **`remoteUser: vscode`** — the `base:ubuntu` image ships user `vscode`, NOT
  `node`. Setting `remoteUser: node` makes the container build but fail to start
  with `unable to find user node`. (`node` only exists on `javascript-node`
  images.) Mount target must match: `/home/vscode/.claude`.
- **`shutdownAction: stopContainer`** — closing the VS Code window stops the
  container (stops, not removes — reopen is fast, state survives). Stops when the
  *last* window on it closes.
- **`runArgs` group label** — `com.docker.compose.project=devcontainers` is the
  key Docker Desktop groups by, so all dev containers collapse under one
  **devcontainers** section instead of cluttering the list. Set at container
  *creation* — existing containers need a rebuild to move into the group.
- **shared auth volume** — a *fixed* source name (`claude-code-config-shared`,
  not `${devcontainerId}`) means every container mounts the same `~/.claude`.
  Authenticate `claude` once per machine; every later container — any slug —
  inherits the login. (Per-`${devcontainerId}` would force a fresh login per
  workspace.)
- **java feature** — drop it if the repo has no JVM tooling; keep node +
  claude-code always (the CLI feature needs Node present).

Drop `image` if the repo uses a `Dockerfile` instead.

## `scripts/new-devcontainer.sh`

Clones the repo into a gitignored `.agents/<slug>/` on its own branch, copies the
(untracked) `.devcontainer/` in, prunes stale containers, and opens the folder
directly inside its container. Idempotent: an existing slug just reopens.

```bash
#!/usr/bin/env bash
# Create (or reopen) an isolated dev-container workspace and open it in VS Code
# directly inside the container. Name it after the task: kebab-case slug.
#   scripts/new-devcontainer.sh <task-slug> [base-branch]
set -euo pipefail

name="${1:?usage: new-devcontainer.sh <task-slug> [base-branch]}"
base="${2:-HEAD}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/.agents/$name"

# Prune dev containers idle > TTL_DAYS before spinning up a new one.
"$root/scripts/prune-devcontainers.sh" || true

if [ ! -d "$dest" ]; then
  git -C "$root" clone --quiet "$root" "$dest"
  git -C "$dest" checkout -q -B "agent/$name" "$base"
  # .devcontainer/ is untracked in the repo, so the clone misses it — copy it in.
  cp -R "$root/.devcontainer" "$dest/"
  echo "created $dest on branch agent/$name"
else
  echo "reusing existing $dest"
fi

# VS Code opens a folder inside its dev container via a hex-encoded host path:
# vscode-remote://dev-container+<hex>/workspaces/<basename>
hex="$(printf '%s' "$dest" | od -A n -t x1 | tr -d ' \n')"
code --folder-uri "vscode-remote://dev-container+${hex}/workspaces/${name}"
echo "opening container window for ${name}..."
```

## `scripts/prune-devcontainers.sh`

TTL cleanup. Runs at the top of `new-devcontainer.sh` (no scheduler) — creating a
new container clears stale ones. Removes only *stopped* group-labeled containers
idle past the TTL; running containers and the on-disk `.agents/<slug>` checkouts
are left alone (container removal is non-destructive — reopening rebuilds, auth
persists via the shared volume).

```bash
#!/usr/bin/env bash
# Remove stopped dev containers (group label com.docker.compose.project=devcontainers)
# that have been idle longer than TTL_DAYS. Running containers and the on-disk
# .agents/<slug> checkouts are left untouched — reopening rebuilds the container.
set -euo pipefail

TTL_DAYS="${TTL_DAYS:-10}"
docker="$(command -v docker || echo /usr/local/bin/docker)"
"$docker" info >/dev/null 2>&1 || { echo "docker not running; skipping"; exit 0; }

cutoff=$(( $(date +%s) - TTL_DAYS * 86400 ))

for id in $("$docker" ps -aq \
      --filter label=com.docker.compose.project=devcontainers \
      --filter status=exited --filter status=created); do
  fin="$("$docker" inspect -f '{{.State.FinishedAt}}' "$id")"
  ts="${fin%.*}"; ts="${ts%Z}"                       # strip fractional seconds + Z
  epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "$ts" +%s 2>/dev/null)" || continue
  if [ "$epoch" -lt "$cutoff" ]; then
    "$docker" rm "$id" >/dev/null && echo "removed $id (idle since $fin)"
  fi
done
```

Override the window per run: `TTL_DAYS=5 scripts/new-devcontainer.sh foo`. The
`date -j -u -f` syntax is BSD/macOS `date`; on Linux use `date -u -d "$ts" +%s`.

## Authenticate

First container on a machine: open a terminal (inside the container) and run
`claude`, log in. The shared volume persists it — no re-auth on rebuild, restart,
or any later container. To skip interactive login entirely, set `ANTHROPIC_API_KEY`
via `containerEnv` — but that bills as API usage, not a Pro/Max subscription, so
prefer the shared-volume login.

## Hardening (add only what the task needs)

| Goal | Add |
| ---- | --- |
| Unattended runs (`--dangerously-skip-permissions`) | `remoteUser` must be non-root (`vscode` already is) — the CLI rejects the flag as root. |
| Restrict network egress | Add the reference [`init-firewall.sh`](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh) + `"runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"]` (alongside the group label). Allowlist: see [network-config](https://code.claude.com/docs/en/network-config#network-access-requirements). |
| Forward emulator/app ports to host | `"forwardPorts": [3000, 8787, 8080, 9199, 4000]` (UI / worker / Firestore / Storage / emulator UI). |

Don't mount host secrets (`~/.ssh`, cloud creds) — prefer repo-scoped or
short-lived tokens. Only use dev containers with trusted repositories.

## Common mistakes / gotchas

- **Reaching for a git worktree** — banned; use a dev container.
- **`remoteUser: node` on `base:ubuntu`** — builds but won't start (`unable to
  find user node`); use `vscode`.
- **Expecting the clone to carry `.devcontainer/`** — it's untracked, so a fresh
  `git clone` misses it; the script copies it in. (Commit `.devcontainer/` to
  drop the copy step.)
- **Unicode in a `bash` `set -u` string** (e.g. a `…` ellipsis right after
  `$name`) — the multibyte bytes get read into the variable name → `unbound
  variable`. Use ASCII + brace the var: `"${name}..."`.
- **Group label / forwarded ports not taking effect** — both apply at container
  *creation*; rebuild an existing container to pick them up.
- **`code --folder-uri` opens the folder locally, not in-container** — the
  `dev-container+<hex>` scheme is VS Code-version-dependent; if it lands local,
  click **Reopen in Container** once (it's remembered after).
- **`--dangerously-skip-permissions` as root** — rejected; non-root `remoteUser`.
- **Firewall without `NET_ADMIN`/`NET_RAW`** — `init-firewall.sh` can't apply rules.

## Reference

- Setup, hardening, org policy: https://code.claude.com/docs/en/devcontainer
- The CLI feature: https://github.com/anthropics/devcontainer-features/tree/main/src/claude-code
- Full reference container (`devcontainer.json`, `Dockerfile`, `init-firewall.sh`): https://github.com/anthropics/claude-code/tree/main/.devcontainer

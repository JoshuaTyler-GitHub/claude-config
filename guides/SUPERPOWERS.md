# Superpowers guide

`superpowers@claude-plugins-official` ships a set of **process skills** —
workflows that decide *how* to approach a task (brainstorm, plan, TDD, debug,
review) before any implementation skill runs. They are invoked through the
normal skill mechanism; this guide is the map of which one fires when, plus the
one place superpowers conflicts with a repo invariant.

## When each skill fires

Process skills run **first** — they set the approach; implementation skills
follow.

| Situation | Skill |
| --------- | ----- |
| Any new feature/component/behavior, before writing code | `superpowers:brainstorming` (explore intent + design first) |
| A spec/requirements for a multi-step task, before touching code | `superpowers:writing-plans` |
| Executing a written plan with review checkpoints | `superpowers:executing-plans` |
| Executing plan tasks in the current session | `superpowers:subagent-driven-development` |
| Implementing any feature or bugfix | `superpowers:test-driven-development` (write the failing test first) |
| Any bug, test failure, or unexpected behavior | `superpowers:systematic-debugging` (before proposing a fix) |
| 2+ independent tasks with no shared state | `superpowers:dispatching-parallel-agents` |
| Completed a task / before merging | `superpowers:requesting-code-review` |
| Got review feedback, before acting on it | `superpowers:receiving-code-review` (verify, don't blindly apply) |
| About to claim work is done / before commit or PR | `superpowers:verification-before-completion` (run the check, show output) |
| Implementation done, deciding how to integrate | `superpowers:finishing-a-development-branch` |
| Creating or editing a skill | `superpowers:writing-skills` |
| Start of any conversation | `superpowers:using-superpowers` (the meta-skill) |

## Rigid vs flexible

`test-driven-development` and `systematic-debugging` are **rigid** — follow
exactly, don't adapt away the discipline. The pattern skills are **flexible** —
adapt to context. Each skill states which it is.

## `using-git-worktrees` is overridden — use dev containers

Superpowers ships `superpowers:using-git-worktrees`, which proposes a git
worktree for isolated/parallel work. **This repo and the global config both
forbid worktrees** (see CLAUDE.md → *AI agents & isolated workspaces*). The
override is real, not advisory:

- **Never** follow `using-git-worktrees`. When work needs isolation or parallel
  agents, use a per-agent dev container — invoke the `dev-containers` skill
  (`npm run agent:new -- <name>`, or scaffold a `.devcontainer/`).
- Instruction priority makes this safe — user/project instructions outrank a
  skill — but treat the worktree skill as a no-op here and substitute the dev
  container workflow.

## Priority

Superpowers' own rule: **user/project instructions (CLAUDE.md) outrank any
skill.** Where a skill says one thing and CLAUDE.md says another, CLAUDE.md
wins — the worktree case above is the canonical example.

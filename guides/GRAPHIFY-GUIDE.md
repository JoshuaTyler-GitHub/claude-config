# Graphify Guide

How to run graphify and where its output lives. The one rule that matters:
**graphify owns `.graphify/` in the project root, and nothing else writes there
or copies out of it.** Read this before running graphify in a repo or wiring its
output into docs.

## What graphify is

`/graphify` turns a folder of files (code, docs, papers, images, video) into a
persistent knowledge graph with community detection and an audit trail
(EXTRACTED / INFERRED / AMBIGUOUS). It produces three outputs — an interactive
`graph.html`, a GraphRAG-ready `graph.json`, and a plain-language
`GRAPH_REPORT.md` — plus a query interface (`graphify query "<question>"`,
`path`, `explain`). The graph persists across sessions, so once built you query
it instead of re-reading files.

## The output location: `.graphify/` — always

graphify writes everything to **`.graphify/` relative to the current working
directory** (the project root where you run the command). This is not
configurable per-run and you should never make it configurable. The store:

| Path | What it is |
| ---- | ---------- |
| `.graphify/graph.json` | The graph — nodes, edges, communities. The fast-path detector looks for exactly this file. |
| `.graphify/graph.html` | Interactive visualization. |
| `.graphify/GRAPH_REPORT.md` | Plain-language report — the human/agent entry point. **Reference this path directly**; never copy it elsewhere. |
| `.graphify/cache/` | Per-file extraction cache; what makes `--update` incremental. |
| `.graphify/.graphify_root`, `.graphify_python`, `.graphify_labels.json` | Root + interpreter + label markers graphify manages itself. |
| `.graphify/cost.json` | Token/cost ledger for the last build. |
| `.graphify/cypher.txt` | Only with `--neo4j`. |

Optional exports (`--svg`, `--graphml`, `--wiki`, `--obsidian`) also land under
`.graphify/` (or the explicit `--obsidian-dir` you pass). There is no reason to
direct any graphify output anywhere else.

## Fast path: query, don't rebuild

If `.graphify/graph.json` exists and the task is a natural-language question
about the codebase ("How does X work?", "What calls Y?", "Trace the flow
through Z") — and **not** an explicit rebuild (`--update`, `--cluster-only`, a
bare path/URL) — skip straight to `graphify query "<question>"`. The graph is
already built; use it. This is the whole point of a persistent store, and it
only works if the canonical files are where the detector looks: `.graphify/`.

## The anti-pattern: a sibling output dir (e.g. `graphify-out/`)

**Never redirect or hand-copy graphify's output into a second directory.** A
sibling like `graphify-out/`, `graph-output/`, or `docs/graph/` holding copies
of `graph.json` / `graph.html` / `GRAPH_REPORT.md` is always wrong. It breaks in
three ways at once:

1. **It goes stale instantly.** It's a snapshot, not the store. The next
   `graphify --update` writes `.graphify/` and leaves the copy frozen at an
   older build — and nothing tells the reader the doc they're citing is out of
   date.
2. **It breaks the fast-path.** The detector keys on `.graphify/graph.json`. A
   copy elsewhere is invisible to it; an agent either rebuilds needlessly or
   queries the wrong file.
3. **It pollutes git.** `.graphify/` is correctly gitignored (it's a large
   build artifact + cache). A hand-rolled output dir usually gets committed,
   dragging hundreds of KB of stale generated HTML/JSON into version control,
   where docs then cite a copy that froze at an older build.

### Fixing a repo that already has one

1. Delete the sibling dir (`rm -rf graphify-out/`) and `git rm` its tracked
   files.
2. Repoint every doc reference from `graphify-out/GRAPH_REPORT.md` to
   `.graphify/GRAPH_REPORT.md` (grep the repo for the old path).
3. Confirm `.gitignore` has `.graphify/` (a leading-dot build store belongs
   there) and drop any `graphify-out/` rules.
4. Re-run `graphify --update` so `.graphify/` is current, then cite it directly.

## gitignore

Add `.graphify/` to `.gitignore` in every repo where you run graphify. It's a
regenerable build artifact and a cache (often >1 MB of `graph.html` alone) —
rebuildable from source by anyone who runs `/graphify`, so it does not belong in
version control. The graph is reproduced on demand, never committed.

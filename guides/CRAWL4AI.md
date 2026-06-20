# crawl4ai guide

Fetch and search the web through crawl4ai's own headless Chromium instead of the
harness `WebFetch`/`WebSearch` tools. Use it when those tools are throttled, or
when a task needs more than a couple of pages. Procedure + exact flags live in
the `crawl4ai` skill; this guide is the *when* and the discipline.

## When to reach for it

- `WebFetch`/`WebSearch` returned `Server is temporarily limiting requests` (a
  shared server-side rate limit) — crawl4ai is entirely off that path.
- You need to crawl/fetch many pages, not a single lookup.
- A deep-research pass keeps stalling on web-tool throttling.

For a single fetch when the built-in tools aren't throttled, prefer them — this
spins up a browser, so it's heavier per call.

## Commands

```sh
# Fetch one URL → clean markdown on stdout
~/.venvs/crawl4ai/bin/python ~/.venvs/crawl4ai/fetch_md.py '<url>'

# Search (scrapes DuckDuckGo HTML) → JSON [{url,title,snippet}]
~/.venvs/crawl4ai/bin/python ~/.venvs/crawl4ai/search.py '<query>' <limit>
```

crawl4ai has no search engine of its own — `search.py` crawls DuckDuckGo's HTML
endpoint.

## Context-mode discipline (mandatory for large output)

Same rule as `MARKITDOWN.md`: **never dump raw page markdown into context.** For
anything beyond a quick read, redirect to a file and process it with
context-mode, surfacing only the derived answer — the page bytes stay in the
sandbox.

```sh
~/.venvs/crawl4ai/bin/python ~/.venvs/crawl4ai/fetch_md.py '<url>' > /tmp/page.md
# then: ctx_execute_file(path="/tmp/page.md", ...)
```

A `| head` sanity-check is the only allowed direct read.

## Deep-research, crawl4ai-wired

The deep-research harness with its search + fetch + verify stages routed through
the helpers (so it dodges the throttle) lives at
`~/.claude/workflows/deep-research-crawl4ai.js` (its agents use
`agentType: "general-purpose"` for Bash):

```
Workflow({scriptPath: "~/.claude/workflows/deep-research-crawl4ai.js", args: "<question>"})
```

## Install

`install.sh` builds the `~/.venvs/crawl4ai` venv (python 3.12), installs
crawl4ai, runs `crawl4ai-setup` (the Chromium it drives), and drops the helpers.
To (re)create by hand or verify, see the **If the venv is missing** section of
the `crawl4ai` skill (`skills/crawl4ai/SKILL.md`). Upstream:
https://github.com/unclecode/crawl4ai

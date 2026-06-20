---
name: crawl4ai
description: Use when the harness WebFetch/WebSearch is rate-limited ("Server is temporarily limiting requests"), when fetching a page or searching the web fails on throttling, or when crawling many pages at once — fetch/search through crawl4ai's own headless Chromium instead.
---

# crawl4ai — web fetch/search off the harness throttle

## Overview

The harness `WebFetch`/`WebSearch` tools share a server-side rate limit and
return `Server is temporarily limiting requests` under load. crawl4ai drives its
own headless Chromium, entirely off that path — so it keeps working when the
built-in tools are throttled, and handles many-page crawls. Two vendored helpers
wrap it; both are copied into the venv by `install.sh`.

## When to use

- `WebFetch`/`WebSearch` returned a rate-limit / "temporarily limiting" error.
- You need to crawl/fetch more than a couple of pages.
- A deep-research pass keeps stalling on web-tool throttling.

Prefer the built-in tools for one-off fetches when they aren't throttled — this
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

## Context-mode discipline (required for large output)

Same rule as markitdown: **don't dump raw page markdown into context.** For
anything beyond a quick read, redirect to a file and process it with
context-mode, surfacing only the derived answer:

```sh
~/.venvs/crawl4ai/bin/python ~/.venvs/crawl4ai/fetch_md.py '<url>' > /tmp/page.md
# then: ctx_execute_file(path="/tmp/page.md", ...) — bytes stay in the sandbox
```

A `| head` sanity-check is the only allowed direct read.

## Deep-research, crawl4ai-wired

A copy of the deep-research harness with its search + fetch + verify stages
routed through these helpers (so it dodges the throttle) lives at
`~/.claude/workflows/deep-research-crawl4ai.js` (its agents use
`agentType: "general-purpose"` for Bash):

```
Workflow({scriptPath: "~/.claude/workflows/deep-research-crawl4ai.js", args: "<question>"})
```

## If the venv is missing

`install.sh` builds it. To (re)create by hand:

```sh
python3.12 -m venv ~/.venvs/crawl4ai
~/.venvs/crawl4ai/bin/pip install -U crawl4ai
~/.venvs/crawl4ai/bin/crawl4ai-setup     # installs the Chromium it drives
~/.venvs/crawl4ai/bin/crawl4ai-doctor    # verify
cp <this-skill-dir>/fetch_md.py <this-skill-dir>/search.py ~/.venvs/crawl4ai/
```

Upstream: https://github.com/unclecode/crawl4ai

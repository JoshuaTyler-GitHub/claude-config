# Markitdown Guide

When the task is to **read, extract, summarize, or process a non-plain-text
document**, convert it with `markitdown` first — never read the raw bytes.
Markitdown (Microsoft) turns rich/binary formats into deterministic markdown,
which is far more token-efficient and reliable than dumping the file into
context. This is a favored default, not a last resort.

## When to use it

Use markitdown for: **PDF, Word (`.docx`), Excel (`.xlsx`/`.xls`), PowerPoint
(`.pptx`), images (PNG/JPEG — OCR + EXIF), HTML, CSV/TSV, JSON/XML, ZIP
(recurses members), EPUB, Outlook `.msg`, audio (transcription), and YouTube
URLs.**

Do **not** use it for plain-text source/markdown/config files — read and edit
those directly.

## The everyday path — CLI to a file

Convert to a file with `-o`; never print the conversion to stdout to read it:

```bash
markitdown <input> -o <output>.md
```

Then process `<output>.md` with context-mode (`ctx_execute_file`) and surface
only the derived answer — the document bytes stay in the sandbox, out of
context. A converted document is exactly the "large output you intend to
process" that context-mode exists for. The only allowed direct read is a brief
`| head` sanity-check.

**Never let the converted markdown land in context** — don't print it to stdout
to read it, and don't `Read` the produced `.md` into the conversation. Convert
→ process in the sandbox → report the answer.

## The MCP server — remote URIs

`markitdown-mcp` exposes one tool, `convert_to_markdown(uri)`, for any
`http:` / `https:` / `file:` / `data:` URI. Use it when converting a remote
URL or data-URI is cleaner than fetch-then-CLI. The CLI is the everyday path;
the MCP server is the exception. (Installed + registered by the repo's
`install.sh`; see [MCP.md](./MCP.md).)

## Install / requirements

- CLI: `~/.local/bin/markitdown` (uv tool, Python 3.12, `[all]` extras — pdf,
  docx, xlsx, pptx, audio, youtube). Reinstall:
  `uv tool install --python 3.12 "markitdown[all]"`.
- **ffmpeg** is required only for audio transcription; without it a pydub
  warning prints and non-audio conversions are unaffected.

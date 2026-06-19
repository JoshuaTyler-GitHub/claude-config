---
name: markitdown
description: Use when the task is to read, extract, summarize, or process a non-plain-text document — PDF, Word (.docx), Excel (.xlsx), PowerPoint (.pptx), image (OCR), HTML, CSV, JSON/XML, ZIP, EPUB, Outlook .msg, audio, or a YouTube URL. Convert it to markdown with the markitdown CLI before reading the raw bytes.
---

# markitdown

Convert any rich/binary document to deterministic markdown before processing it.
Far more token-efficient and reliable than dumping the raw file into context.

## When this applies

Reach for markitdown whenever the input is a non-plain-text document: **PDF,
.docx, .xlsx/.xls, .pptx, images (PNG/JPEG — OCR + EXIF), HTML, CSV/TSV,
JSON/XML, ZIP, EPUB, .msg, audio, or a YouTube URL.**

Do **not** use it for plain-text source/markdown/config — read and edit those
directly.

## How to use it

1. **Convert to a file** (never to stdout):

   ```bash
   markitdown <input> -o <output>.md
   ```

2. **Process the file in the sandbox**, not in context. Use context-mode's
   `ctx_execute_file` (or index + `ctx_search`) on `<output>.md` and surface only
   the derived answer. The document bytes stay out of the conversation.

3. **Never `Read` the converted markdown into context.** A brief `| head`
   sanity-check is the only allowed direct read.

## Remote URLs

For an `http:`/`https:`/`file:`/`data:` URI, the `markitdown-mcp` server's
`convert_to_markdown(uri)` tool is cleaner than fetch-then-CLI. The CLI is the
everyday path; the MCP server is the exception.

## Requirements

CLI at `~/.local/bin/markitdown` (uv tool, Python 3.12, `[all]` extras). `ffmpeg`
is needed only for audio transcription.

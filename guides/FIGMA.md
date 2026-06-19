# Figma Guide

Figma is the source of truth for **designs, mockups, and architecture
diagrams**. Use it to read a designer's intent precisely instead of eyeballing a
screenshot, and to author diagrams that back `PROJECT.md`. Access is through the
official **figma** plugin (which provides the Figma MCP server) — see
[SKILLS.md](./SKILLS.md) and [MCP.md](./MCP.md) for install.

## When to reach for it

- **Implementing a UI from a design / mockup** — pull the selected frame's real
  structure, tokens, spacing, and measurements via the MCP rather than guessing
  from an image. This is the difference between matching the design and
  approximating it.
- **Architecture / flow diagrams** — author them in FigJam and link them from
  `PROJECT.md` so the diagram and the prose stay together.

## The Figma MCP — design context into code

The figma plugin exposes Dev Mode context: with a frame selected in the Figma
desktop app, the MCP can return that frame's layer tree, auto-layout, type
styles, colors, and exact measurements, and can scaffold code from it. The local
MCP needs the **Figma desktop app open with Dev Mode** on the target file; the
claude.ai Figma connector is the alternative when working without the desktop
app (managed in `/mcp` / claude.ai, not in `mcp/mcp.json`).

## Translate, don't transcribe

A Figma frame gives raw pixel values; this codebase speaks **tokens and scale
steps**. When you implement from Figma, map its values onto the design system —
never paste arbitrary pixels:

- Colors / typography / radius → the token surface in
  [UI-STYLE-GUIDE.md](./UI-STYLE-GUIDE.md), not raw hex.
- Spacing / sizing → the nearest whole Tailwind scale step (no `p-[13px]`); see
  the whole-number rule in [UI-STYLE-GUIDE.md](./UI-STYLE-GUIDE.md).
- Corners → `rounded-3xl` to match HeroUI surfaces, per the
  [HEROUI-GUIDE.md](./HEROUI-GUIDE.md) and the single-radius rule.

A 13px gap in Figma becomes `gap-3`, a `#0A0A0A` fill becomes the matching
theme token. If a Figma value has no token, that's a design-system gap worth
surfacing — not a reason to hardcode.

## Architecture diagrams

Keep diagrams editable (FigJam / Figma), export a static image for the doc, and
link the source frame so the next person can update it. A diagram that only
exists as a flattened PNG rots the same way a stale screenshot does.

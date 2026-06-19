# Design System — UI Style Guide

The visual design: token surface, brand defaults, typography, radius,
container widths, accessibility.

**Source of truth.** This document explains the system; the *values* live in
code and win on any disagreement:

| Concern | Owner |
| ------- | ----- |
| Brand defaults + full token surface | `styles/global.css` |
| Fonts (`next/font` families) | `config/platform-theme-fonts.ts` |
| `next-themes` wiring (light/dark) | `config/theme-config.ts` |
| Stylesheet layout + HeroUI override patterns | `PROJECT.md` → "Styles" |

There is **no** `--brand-navy-*` / `--color-*` palette and **no** `BRAND_PALETTE`
constant — everything is expressed as the HeroUI v3 semantic token surface below.

---

## 1. Theming approach

**Tailwind v4 + HeroUI v3** (CSS-first; no `tailwind.config.js`). `styles/global.css`
binds the core HeroUI tokens (`--background`, `--surface`, `--accent`, …) for
`:root` / `.light` / `[data-theme='light']` and `.dark` / `[data-theme='dark']`,
directly on top of `@heroui/styles`. Light/dark is the only axis — see §6.

**Rule:** Never hardcode a hex/OKLCH literal in a component. Style against the
tokens (`bg-surface`, `text-foreground`, `bg-accent`, …) so the element tracks
light/dark mode automatically.

---

## 2. The token surface

The semantic tokens every component styles against. HeroUI reads them directly
(`<Button variant="primary">` fills with `--accent`); custom UI uses the
matching Tailwind utilities (`bg-surface`, `text-muted`). Each `*-foreground`
token is the readable on-color for its pairing.

| Group | Tokens |
| ----- | ------ |
| **Surfaces** | `--background`, `--surface`, `--surface-secondary`, `--surface-tertiary`, `--overlay`, `--default` (each with a `-foreground`) |
| **Content** | `--foreground`, `--muted` |
| **Accent** | `--accent` (+ `-foreground`), `--focus`, `--link` |
| **Status** | `--success`, `--danger`, `--warning` (each with a `-foreground`) |
| **Form fields** | `--field-background`, `--field-border`, `--field-foreground`, `--field-placeholder`, `--field-radius` |
| **Structure** | `--border`, `--separator`, `--segment` (+ `-foreground`), `--scrollbar`, `--radius` |
| **Effects** | `--overlay-shadow`, `--surface-shadow` |

`global.css` defines the full surface — every token above — for both light and
dark.

---

## 3. Brand defaults

The values in `styles/global.css`. The accent is a **warm orange**
(`oklch(65% 0.18 40)`), shared across light and dark; neutrals are a faintly
warm gray (hue ~80–95, very low chroma).

### Light (`:root`, `.light`, `[data-theme='light']`)

| Token | Value | Role |
| ----- | ----- | ---- |
| `--background` | `oklch(98% 0.005 95)` | Page background (warm near-white) |
| `--foreground` | `oklch(18% 0.002 80)` | Primary text (warm near-black) |
| `--surface` | `oklch(100% 0 0)` | Cards, panels (pure white) |
| `--surface-secondary` | `oklch(0.9524 0.0013 286.37)` | Raised/alt surface |
| `--surface-tertiary` | `oklch(0.9373 0.0013 286.37)` | Ghost/outline button hover + active |
| `--accent` | `oklch(65% 0.18 40)` | Brand accent — primary action fill |
| `--accent-foreground` | `oklch(100% 0 0)` | Text on accent (white) |
| `--success` | `oklch(60% 0.149 139)` | Success (green) |
| `--danger` | `oklch(57.71% 0.2152 27.33)` | Error / destructive (red) |
| `--link` | `oklch(59% 0.128 252)` | Links (blue) |
| `--muted` | `oklch(73% 0.009 90)` | Muted / secondary text |
| `--default` | `oklch(92% 0.012 95)` | Neutral component fill |
| `--border`, `--separator` | `oklch(92% 0.012 95)` | Borders, dividers, the interactive-edge rule (§7) |
| `--field-background` | `oklch(100% 0 0)` | Form-field fill |

### Dark (`.dark`, `[data-theme='dark']`)

The neutral ramp inverts; accent/success/danger hold their hue.

| Token | Value |
| ----- | ----- |
| `--background` | `oklch(18% 0.002 80)` |
| `--foreground` | `oklch(98% 0.005 95)` |
| `--surface` | `oklch(0.2103 0.0059 285.89)` |
| `--surface-secondary` | `oklch(0.257 0.0037 286.14)` |
| `--surface-tertiary` | `oklch(0.2721 0.0024 247.91)` |
| `--accent` / `--accent-foreground` | `oklch(65% 0.18 40)` / `oklch(100% 0 0)` |
| `--border` | `oklch(30% 0.002 80)` |
| `--separator` | `oklch(28% 0.002 80)` |
| `--field-background` | `oklch(21% 0.002 80)` |

---

## 4. Typography

Sans is **Inter**, loaded once via `next/font/google` and stamped on `<body>`
as `--font-sans` (`config/platform-theme-fonts.ts`). There is no separate
heading font — weight and size carry the hierarchy. Use Tailwind's type scale
(`text-sm` … `text-5xl`, `font-medium` / `font-semibold` / `font-bold`).

---

## 5. Radius

| Size | rem |
| ---- | --- |
| `none` | `0` |
| `xs` | `0.125rem` |
| `sm` | `0.25rem` |
| `md` | `0.5rem` |
| `lg` | `0.75rem` |
| `xl` | `1rem` |

`--radius` drives the app-wide corner system; `--field-radius` does the same for
form fields.

**Rule:** At the component level the app uses a single corner radius,
`rounded-3xl` (rationale + exceptions in `CLAUDE.md` → "Single corner-radius").

---

## 6. Color modes

Light/dark is driven by **`next-themes`** via the `data-theme` attribute on
`<html>` (`config/theme-config.ts`):

- Attribute: `data-theme` — values `light` / `dark`, default `system`.
- Each mode carries a full set of token values, so mode-switching never leaves a
  token unset.

---

## 7. Accessibility (enforced in `global.css`)

- **Interactive-edge rule.** Every interactive HeroUI surface (`[data-slot]`
  triggers, inputs, switches, checkboxes, …) gets a `1px solid var(--separator)`
  border so its bounds are locatable without relying on hover/focus/contrast.
  Inner nested slots are skipped to avoid doubled borders.
- **Opt-out.** Mark an element (or an interactive descendant) with
  `data-border-exception` to exempt it from the edge rule.
- **Ghost/outline buttons** take `--surface-tertiary` on hover and active so they
  read as pressable against any surface.
- **Pair colored fills with their `-foreground`.** `--accent-foreground` is white
  against accent, `--danger-foreground` reads against danger, `--link` stays
  legible on `--surface`. When you introduce a new colored fill, use the matching
  `-foreground` token rather than guessing a text color.

---

## 8. Using tokens in components

- Style against tokens, not literals: `bg-background`, `bg-surface`,
  `text-foreground`, `text-muted`, `bg-accent text-accent-foreground`,
  `border-separator`, `bg-danger text-danger-foreground`.
- Let HeroUI variants pull the tokens for you (`<Button variant="primary">` →
  `--accent`); only reach for explicit token utilities in hand-built UI.
- Need a token value in CSS? Reference the variable (`var(--accent)`), never the
  resolved color.
- Overriding a HeroUI component's look? Use the BEM-style class names + per-slot
  custom properties documented in `PROJECT.md` → "Overriding HeroUI v3 component
  styles" — don't fight specificity with arbitrary selectors.

---

## 9. Container widths & responsive components

**Capping content width** → use `Container` (`@components/container`), not a
hand-written `mx-auto w-full max-w-*`. It's a `FlexColumn` that centers, fills
the available width, and caps at a `size` drawn from Tailwind's `max-w-*` scale:

| `size` | Caps at | `size` | Caps at |
| ------ | ------- | ------ | ------- |
| `3xs`…`xs` | `max-w-3xs` … `max-w-xs` | `xl`…`4xl` | `max-w-xl` … `max-w-4xl` |
| `sm` (default) | `max-w-sm` | `5xl`…`7xl` | `max-w-5xl` … `max-w-7xl` |
| `md`, `lg`, `2xl` | the matching `max-w-*` | `full` | `max-w-full` (no cap) |

```tsx
// Page/section content capped and centered — pick the size, nothing else
<Container size={'3xl'}>…</Container>
```

**Responsive components → prefer container queries over viewport breakpoints.**
Tailwind v4 ships container queries in core (no plugin). A reusable component
should adapt to *its own* width, not the viewport's, so it looks right in a
sidebar, a grid cell, and a full-bleed page alike. Mark the wrapper `@container`
and use `@sm:` / `@md:` / `@lg:` (or the `@max-*` range variants) on children:

```tsx
// Adapts to the component's container, not the screen
<div className={'@container'}>
  <div className={'grid grid-cols-1 @md:grid-cols-2 @lg:grid-cols-3'}>…</div>
</div>
```

Reach for plain `sm:`/`md:` viewport breakpoints only for true page-level layout
(the shell, top nav) where the viewport *is* the relevant box.

---

## 10. Source map

| You need… | Go to |
| --------- | ----- |
| The exact brand default values | `styles/global.css` |
| Font families + loading | `config/platform-theme-fonts.ts` |
| Light/dark wiring | `config/theme-config.ts` |
| Stylesheet files, import order, override patterns | `PROJECT.md` → "Styles" |
| Cap content width / center a column | `Container` (`@components/container`) |
| HeroUI v3 component API + migration | `.claude/guides/HEROUI-GUIDE.md` |

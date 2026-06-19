# HeroUI v3 Guide — API reference & v2 → v3 migration

The v3 component API, the v2→v3 migration map, and the project's composition
patterns. Derived from `node_modules/@heroui/react/dist/components/*/index.d.ts`
and TypeScript errors emitted against the codebase. Live upgrade-tracking notes:
`.claude/memories/heroui-v3-migration.md`.

v3 is a near-total redesign: react-aria-components base, compound components
(`Card.Header`, `Modal.Container`, `Tabs.Tab`, …), a new variant enum
(`primary`/`secondary`/`tertiary`/`ghost`/`outline` replacing
`flat`/`light`/`solid`/`bordered`), and Tailwind v4 CSS-first theming via
`@heroui/styles`. Companion memory:
`.claude/projects/.../memory/tailwind-heroui-stack.md`.

## Removed / Renamed exports

Genuinely removed (or genuinely renamed — the v2 symbol no longer exists):

| v2               | v3                                                                                                                                     |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `CardBody`       | `CardContent` (or `Card.Content`)                                                                                                      |
| `Divider`        | `Separator`                                                                                                                            |
| `getKeyValue`    | (removed — use `row[columnKey]` direct access)                                                                                         |
| `HeroUIProvider` | (removed — wrap with `RouterProvider` from `@heroui/react/rac` only if you need `next/link` integration; otherwise no provider needed) |
| `Image`          | (removed — use `next/image` or HTML `<img>`)                                                                                           |
| `Listbox`        | `ListBox` (casing change)                                                                                                              |
| `ModalContent`   | `Modal.Container` + `Modal.Dialog` (split)                                                                                             |
| `Progress`       | `ProgressBar` _or_ `ProgressCircle` (per use)                                                                                          |
| `SlotsToClasses` | (removed — `classNames` prop gone everywhere)                                                                                          |
| `Snippet`        | (removed — build with text + CloseButton/copy hook)                                                                                    |
| `Spacer`         | (removed — use Tailwind spacing utilities)                                                                                             |

Compound aliases (named export **still works** — compound form is preferred for
new code, but the rename is not required):

| Named import (still valid)        | Compound alias                       |
| --------------------------------- | ------------------------------------ |
| `CardHeader`                      | `Card.Header`                        |
| `CardFooter`                      | `Card.Footer`                        |
| `CardContent`                     | `Card.Content`                       |
| `CardTitle`                       | `Card.Title`                         |
| `CardDescription`                 | `Card.Description`                   |
| `Tab`                             | `Tabs.Tab`                           |
| `TabList`                         | `Tabs.List`                          |
| `TabPanel`                        | `Tabs.Panel`                         |
| `ListBoxItem`                     | `ListBox.Item`                       |
| `ListBoxSection`                  | `ListBox.Section`                    |
| `ModalHeader` / `Body` / `Footer` | `Modal.Header` / `.Body` / `.Footer` |

Other imports still valid in v3 (some lose props — see below): `Button`,
`ButtonProps`, `Card`, `Chip`, `ChipProps`, `cn`, `Input`, `InputProps`,
`InputGroup`, `Label`, `Description`, `FieldError`, `TextField`,
`TextFieldProps`, `TextArea`, `Form`, `Link`, `LinkProps`, `Modal`,
`Pagination`, `PaginationProps`, `Selection`, `SortDescriptor`, `Spinner`,
`SpinnerProps`, `Switch`, `Tabs`, `TabsProps`.

## Variant / color enum flip

v2 took `color` and `variant` (`solid|bordered|flat|light|ghost|shadow|faded`)
as separate axes. v3 collapses color + emphasis into a single `variant` token.

### Button

| v2                                     | v3                                    |
| -------------------------------------- | ------------------------------------- |
| `<Button>` (default)                   | `<Button variant="primary">`          |
| `color="primary" variant="solid"`      | `variant="primary"`                   |
| `color="secondary" variant="solid"`    | `variant="secondary"`                 |
| `color="default" variant="solid"`      | `variant="tertiary"`                  |
| `color="danger" variant="solid"`       | `variant="danger"`                    |
| `color="danger" variant="flat"`        | `variant="danger-soft"`               |
| `variant="bordered"` (any color)       | `variant="outline"`                   |
| `variant="light"` / `variant="ghost"`  | `variant="ghost"`                     |
| `variant="flat"` (no color or default) | `variant="tertiary"` (judgement call) |

### Chip

v3 variants: `primary` / `secondary` / `soft` / `tertiary`. Colors: `default` /
`accent` / `danger` / `success` / `warning` (note: `primary` is NOT a v3 chip
color — use `accent`).

| v2                | v3                                         |
| ----------------- | ------------------------------------------ |
| `color="primary"` | `color="accent"`                           |
| `variant="flat"`  | `variant="soft"`                           |
| `variant="dot"`   | `variant="soft"` + manual dot via children |

### Status / decorator usage

Anywhere `color="primary"` is used as a status indicator (alerts, chips, status
decorators), map to `color="accent"` in v3.

## Removed props by component

### Button

- `color` — gone; folded into `variant` (see flip table).
- `isLoading` → **`isPending`** (renamed, not removed). `ButtonRootProps`
  extends `react-aria-components/Button`, whose `isPending?: boolean` drives the
  loading state and disables pointer events. Just rename the prop — don't render
  a manual `<Spinner>`.
- `as` — gone; use the `render` prop (DOMRenderFunction pattern).
- `classNames`, `slotsProps` — gone; use `className`.

### Tab

- `title` — gone. Old:
  ```tsx
  <Tabs>
    <Tab
      id='x'
      title='Label'
    >
      <Body />
    </Tab>
  </Tabs>
  ```
  New:
  ```tsx
  <Tabs.Root>
    <Tabs.List>
      <Tabs.Tab id='x'>Label</Tabs.Tab>
    </Tabs.List>
    <Tabs.Panel id='x'>
      <Body />
    </Tabs.Panel>
  </Tabs.Root>
  ```

### Input / TextField (form-field surface moved)

**The bare `<Input>` is no longer the form-field root.** It's now a thin
wrapper around `react-aria-components/Input` — a styled `<input>` with native
HTML attrs (`required`, `disabled`, `readOnly`). All v2 `Input` ergonomics
moved up to the `TextField` compound:

```tsx
// v2
<Input
  label="Email"
  isRequired
  isInvalid={!isEmpty(err)}
  errorMessage={err}
  startContent={<Icon />}
  onValueChange={setEmail}
/>

// v3 — TextField owns the field-level concerns
<TextField isRequired isInvalid={!isEmpty(err)} value={email} onChange={setEmail}>
  <Label>Email</Label>
  <InputGroup>            {/* only if you need start/end adornments */}
    <Icon />
    <Input />
  </InputGroup>
  <FieldError>{err}</FieldError>
</TextField>
```

Per-prop migration:

| v2 (on `<Input>`)             | v3                                                                 |
| ----------------------------- | ------------------------------------------------------------------ |
| `label`                       | `<Label>` child of `<TextField>` (gone from Input)                 |
| `description`                 | `<Description>` child of `<TextField>`                             |
| `errorMessage`                | `<FieldError>` child of `<TextField>`                              |
| `isInvalid`                   | `isInvalid` on `<TextField>`                                       |
| `isRequired`                  | `isRequired` on `<TextField>` (or native `required` on `<Input>`)  |
| `isDisabled`                  | `isDisabled` on `<TextField>` (or native `disabled` on `<Input>`)  |
| `isClearable`                 | gone — compose a clear `<Button>` inside `<InputGroup>`            |
| `startContent` / `endContent` | wrap `<Input>` in `<InputGroup>` and render adornments as siblings |
| `onValueChange`               | `onChange` on `<TextField>` (receives the string directly)         |
| `classNames`                  | gone; pass `className` to each compound part                       |

Use a multi-line input the same way — swap `<Input>` for `<TextArea>`.

#### `TextField` in a flex row overflows its container — add `min-w-0`

A `TextField` (or any flex item wrapping an `<Input>` / `<TextArea>`) **will
not shrink below the input's intrinsic width** when the container narrows: a
flex item's default `min-width: auto` resolves to the content's min-content
size. The input keeps its ~180px preferred width and pushes itself and its
siblings (sort buttons, end content) past the surface edge. Flex slack hides
it at wide widths; it overflows only once the container narrows (sidebar, grid
column, mobile).

Fix with two utilities on the flex chain — **not** a `max-w-*` on the input:

- **`min-w-0`** on every flex item between the constraining container and the
  `TextField` (the wrapping `FlexRow`, plus the `TextField` itself if it's a
  direct flex child). Releases the `min-width: auto` floor so `flex-shrink`
  takes effect.
- **`w-full`** on the intermediate flex container so the parent surface bounds
  it instead of its content width. In a flex-**column** parent the item sizes
  on the cross axis, where `flex-shrink` does nothing and `align-items: center`
  lets it grow to content width — `w-full` is what bounds it.

```tsx
// Bad — input won't compress; overflows a narrow surface
<FlexRow className={'w-full'}>
  <TextField className={'w-full'}>
    <Input />
  </TextField>
</FlexRow>

// Good — min-w-0 lets the row shrink below the input's intrinsic width
<FlexRow className={'min-w-0 w-full'}>
  <TextField className={'min-w-0 w-full'}>
    <Input />
  </TextField>
</FlexRow>
```

Reference: `components/search-bar/search-bar.tsx`. The generic flexbox
`min-width: auto` trap — applies to any intrinsically-sized child (inputs,
`<canvas>`, `next/image`, embedded maps), not just `TextField`.

### Modal

- `isOpen` / `onOpenChange` / `onClose` — gone on the root. Root takes
  `{ children, state }` where `state` comes from `useOverlayState()` (the v3
  replacement for v2's `useDisclosure`):
  ```tsx
  const state = useOverlayState({ defaultOpen: false });
  // state.isOpen, state.open(), state.close(), state.toggle(), state.setOpen()
  <Modal state={state}>…</Modal>;
  ```
  Or stay uncontrolled and close via `<Modal.CloseTrigger>` (any inner
  `<Button slot="close">` also closes).
- `hideCloseButton` — gone; just omit `<Modal.CloseTrigger>`.
- `isDismissable` — moved to `<Modal.Backdrop>`.
- `className`, `classNames` — gone on root; apply to inner pieces.

### Table

- **`<Table>` is now just a styled wrapper.** The real react-aria-components
  `Table` primitive — which creates the collection context `TableColumn` /
  `TableRow` look up — is `<TableContent>`. Header / Body must live inside
  `TableContent`, not directly inside `Table`. Skipping it throws _"TableColumn
  cannot be rendered outside a collection."_
  ```tsx
  // v2
  <Table aria-label='Users'>
    <TableHeader>
      <TableColumn>Email</TableColumn>
    </TableHeader>
    <TableBody>…</TableBody>
  </Table>

  // v3
  <Table>
    <TableContent aria-label='Users'>
      <TableHeader>
        <TableColumn isRowHeader>Email</TableColumn>
      </TableHeader>
      <TableBody>…</TableBody>
    </TableContent>
  </Table>
  ```
  `aria-label` moves to `TableContent` (the real RAC `Table`). Mark the first
  text column `isRowHeader` for screen-reader correctness. `<ThemedTable>`
  follows this pattern — reach for it when you need sort / filter /
  visible-column logic on the raw primitives.
- `bottomContent` — gone; render pagination outside the table.
- `classNames`, `isStriped`, `removeWrapper` — gone.
- `loadingContent`, `isLoading` (on `TableBody`) — gone. Use
  `<Table.LoadMore isLoading onLoadMore={…}>` for paginated/async lists
  (sentinel-row pattern), or render `<Spinner>` as a sibling overlay for
  one-shot loads.

### Chip

- `onClose` — gone; place a `<CloseButton>` as a child
- `classNames` — gone

### Card

- `CardBody` no longer exists. Use compound structure:
  ```tsx
  <Card>
    <Card.Header>
      <Card.Title>...</Card.Title>
    </Card.Header>
    <Card.Content>...</Card.Content> {/* was CardBody */}
    <Card.Footer>...</Card.Footer>
  </Card>
  ```

### Menu

- `MenuSection` and `MenuItem` are bare wrappers — there is **no**
  `MenuSection.Header`, `MenuItem.Label`, `MenuItem.Description`, or
  `MenuItem.Shortcut`. Section headers use the top-level `<Header>` export from
  `@heroui/react`; item content is just children with any inline layout.
  ```tsx
  <Menu aria-label='Actions'>
    <MenuSection>
      <Header>Actions</Header>
      <MenuItem id='new'>
        <div className='flex flex-1 flex-col'>
          <span>New file</span>
          <span className='text-xs text-muted'>Create a new file</span>
        </div>
        <div className='flex gap-1'>
          <Kbd>⌘</Kbd><Kbd>N</Kbd>
        </div>
      </MenuItem>
    </MenuSection>
    <MenuSection>
      <MenuItem id='delete' variant='danger'>Delete file</MenuItem>
    </MenuSection>
  </Menu>
  ```
- `MenuItem` accepts `variant='danger'` for destructive actions.

### Select

- The dropdown content comes from the **top-level `ListBox` + `ListBoxItem`**
  exports, **not** `Select.ListBox` / `Select.Item` (which don't exist).
- `SelectValue` has no `placeholder` prop — pass a render function that
  branches on `isPlaceholder`.
  ```tsx
  import { Select, SelectValue, ListBox, ListBoxItem, Label } from '@heroui/react';

  <Select aria-label='State'>
    <Label>State</Label>
    <Select.Trigger>
      <SelectValue>
        {({ defaultChildren, isPlaceholder }) =>
          isPlaceholder ? 'Select one' : defaultChildren
        }
      </SelectValue>
      <Select.Indicator />
    </Select.Trigger>
    <Select.Popover>
      <ListBox>
        <ListBoxItem id='ca'>California</ListBoxItem>
        <ListBoxItem id='ny'>New York</ListBoxItem>
      </ListBox>
    </Select.Popover>
  </Select>
  ```

### Alert

- `status` is one of `default | accent | success | warning | danger` — there is
  **no `info` status**. Map "info" to `accent`.
- Compound structure: `Alert.Indicator`, `Alert.Content`, `Alert.Title`,
  `Alert.Description`. Action elements (e.g. a `Button`) render as siblings
  inside the `Alert`.

## Composition patterns

### Link-button — a button-shaped target that navigates

`Button` is a pressable (`react-aria-components/Button`) — no `href`, no
navigation. For a button-shaped link:

- **Project default — `LinkDecorator`** (`@components/link-decorator`). Wraps
  `next/link` with `buttonVariants`, so the DOM is a real `<a>` with button
  styling. Preserves right-click / Cmd-click, anchor focus-ring, and crawler
  discovery.

  ```tsx
  <LinkDecorator
    buttonProps={{ variant: 'ghost' }}
    href={url}
    isNewTab={true}  // external links only
  >
    <Svg src={icon} />
    <span>{label}</span>
  </LinkDecorator>
  ```

- **HeroUI-native composition — `Button > Link`.** Use when you need the
  full HeroUI Button shell (variants, pressed states, `ButtonGroup`
  joined-corner integration). The outer `Button` carries the variant; the
  inner HeroUI `Link` (`react-aria-components/Link`, i.e. an `<a>`) carries
  `href` / `target` / `rel`.

  ```tsx
  <Button variant={'ghost'}>
    <Link
      className={'no-underline'}
      href={url}
      rel={'noopener noreferrer'}
      target={'_blank'}
    >
      {children}
    </Link>
  </Button>
  ```

  Reference: `external-site.tsx` on the platform info page.

**Anti-pattern:** `Button` with `onPress={() => window.open(url)}`. Loses the
anchor — no right-click "open in new tab", no Cmd-click, no real `href`, no
SSR/crawler URL discovery. Use one of the two patterns above.

### `ButtonGroup` + navigation

`ButtonGroup` joined-corner CSS targets `.button-group .button` and re-rounds
only `:first-child` / `:last-child`. The selector resolves against `.button`'s
parent, not the `ButtonGroup` root — so wrappers that nest `.button` deeper
(e.g. `LinkDecorator`, which puts the styled `NextLink` inside a `FlexRow`)
defeat `:first-child`, and every row ends up fully rounded instead of stacked.

- For grouped/stacked navigation rows, use the `Button > Link` composition
  above — direct `<Button>` children of `ButtonGroup` get the joined-corner
  treatment correctly.
- If `LinkDecorator` is the right primitive for the row content, drop
  `ButtonGroup` and stack with `FlexColumn`; the visual ask is usually
  satisfied without the joined-corner CSS.

### Native `<button>` vs HeroUI `Button`

Anything that fires an action on press (toolbars, submits, in-row actions,
overlay closes, icon-only triggers) uses `Button` with `onPress` — never
native `<button>`, which lacks react-aria press, focus-ring theming, and
variants. For non-standard footprints (full-bleed backdrops, chip-sized
closes), neutralize HeroUI's shape with className overrides instead of dropping
to `<button>`:

```tsx
<Button
  className={'h-auto min-w-0 rounded-none p-0'}
  disableRipple={true}
  onPress={onClose}
/>
```

Reference: `Sidebar.Backdrop` in `components/sidebar/sidebar.tsx`. Native
`<button>` is acceptable only for surfaces needing `role='button'` keyboard
semantics whose primary interaction isn't a discrete press (drag handles,
focus-shifters).

## Tailwind v4 + theme

Brand colors live in `styles/global.css` as token overrides on the HeroUI
semantic surface (see `.claude/guides/UI-STYLE-GUIDE.md`), not in
`tailwind.config.js`. `styles/global.css` contains:

```css
@import 'tailwindcss';
@import '@heroui/styles/css';

@source "../app/**/*.{html,js,ts,jsx,tsx}";
@source "../components/**/*.{html,js,ts,jsx,tsx}";
@source "../providers/**/*.{html,js,ts,jsx,tsx}";
@source "../widgets/**/*.{html,js,ts,jsx,tsx}";

@theme inline {
  --font-sans: var(--font-inter);
}
```

(Plus the BEM-class hover/pressed overrides at the bottom.)

Variable names are listed in
`node_modules/@heroui/styles/dist/themes/default/variables.css`.

Light/dark is owned by `next-themes` on `<html data-theme="…">`. Token values +
the full surface: `.claude/guides/UI-STYLE-GUIDE.md`.

## Migration order

1. **Infrastructure** — postcss + global.css + providers.tsx — DONE.
2. **Trivial renames** — `Divider`→`Separator`, `CardBody`→`CardContent`,
   `Listbox`→`ListBox`, `ModalContent`→`Modal.Container`+`Modal.Dialog`,
   `Progress`→`ProgressBar`/`Circle`, `HeroUIProvider` import removal.
3. **Prop renames** (same component, different prop) — Button
   `isLoading`→`isPending`, Button `color`+`variant` collapsed to single
   `variant` token (see flip table).
4. **Variant/color flip** — Button + Chip + Alert + StatusDecorator call-site
   rewrites.
5. **Compound restructure** — Tabs (`Tab title=…` → `Tabs.Tab` + `Tabs.Panel`),
   Modal (`isOpen/onClose` → `state={useOverlayState()}`), Table.
6. **Form-field rehoming** — every
   `<Input label= isRequired isInvalid= errorMessage= startContent= onValueChange=>`
   becomes `<TextField …><Label /><Input /><FieldError /></TextField>`. Not a
   per-prop rename — the whole field migrates to `TextField`.
7. **Removed-component substitutions** — Spacer (→ Tailwind), Image (→
   next/image), Snippet (→ custom), getKeyValue (→ direct access).
8. **Removed-prop sweeps** — Modal (`onClose`/`hideCloseButton`), Chip
   (`onClose`), Table (`bottomContent`/`isStriped`/`removeWrapper`).
9. **Local component contracts** — `StatusDecoratorProps` and
   `DeleteSwiperProps` require `children`; audit every call site.

## Testing gotchas

Tests querying components that wrap interactive children in React Aria's
pressable layer (`Modal.Trigger`, `Popover.Trigger`, `Tooltip.Trigger`,
`Dropdown.Trigger`, …) hit a duplicate-role-button trap. The wrapper renders an
outer `<div role="button">` _and_ the inner `<button>` keeps its native role,
so both expose the same accessible name to `getByRole`:

```html
<div
  role="button"
  data-slot="modal-trigger"
  aria-expanded="false"
>
  <button data-slot="button">Open modal</button>
</div>
```

`canvas.getByRole('button', { name: 'Open modal' })` throws _"Found multiple
elements with the role 'button'"_.

**Fix** — narrow with a tagName filter so the query resolves to the real
`<button>` (skipping the wrapper). Clicking either fires the same React Aria
press, so the test still exercises the user-facing behavior:

```tsx
const trigger = canvas
  .getAllByRole('button', { name: 'Open modal' })
  .find((el): el is HTMLButtonElement => el.tagName === 'BUTTON');
await userEvent.click(trigger!);
```

The same applies to any v3 compound exposing a `.Trigger` sub-part — they all
share this wrapper-plus-child shape.

## Storybook integration

`@storybook/nextjs-vite` + `@storybook/addon-vitest` is wired up. Stories scan
from `stories/**`, `components/**`, and `widgets/**`. `.storybook/preview.tsx`
mounts `<Toast.Provider />` and imports `styles/global.css` so every story
renders with the production theme.

- `npm run storybook` — dev server (port 6006).
- `npm run test:storybook` — headless Chromium play-function runner via Vitest.
  Separate from `npm run test:unit` (jest).
- `npm run build-storybook` — static build for hosting.

a11y violations show in the test UI (`parameters.a11y.test: 'todo'`) but don't
fail CI yet — flip to `'error'` in `.storybook/preview.tsx` to gate on a11y.

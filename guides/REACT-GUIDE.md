# React Component Style Guide

Formatting conventions for React components. All components follow this
structure. The TypeScript baseline is the
[Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html);
these rules and `CLAUDE.md` are the project-specific layer on top.

## File Structure

Components are organized into labeled sections using JSDoc-style block comment
annotations, each separated by a blank line.

### Marker format — always 3 lines, blank line above

Every section marker uses the 3-line JSDoc form with a blank line directly
above it:

```tsx
/**
 * @section
 */
```

**Never** collapse to the one-line form `/** @section */` — the 3-line shape
plus the blank line above is what the reader's eye scans for. Applies to every
marker without exception: top-level (`@imports`, `@constants`, `@component`,
`@helpers`, …), in-function (`@state`, `@derived`, `@render`, …), and inside
indented blocks (the marker keeps the surrounding indentation; the blank line
above remains).

### Top-Level Sections (outside the component function)

Sections appear in this order; include only those used.

```tsx
'use client'; // only if needed

/**
 * @imports
 */

/**
 * @logger
 */

/**
 * @constants
 */

/**
 * @defaults
 */

/**
 * @props
 */

/**
 * @component
 */
```

### Component-Level Sections (inside the component function)

Sections appear in this order inside the body; include only those used.

```tsx
/**
 * @hooks
 */

/**
 * @locale
 */

/**
 * @state
 */

/**
 * @memos
 */

/**
 * @callbacks
 */

/**
 * @effects
 */

/**
 * @render
 */

/**
 * @helpers
 */
```

## Imports

Imports are grouped by source with a single-line comment label above each
group, separated by a blank line. Groups appear in alphabetical order, except
node_modules is always first:

1. `// node_modules` — third-party packages (e.g., `@heroui/react`, `react`,
   `next/navigation`)
2. `// app` — app-level imports (e.g., `@app/app-routes`)
3. `// components` — shared components (e.g., `@components/flex`)
4. `// icons` — icon imports (e.g., `@icons/eye`)
5. `// lib` — lib imports (e.g., `@lib/enums/breakpoints`)
6. `// local` — local/sibling file imports (e.g., `'./collection-editor-state'`)
7. `// locale` - locale imports for translations and language features (e.g.
   data formatting, RTL or LTR reading)
8. `// logger` — logger imports (e.g., `@log`)
9. `// repositories` — repository imports
10. `// services` — service imports
11. `// store` — Redux store imports (e.g., `@redux/actions`, `@redux/hooks`,
    `@redux/selectors`)
12. `// widgets` — widget imports

Within each group, imports are ordered alphabetically by path. Use alias paths
(`@components/...`, `@lib/...`, …) — never relative, except `// local` imports
which use `'./...'`.

```tsx
/**
 * @imports
 */
// node_modules
import { Button, Spacer } from '@heroui/react';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';

// app
import { AppRoutes } from '@app/app-routes';

// components
import { FlexColumn } from '@components/flex';
import { Section } from '@components/section';

// icons
import icon_eye from '@icons/eye';
import icon_layers_fill from '@icons/layers-fill';

// store
import { ClientActions } from '@redux/actions';
import { useAppDispatch, useAppSelector } from '@redux/hooks';
import { selectAdminPlatforms } from '@redux/selectors';
```

## Logger

When a component logs, declare the logger as a top-level constant.

```tsx
/**
 * @logger
 */
const logger = createLogger('components/item-editor');
```

## Constants

Module-level constants go after the logger and before props.

```tsx
/**
 * @constants
 */
const DEFAULT_SUMMARY: string = '-';
const PLATFORM_LIST_LIMIT = 20;
```

## Default Props

For complex default prop values, define a top-level constant object.

```tsx
/**
 * @defaults
 */
const DEFAULT_PROPS: SectionProps = {
  className: 'p-2 w-full',
  titleProps: { className: 'font-semibold text-lg' },
};
```

## Props

Props types use `type` (not `interface`), placed directly before the component.
Use intersection types to extend shared prop types.

```tsx
/**
 * @props
 */
export type CollectionEditorProps = FlexProps & {
  collectionKey: string;
};
```

## Component Declaration

Components are named function declarations (not arrow functions), with
`Readonly<Props>` for the props parameter.

- Page components: `export default function Page()`
- Reusable components: `export function ComponentName(props: Readonly<Props>)`

Props are destructured at the top of the body, before any section annotations.
Use rest spreading when passing through to a wrapper element.

```tsx
/**
 * @component
 */
export function CollectionEditor(props: Readonly<CollectionEditorProps>) {
  const { collectionKey, ...rest } = props;
```

## Locale & Translations

This project uses [`next-intl`](https://next-intl.dev/) for i18n. Translation
strings live in JSON message files under `messages/` (e.g., `messages/en.json`).
Non-translation locale metadata (country code, currency, date formats) lives in
`public/locales/` (e.g., `public/locales/en-US.json`), accessed via the
`useLocaleSettings()` hook from `@providers/locale`.

### Architecture

```
messages/en.json          — translation strings (managed by next-intl)
public/locales/en-US.json — locale metadata (currency, date formats, etc.)
i18n/request.ts           — next-intl server config (loads messages)
providers/locale/          — LocaleProvider (wraps NextIntlClientProvider)
```

### `useTranslations()` — accessing translation strings

Import `useTranslations` from `next-intl`; pass a namespace matching a top-level
key in the messages JSON. Place it in the `@locale` section (after `@hooks`,
before `@state`).

```tsx
/**
 * @locale
 */
const t = useTranslations('global');
```

Then use `t('key')` in JSX instead of hardcoded strings:

```tsx
<Button>{t('save')}</Button>
<Input placeholder={t('search')} />
```

For nested namespaces, dot into them:

```tsx
const t = useTranslations('widgets.filterWidget');
// t('contains') → "Contains"
// t('startsWith') → "Starts with"
```

### `useLocaleSettings()` — accessing locale metadata

For non-translation locale data (currency, date formats, country code), use
`useLocaleSettings()` from `@providers/locale`, in the `@locale` section
alongside `useTranslations`.

```tsx
/**
 * @locale
 */
const t = useTranslations('global');
const { currency, time } = useLocaleSettings();
```

### Messages JSON structure

Translation keys are organized by namespace in `messages/en.json`:

```json
{
  "global": {
    "actions": "Actions",
    "cancel": "Cancel",
    "save": "Save",
    "search": "Search"
  },
  "errors": {
    "unknown": "An unknown error occurred."
  },
  "widgets": {
    "filterWidget": {
      "contains": "Contains",
      "startsWith": "Starts with"
    }
  }
}
```

### Import grouping

`useTranslations` (from `next-intl`) goes in `// node_modules`;
`useLocaleSettings` goes in `// providers`.

```tsx
// node_modules
import { useTranslations } from 'next-intl';

// providers
import { useLocaleSettings } from '@providers/locale';
```

## Hooks

Third-party and built-in hooks other than `useState`, `useMemo`, `useCallback`,
`useEffect` go in `@hooks` — `useId`, `useRouter`, `useReducer`, etc.

```tsx
/**
 * @hooks
 */
const instanceId = useId();
const router = useRouter();
```

## State

`useState` declarations, `useReducer` state, Redux selectors, and destructured
state all belong in `@state`.

```tsx
/**
 * @state
 */
const dispatch = useAppDispatch();
const activity = useAppSelector(selectAdminActivity);
const [isCollapsed, setIsCollapsed] = useState<boolean>(false);
```

When using `useReducer`, destructure the state object in this section:

```tsx
/**
 * @state
 */
const [state, dispatch] = useReducer(Reducer, getDefaultState());
const { editableItem, isErrored, isLoading, isSaving } = state;
```

### Render-phase sync over `setState`-in-`useEffect`

Synchronous `setState` in a `useEffect` body causes cascading renders and trips
`react-hooks/set-state-in-effect` (errors locally). When state must react to a
prop or other state changing, track the previous value in its own `useState`
and call setters during render inside an `if`-block:

```tsx
// Bad — synchronous setState in effect body
useEffect(() => {
  setDisplayCount(PAGE_SIZE);
}, [searchQuery, selectedKinds]);

// Good — render-phase sync
const [prevSearch, setPrevSearch] = useState<string>('');
if (searchQuery !== prevSearch) {
  setPrevSearch(searchQuery);
  setDisplayCount(PAGE_SIZE);
}
```

Effects remain correct for *external* synchronization (Firestore snapshots, DOM
observation, async fetches — setters inside `.then` / `.catch` are fine because
they run after render). Reference:
`components/user-editor-drawer/user-editor-drawer.tsx`.

## Memos

`useMemo` declarations go in `@memos`.

```tsx
/**
 * @memos
 */
const isNew: boolean = useMemo(() => isNewKey(collectionKey), [collectionKey]);
```

## Callbacks

`useCallback` declarations go in `@callbacks`, ordered alphabetically.

```tsx
/**
 * @callbacks
 */
const onNameCallback = useCallback(
  (value: string) => dispatch(Actions.SET_NAME(value)),
  [],
);

const onSummaryCallback = useCallback(
  (value: string) => dispatch(Actions.SET_SUMMARY(value)),
  [],
);
```

## Effects

`useEffect` declarations go in `@effects`. Each may have a short comment
describing its purpose.

```tsx
/**
 * @effects
 */
// use a trigger to load item data
useEffect(() => {
  if (isNew) {
    createItemCallback();
  } else {
    getItemCallback();
  }
}, [createItemCallback, getItemCallback, isNew, itemKey]);
```

## Render

The return statement goes in `@render`. Early returns (loading states, error
guards, redirects) go at the top, before the main return.

```tsx
/**
 * @render
 */
if (isLoading) {
  return <LoadingIndicator />;
}
return (
  <FlexColumn
    gap={0}
    {...rest}
  >
    {/* Exit Button */}
    <SmartExitButton />
  </FlexColumn>
);
```

## Helpers

Helper functions that support the component but aren't hooks, callbacks, or
memos go in `@helper` sections — each gets its own `@helper` annotation. Place
them after `@render` when used only within JSX (e.g., sub-render functions), or
before `@render` when used in component logic.

Helpers are plain functions — not `useCallback` or `useMemo` — for stateless
formatting, grouping, or rendering logic that doesn't depend on React lifecycle.

```tsx
/**
 * @helper
 */
function formatTimestamp(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, {
    hour: 'numeric',
    minute: '2-digit',
  });
}

/**
 * @helper
 */
function groupByDate(
  messages: Message[],
): Array<
  { type: 'separator'; label: string } | { type: 'message'; message: Message }
> {
  const items: Array<
    { type: 'separator'; label: string } | { type: 'message'; message: Message }
  > = [];
  let lastDate = '';

  for (const message of messages) {
    const dateLabel = new Date(message.timestamp).toLocaleDateString();

    if (dateLabel !== lastDate) {
      items.push({ type: 'separator', label: dateLabel });
      lastDate = dateLabel;
    }

    items.push({ type: 'message', message });
  }

  return items;
}
```

Module-level helpers appear between `@constants` / `@defaults` and `@props`:

```tsx
/**
 * @constants
 */
const PAGE_SIZE = 20;

/**
 * @helper
 */
function buildFilterKey(filters: Filter[]): string {
  return JSON.stringify(filters);
}

/**
 * @helper
 */
function isValidStatus(status: string): boolean {
  return VALID_STATUSES.includes(status);
}

/**
 * @props
 */
export type MyComponentProps = { ... };
```

## JSX Formatting

### Props

- Each prop on its own line when the element has more than one prop
- Props ordered alphabetically
- String literals wrapped in curly braces with single quotes: `{'text'}`
- Boolean `true` values explicit: `isRequired={true}`

```tsx
<Button
  color={'danger'}
  onPress={onSignOutCallback}
>
  {'Sign Out'}
</Button>
```

### Prefer component defaults

Shared components (`Flex` / `FlexRow` / `FlexColumn`, `Section`, `Card`,
`TextField`, …) have thoughtful defaults — pass a prop only when the style
genuinely needs to differ. Don't restate a value the component already supplies;
the fewer props, the louder the deviations.

```tsx
// Bad — every prop just restates a component default, burying the one
// genuine deviation in the noise
<FlexRow gap={4} items={'center'} justify={'between'} wrap={'nowrap'}>
  ...
</FlexRow>

// Good — only the actual deviation is named; the rest fall back
<FlexRow justify={'between'}>
  ...
</FlexRow>
```

### No inline arrow functions in event-handler props

Handler-shaped props (`onPress`, `onClick`, `onChange`, `onValueChange`,
`onSelect`, `onSubmit`, …) must reference a `useCallback` from `@callbacks` or a
stable direct function reference — an inline arrow allocates a fresh function
each render and defeats `React.memo` downstream.

```tsx
// Bad
<Button onPress={() => setIsOpen(false)} />

// Good
const onClose = useCallback(() => setIsOpen(false), [setIsOpen]);
<Button onPress={onClose} />
```

Transform callbacks (`array.map(x => …)`, `.then(data => …)`) stay inline. If a
list-row needs to capture row data (`onPress={() => f(item.id)}`), extract the
row to its own component so the handler can be a `useCallback` there.

### Inline Comments

Use `{/* Comment */}` to label logical sections within JSX, as visual
separators for groups of related elements.

```tsx
{
  /* Header */
}
<h1 className={'font-bold text-lg'}>{'Admin Dashboard'}</h1>;

{
  /* Overview */
}
<Section title={'Overview'}>...</Section>;
```

## Server Components

Server components (async functions) follow the same structure but omit
`'use client'` and client-only sections (`@hooks`, `@state`, `@memos`,
`@callbacks`, `@effects`). Logic runs directly in the function body between
`@component` and `@render`.

```tsx
/**
 * @imports
 */
// node_modules
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

// services
import { AuthService } from '@services/auth-service';

/**
 * @component
 */
export default async function Page({ searchParams }: Readonly<NextPageProps>) {
  const requestCookies = await cookies();
  const authStatus = await AuthService.getServerUserStatus(requestCookies);

  /**
   * @render
   */
  if (authStatus !== AuthStatus.AUTHENTICATED) {
    return <AuthenticationWidget />;
  }
  return redirect(AppRoutes.SIGN_IN);
}
```

## Full Example

```tsx
'use client';

/**
 * @imports
 */
// node_modules
import { Input, Spacer } from '@heroui/react';
import { useTranslations } from 'next-intl';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useId, useMemo, useReducer } from 'react';

// app
import { AppRoutes } from '@app/app-routes';

// components
import { FlexColumn, FlexProps } from '@components/flex';
import { LoadingIndicator } from '@components/loading-indicator';
import { Section } from '@components/section';

// lib - models
import { Item } from '@lib/models/item';

// local
import {
  getDefaultState,
  ItemEditorActions as Actions,
  ItemEditorReducer as Reducer,
} from './item-editor-state';

// logger
import { createLogger } from '@log';

// services
import { ItemService } from '@services/item-service';

/**
 * @logger
 */
const logger = createLogger('components/item-editor');

/**
 * @constants
 */
const DEFAULT_MEDIUM: string = '-';

/**
 * @props
 */
export type ItemEditorProps = FlexProps & {
  itemKey: string;
};

/**
 * @component
 */
export function ItemEditor(props: Readonly<ItemEditorProps>) {
  const { itemKey, ...rest } = props;

  /**
   * @hooks
   */
  const instanceId = useId();
  const router = useRouter();

  /**
   * @locale
   */
  const t = useTranslations('global');

  /**
   * @state
   */
  const [state, dispatch] = useReducer(Reducer, getDefaultState());
  const { editableItem, isLoading, isSaving } = state;

  /**
   * @memos
   */
  const isNew: boolean = useMemo(() => isNewKey(itemKey), [itemKey]);

  /**
   * @callbacks
   */
  const onNameCallback = useCallback(
    (value: string) => dispatch(Actions.SET_NAME(value)),
    [],
  );

  const saveItemCallback = useCallback(() => {
    dispatch(Actions.SET_IS_SAVING(true));
    ItemService.update(editableItem)
      .then((data: Item | null) => {
        if (data !== null) {
          dispatch(Actions.SET_EDITABLE_ITEM(data));
        }
      })
      .catch((error) => logger.error(error))
      .finally(() => dispatch(Actions.SET_IS_SAVING(false)));
  }, [editableItem]);

  /**
   * @effects
   */
  useEffect(() => {
    if (!isLoading) {
      saveItemCallback();
    }
  }, [editableItem, isLoading, saveItemCallback]);

  /**
   * @render
   */
  if (isLoading) {
    return <LoadingIndicator />;
  }
  return (
    <FlexColumn
      gap={0}
      {...rest}
    >
      {/* Information */}
      <Section title={t('information')}>
        <Input
          defaultValue={editableItem.name}
          isRequired={true}
          label={t('name')}
          onValueChange={onNameCallback}
        />
      </Section>
    </FlexColumn>
  );
}
```

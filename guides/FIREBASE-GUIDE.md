# Firebase Architecture Guide

Reference for Firebase across projects sharing this architecture. File paths are
illustrative; the **roles, boundaries, and patterns** are fixed.

---

## 1. Directory & File Layout

| Location                                 | Purpose                                                                                                                                                                                  |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/firebase.json` (project root)          | Firebase CLI config. Points to rules/indexes under `firebase/`.                                                                                                                          |
| `/firebase/`                             | Deploy artifacts: `firestore.rules`, `firestore.indexes.json`, `storage.rules`. Never application code.                                                                                  |
| `/repositories/firebase.ts`              | Initializes the client SDK. Exports `FIREBASE`, `AUTH`, `FIRESTORE`, `STORAGE`, `ANALYTICS`.                                                                                             |
| `/repositories/firestore.ts`             | `FirestoreClient` — thin static wrapper over the client SDK (CRUD, `watch`, `watchCollection`, `buildPath`, `validate`).                                                                 |
| `/repositories/firestore-admin.ts`       | Admin SDK wrapper for server-only code (API routes, instrumentation, event consumers). Never imported from client.                                                                       |
| `/repositories/*-repository.ts`          | Optional per-entity repositories extending `FirestoreClient` with entity-specific queries (rare — most entities go through services).                                                    |
| `/services/firebase-service.ts`          | `FirebaseService<T>` — base class every domain service extends. Typed `create`/`get`/`getAll`/`update`/`delete`/`count`/`watch`/`watchAll` delegating to `FirestoreClient`.              |
| `/services/<entity>/<entity>-service.ts` | Domain services. Extend `FirebaseService<T>`, inject a `DynamicDocument`, add domain logic (cascade deletes, rollups, input-schema validation, ID generation).                           |
| `/lib/firebase/dynamic-document.ts`      | `DynamicDocument` type.                                                                                                                                                                  |
| `/lib/firebase/platform-context.ts`      | `PlatformContext` type (optional — only with multi-tenant scoping).                                                                                                                      |
| `/lib/schemas/<entity>.ts`               | Zod schemas + `DynamicDocument` constant per entity.                                                                                                                                     |
| `/hooks/use-firestore.ts`                | Client hooks: `useFirestore`, `useFirestoreDocument`, shared `subscribeToQuery`/`subscribeToDocument` helpers.                                                                           |

**Rule:** The client SDK (`firebase/app`, `firebase/firestore`, etc.) is
imported **only** from `/repositories/firebase.ts`,
`/repositories/firestore.ts`, and `/hooks/use-firestore*.ts`. Everything else
goes through services.

---

## 2. `firebase.json` (Project Root)

Lives at the **repository root**, references artifacts inside `/firebase/`:

```json
{
  "firestore": {
    "indexes": "firebase/firestore.indexes.json",
    "rules": "firebase/firestore.rules"
  },
  "storage": {
    "rules": "firebase/storage.rules"
  }
}
```

Don't keep `firestore.rules` or `firestore.indexes.json` at the root — they
belong inside `/firebase/`.

---

## 3. Client SDK Initialization (`repositories/firebase.ts`)

Single entry point for the client SDK; exports initialized singletons. Must
tolerate a missing API key at build time (use a placeholder so the build
doesn't crash — warn at runtime instead).

```ts
export const FIREBASE = initializeApp(FIREBASE_CONFIG);
export const AUTH = getAuth(FIREBASE);
export const FIRESTORE = getFirestore(FIREBASE);
export const STORAGE = getStorage(FIREBASE);
export const ANALYTICS = isSupported().then((ok) =>
  ok ? getAnalytics(FIREBASE) : null,
);
```

Server code must not import from this file — use `firestore-admin.ts`.

---

## 4. `FirestoreClient` (`repositories/firestore.ts`)

Static class. All methods take a `DynamicDocument` + optional `PlatformContext`
and resolve the full collection path via `buildPath`. Responsibilities:

- `buildPath(document, platformContext?)` — prepends `platforms/{id}/` when
  `scoped: true`.
- `create` — if `data.id` is provided, uses `setDoc`; otherwise `addDoc` and
  writes `id` back into the doc.
- `get` / `getAll` — runs `document.formatter` (if any), then `schema.parse`.
- `update` — `setDoc(..., { merge: true })` with a partial.
- `delete` — `deleteDoc`.
- `watch` / `watchCollection` — `onSnapshot` wrappers. `watchCollection` fans
  `docChanges` into `onCreate`/`onUpdate`/`onDelete` callbacks.
- Default query constraints: if the schema declares `is_archived` or
  `is_hidden`, `getAll` auto-filters them out unless explicitly opted in.

Never add business logic here — it is a typed, schema-aware proxy for the SDK.

---

## 5. `DynamicDocument` + Zod Schemas

Every collection is described by a `DynamicDocument`:

```ts
// lib/firebase/dynamic-document.ts
export type DynamicDocument<T extends z.ZodRawShape = z.ZodRawShape> = {
  path: string; // e.g. 'projects'
  schema: z.ZodObject<T>; // Zod validator
  scoped: boolean; // platform-prefixed?
  formatter?: (data: unknown) => Record<string, unknown>; // optional normalizer
};
```

### Pattern per entity (`lib/schemas/<entity>.ts`)

1. Define the Zod schema (source of truth for both runtime validation and the
   TS type via `z.infer`).
2. Define input schemas for create/update (usually `.partial()` of the main
   schema or a narrower pick).
3. Export a single `<ENTITY>_DOC: DynamicDocument` constant.

```ts
export const projectSchema = z.object({
  id: z.string(), // always present on reads — Firestore-generated
  /* ... */
});
export type Project = z.infer<typeof projectSchema>;

export const createProjectSchema = z.object({
  /* subset — NEVER includes id */
});
export type CreateProjectInput = z.infer<typeof createProjectSchema>;

export const updateProjectSchema = createProjectSchema.partial();
export type UpdateProjectInput = z.infer<typeof updateProjectSchema>;

export const PROJECT_DOC: DynamicDocument = {
  path: 'projects',
  schema: projectSchema,
  scoped: true,
};
```

### ID generation

**Firestore auto-generates every document ID.** Services do NOT create IDs with
custom prefixes (`plt_…`, `itm_…`) or UUIDs. On `create`, the service passes an
entity with `id` absent; `FirestoreClient.create` calls `addDoc`, receives the
Firebase-assigned ID, writes it back into the document body, and returns the
full entity with `id` populated.

Rules:

- `createXSchema` never includes `id` — the field doesn't exist on the
  create-input type.
- The main schema has `id: z.string()` (required) because every read carries an
  id.
- Inside `createX`, build the full entity **without** `id`, type-assert to the
  entity type (the id is filled in immediately by `FirestoreClient`), and call
  `this.create(entity)`.
- Don't store a separate `key` field that duplicates `id`. If a legacy `key`
  was always equal to `id`, drop it. If `key` is a distinct human-readable
  value (e.g. a ticker like `PLTZ`), keep it as an independent domain field.

### Why this shape

- One place to change the field set — schema, TS type, validation, and
  collection path stay in lockstep.
- `FirestoreClient` validates every read and applies the formatter without the
  service knowing.
- Input schemas keep route handlers terse — they call `schema.parse(body)` and
  hand the result to the service.

---

## 6. `FirebaseService<T>` (`services/firebase-service.ts`)

Base class every domain service extends. Provides standard CRUD + real-time API
and owns the per-service logger.

```ts
export class FirebaseService<T extends { id?: string }> {
  protected readonly document: DynamicDocument;
  protected readonly logger: LoggerInstance;

  constructor(document: DynamicDocument, loggerName: string) {
    this.document = document;
    this.logger = createLogger(loggerName);
  }

  // count, create, delete, get, getAll, update, watch, watchAll
  // — all delegate to FirestoreClient, wrapped in try/catch + logger.error
}
```

Public surface (every domain service inherits these):

| Method                                       | Behavior                                            |
| -------------------------------------------- | --------------------------------------------------- |
| `count(filters?, platformId?)`               | `getCountFromServer`; returns `0` on error.         |
| `create(data, platformId?)`                  | Returns the created doc with `id`; throws on error. |
| `get(id, platformId?)`                       | Returns `T \| null`; returns `null` on error.       |
| `getAll(filters?, platformId?)`              | Returns `T[]`; returns `[]` on error.               |
| `update(id, partial, platformId?)`           | Merge-update; throws on error.                      |
| `delete(id, platformId?)`                    | Throws on error.                                    |
| `watch(id, onUpdate, platformId?)`           | Returns an `Unsubscribe`.                           |
| `watchAll(callbacks, filters?, platformId?)` | `onCreate`/`onUpdate`/`onDelete`.                   |

**Naming convention:** the base file is always `firebase-service.ts` and the
exported class is always `FirebaseService`. Don't use `base-service` — it is
ambiguous and the Firebase binding is load-bearing.

### Domain Service Pattern

```ts
class ProjectServiceClass extends FirebaseService<Project> {
  constructor() {
    super(PROJECT_DOC, 'ProjectService');
  }

  async createProject(
    input: CreateProjectInput,
    platformId: string,
  ): Promise<Project> {
    const validated = createProjectSchema.parse(input);
    const now = new Date().toISOString();

    // Build the entity without `id` — Firestore assigns it on write.
    const project = {
      /* ...derive full entity from validated, no id field... */
      createdAt: now,
      updatedAt: now,
    } as Project;

    return this.create(project, platformId);
  }

  async findByKey(key: string, platformId: string): Promise<Project | null> {
    const results = await this.getAll([['key', '==', key]], platformId);
    return results[0] ?? null;
  }
}

export const projectService = new ProjectServiceClass();
```

Rules:

- Services are **singletons** (`export const xService = new XServiceClass()`).
- **IDs are never generated in the service.** Let Firestore auto-assign;
  `FirestoreClient.create` writes the assigned ID back and returns the entity
  with `id` populated.
- Domain logic (timestamps, derived fields, cascades, defaults) lives in the
  service — not in components, routes, or `FirestoreClient`.
- Input validation uses the Zod input schema (`createXSchema.parse(input)`).
- Never talk to the client SDK directly from a service — always through
  `FirebaseService` (inherited) or `FirestoreClient` (uncommon cases).

---

## 7. `useFirestore` and Related Hooks

Client components read Firestore through `useFirestore` /
`useFirestoreDocument` rather than calling services directly: services are for
one-shot reads/mutations, while hooks own subscriptions, loading state, error
aggregation, and optimistic updates.

### `useFirestore<T>(document, options?)`

Real-time collection subscription. Returns:

```ts
{
  data: T[];
  errors: string[];
  isLoading: boolean;
  mutations: {
    create: (data: T) => Promise<T>;
    delete: (id: string) => Promise<void>;
    update: (id: string, partial: Partial<T>) => Promise<void>;
  };
}
```

Options: `filters`, `limit`, `orderBy`, `platformId`.

- Subscribes via `onSnapshot` in a `useEffect`.
- Uses `startTransition` to batch snapshot updates.
- Suppresses metadata-only snapshots after the first load (`hasLoaded` flag).
- Stabilizes `filters` / `orderBy` via content-keyed refs — callers can pass
  inline arrays/objects without triggering resubscribes.
- Mutations are **optimistic**: local state updates first, the Firestore write
  follows. A `resync` token forces a re-subscribe on mutation failure to
  recover server state.
- Error strings are deduped in an array; hooks exposing a single `Error | null`
  should select `errors[0]`.

### `useFirestoreDocument<T>(document, docId, options?)`

Same shape for a single document. `docId = null` yields `data: null` and
suspends the subscription (useful for "create new" screens).

### Higher-level hooks

Thin wrappers over `useFirestore` for opinionated lists (e.g.
`useFirestoreChat`, `useFirestoreNotifications`, `useFirestoreAgents`) — memoize
filters with `useMemo`, translate `errors: string[]` into an `Error | null` if
consumers prefer it, and reshape names (`data` → `messages`, etc.) at the
boundary only.

### Escape hatch

`useFirestoreCollection(collectionPath, filters?, options?)` accepts a raw path
(no `DynamicDocument`). Reserve it for admin/debug surfaces. Production code
should always route through a `DynamicDocument` so validation, formatters, and
platform scoping apply uniformly.

### Subscription internals

`subscribeToQuery` and `subscribeToDocument` are shared helpers — always call
`setIsLoading(true)` on subscribe, wrap `onNext`/`onError` in `startTransition`,
and return the raw `onSnapshot` unsubscribe. New hooks needing custom snapshot
logic should compose these, not call `onSnapshot` directly.

---

## 8. Multi-Tenant Scoping (Optional)

If multi-tenant, documents live under `platforms/{platformId}/...` and
`DynamicDocument.scoped = true`.

- `FirestoreClient.buildPath` prepends the prefix when a `PlatformContext` is
  provided.
- `FirebaseService` methods accept an optional trailing `platformId` and
  internally build the `PlatformContext`.
- Client components pull the current `platformId` from a provider
  (`PlatformProvider`) and pass it to hooks via `options.platformId`.
- Firestore rules enforce role-based access inside `platforms/{id}/` (members
  read, editors create/update, owners delete).

Single-tenant projects: set `scoped: false` on every `DynamicDocument` and omit
`platformId` everywhere.

---

## 9. Client vs. Server SDK Boundary

| Context                                                                                     | Use                                                                   |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| React components, client hooks                                                              | `repositories/firebase.ts` + `repositories/firestore.ts` (client SDK) |
| API route handlers, server components, instrumentation, event consumers, background workers | `repositories/firestore-admin.ts` (Admin SDK)                         |

Never import `firebase/firestore` from server code. Never import
`firebase-admin` from client code. Both must not appear in the same module.

Services (`/services/`) run on both sides depending on caller — they delegate
through `FirebaseService`, which picks the right underlying client. If a project
needs a split, introduce `FirebaseAdminService` with the same API shape, not
branching inside a single class.

---

## 10. Checklist When Adding a New Entity

1. **Schema** — `lib/schemas/<entity>.ts`: Zod schema + `z.infer` type;
   `createXSchema` / `updateXSchema` for API inputs; `X_DOC: DynamicDocument`
   constant (`path`, `schema`, `scoped`).
2. **Service** — `services/<entity>/<entity>-service.ts`: class extends
   `FirebaseService<X>`; constructor passes `X_DOC` + logger name; domain
   methods parse input schemas and call inherited CRUD; export a singleton.
3. **Hook (if needed)** — `hooks/use-<entity>.ts` (or inline with
   `useFirestore(X_DOC, ...)`): memoize filters; map `errors` → `Error | null`
   if that's your convention.
4. **Rules & indexes** — update `firebase/firestore.rules` and
   `firebase/firestore.indexes.json` for new collection paths and compound
   queries.
5. **No changes** to `FirestoreClient` or `FirebaseService` — if a new entity
   pushes you to edit them, it almost certainly belongs in the domain service.

---

## 11. Anti-Patterns

- Importing `firebase/firestore` from a component, service, or route handler.
  Always route through `FirestoreClient` / `FirebaseService` / `useFirestore`.
- Defining a Firestore collection path as a string literal outside a
  `DynamicDocument`. Every collection has exactly one `DynamicDocument` and one
  Zod schema.
- Passing raw Firestore `where(...)` clauses across module boundaries. Use the
  `[field, op, value]` tuple form that `FirestoreClient`, `FirebaseService`,
  and `useFirestore` all accept.
- Mutating state inside an `onSnapshot` callback without `startTransition` —
  snapshot bursts will hammer React renders.
- Subscribing with inline array/object options without memoization — pass
  memoized values or use the content-keyed hooks (`useFirestore` handles this;
  custom hooks must too).
- Naming the base service class anything other than `FirebaseService` in file
  `firebase-service.ts`.
- Generating document IDs in a service (custom prefixes, UUIDs, slug-derived
  keys as IDs). Let Firestore auto-assign via `addDoc`. Human-readable keys are
  a separate field (e.g. `key: 'PLTZ'`), not the document ID.
- Storing a `key` field that duplicates `id`. Drop the duplicate.

---

## 12. Cloud Storage — Media Layout & Pipeline

Media binaries (audio, images, panoramas, videos) live in Cloud Storage,
**separate** from their Firestore docs. A wrong path is a silent 404 — read
this before resolving any media URL.

### Source of truth

`firebase/functions/src/lib/paths.ts` is the canonical on-disk layout; it
mirrors `firebase/storage.rules` and the two are halves of one contract (add a
path to the rules, add the builder here). On the **functions** side never
concatenate by hand — use `mediaPath(kind, stage, file)` /
`thumbnailPath(kind, stage, file)`. On the **client** side, services use a
per-kind constant plus a stage segment and must stay in lockstep with those two
files:

```ts
const AUDIO_STORAGE_PATH = 'audios';
const IMAGE_STORAGE_PATH = 'images';
const PANORAMA_STORAGE_PATH = 'panoramas';
const VIDEO_STORAGE_PATH = 'videos';
```

### Path shape

```
{kind}/{stage}/{file}
{kind}/thumbnails/{stage}/{file}     // audio / panorama / video thumbnails
{kind}/captions/{stage}/{file}       // audio / panorama / video captions
```

- **Kinds:** `audios`, `images`, `panoramas`, `videos`.
- **Tenant scope is NOT in the path** — it lives in the object's
  `metadata.platformId` and the StorageReference doc. `Storage.get(path, scope)`
  (`@repositories/storage`) applies scope via `buildPath`.

### Stages — and which to read at runtime

- **`ingests/{id}.{type}`** — the raw upload. Writing here fires the
  `on-media-write` trigger → media-processor, which produces the stages below.
  **Never read at runtime:** transient (consumed by the processor, may be
  cleaned up) and frequently absent on migrated data. Reading it is the classic
  silent 404.
- **`originals/{id}.{type}`** — the persistent full-resolution copy at the
  upload's **true aspect ratio** and original extension. The full-res source;
  survives until the media doc itself is deleted.
- **`resizes/...`** — derived **square** (image) / tiled (panorama) variants,
  always re-encoded to `.jpeg`. Use for fast, sized display. Also where the
  normalized, playable **video** lands (`videos/resizes/{id}.{type}`).
- **`processed/{id}.{type}`** — the normalized, playable **audio** file
  (`audios/processed/...`). Not every kind has this stage — images don't, and
  video uses `resizes/` for its playable output.

> **The rule that caused a real bug:** to show a full-resolution image, read
> `{kind}/originals/{id}.{type}` — **not** `ingests/`. `ingests/` is an upload
> entry point, not a readable asset.

### Per-kind read map (where each `getSources` looks)

- **Image** — `image-service.getSources`: square resizes
  `images/resizes/{id}_{1000|500|100}x{N}.jpeg` (sizes from the `ImageSizes`
  enum: `LARGE = 1000`, `SMALL = 500`, `THUMB = 100`) and, when
  `includeOriginal` is passed, the true-aspect `images/originals/{id}.{type}`.
- **Audio** — `audio-service.getSources`: the audio file
  `audios/processed/{id}.{type}`. Its preview imagery is **not** an audio path —
  it resolves the audio's `previewImageId` through
  `ImageService.resolvePreviewSources`, so audio thumbnails are Image resizes /
  originals.
- **Video** — `videos/resizes/{id}.{type}`, with thumbnail and caption inputs
  under `videos/thumbnails/...` and `videos/captions/...`.
- **Panorama** — the full panorama `panoramas/resizes/{id}_full.jpeg` and tiles
  `panoramas/resizes/{id}_tile=x{X}-y{Y}-z{Z}.jpeg`.

Each service's `upload()` writes only to the `ingests/` stage
(`{kind}/ingests/{id}.{type}`, `{kind}/thumbnails/ingests/...`,
`{kind}/captions/ingests/...`) and lets the pipeline derive
`originals` / `resizes` / `processed`.

### Resolving a URL

`Storage.get(path, scope)` (`@repositories/storage`) returns a download URL via
`getDownloadURL` — a **network RPC** with only in-flight dedup (no result
cache). Resolve a media's sources once; don't call it in a tight loop. A missing
object throws `storage/object-not-found`.

### Optional derivatives & the progressive-load pattern

An optional derivative (e.g. the `originals` copy on legacy / migrated data) can
legitimately be absent. Per the error-handling rule, **catch and log** it (never
`.catch(() => undefined)`) and fall back to a resize — see
`ImageService.getSources`. The canonical progressive display shows the small
square resize immediately, then swaps to the `originals` image once it loads
(`components/audio-display`, `ProgressiveImage`). A missing `resizes` /
`processed` file for an otherwise-healthy doc is a **genuine error**, not a
tolerable absence.

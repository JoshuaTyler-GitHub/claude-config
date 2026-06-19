# API Design Guide

The design standard for every networked API we build — HTTP/JSON endpoints,
Cloud Functions, RPC services, and the service layer in front of Firestore.

Consolidated from Google's **API Design Guide** (`cloud.google.com/apis/design`,
which redirects into the **API Improvement Proposals**, `google.aip.dev`); the
AIP source map is in §15. Examples use Protocol Buffers (the canonical IDL), but
every rule applies equally to the JSON/HTTP shape generated from it — a proto
`Book` is the same contract as the JSON body the endpoint returns.

### How to read the requirement levels

Normative keywords follow [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119):

- **MUST** / **MUST NOT** — absolute. Violating it breaks the contract.
- **SHOULD** / **SHOULD NOT** — the default; deviate only with a defensible reason.
- **MAY** — genuinely optional.

### Contents

1. [Resource-oriented design](#1-resource-oriented-design)
2. [Resource names](#2-resource-names)
3. [Standard methods](#3-standard-methods)
4. [Custom methods](#4-custom-methods)
5. [Standard fields](#5-standard-fields)
6. [Pagination](#6-pagination)
7. [Long-running operations](#7-long-running-operations)
8. [Errors](#8-errors)
9. [Naming conventions](#9-naming-conventions)
10. [Versioning](#10-versioning)
11. [Backwards compatibility](#11-backwards-compatibility)
12. [File and directory structure](#12-file-and-directory-structure)
13. [Documentation](#13-documentation)
14. [Glossary](#14-glossary)
15. [Source map (AIP index)](#15-source-map-aip-index)

---

## 1. Resource-oriented design

An API is built from individually-named **resources** (nouns) and the hierarchy
between them. A small set of standard **methods** (verbs) covers most operations;
**custom methods** cover what they cannot express.

An API **should** be a **resource hierarchy** where each node is a single
resource or a collection. A collection holds resources of one type (a publisher
owns a collection of books); resources hold fields and may own sub-resources.

**Rule:** A resource-oriented API is **not** a database schema on the wire.
Mirroring storage one-to-one couples the public surface to the backend and leaks
implementation detail callers should never depend on.

### Standard methods over custom methods

Emphasize the data model over the functionality. Most resources need only the
standard methods. Prefer, in order:

1. Standard methods (`Get`, `List`, `Create`, `Update`, `Delete`).
2. Standard batch / aggregate methods.
3. Custom methods (on a collection, a resource, or stateless).
4. Streaming methods.

Standard methods give the most uniform experience across clients; custom and
streaming methods require hand-written integrations and prevent callers from
reusing knowledge across APIs.

### Schema consistency

**Rule:** When the request to — or response from — a standard method (or a
custom method in the same service) **is** or **contains** the resource, the
resource schema **must** be identical across all of them. The `Book` returned by
`GetBook` is the same `Book` accepted by `CreateBook` and returned by `ListBooks`.

### Minimum surface

- A resource **must** support at minimum **Get** — clients must validate state
  after a `Create`, `Update`, or `Delete`.
- A resource **must** also support **List**, except for singletons where more
  than one instance is impossible.

### Standard methods at a glance

| Method | Request | Response |
| ------ | ------- | -------- |
| `Create` | Contains the resource | Is the resource |
| `Get`    | None (just the name)  | Is the resource |
| `Update` | Contains the resource | Is the resource |
| `Delete` | None (just the name)  | None (`Empty`)  |
| `List`   | None (just the parent)| Contains the resources |

### Strong consistency

For management-plane operations, completion of a mutation (synchronous, or a
finished long-running operation) **must** mean existence and all user-settable
values have reached steady state:

- After a successful `Create`, a `Get` **must** return the resource.
- After a successful `Update`, a `Get` **must** return the updated values.
- After a successful `Delete`, a `Get` **must** return `NOT_FOUND` (or the
  soft-deleted state).

This lets clients orchestrate dependent operations using method completion as
the signal to proceed.

### Statelessness

Resource-oriented APIs **must** operate over a stateless protocol: each request
is independent, and resources are directly addressable without a preceding
sequence. The server persists shared data; the client owns application state.

### Acyclic references

Resource references and the parent-child hierarchy **must** form a
[directed acyclic graph](https://en.wikipedia.org/wiki/Directed_acyclic_graph),
and an instance **must** have exactly one canonical parent. Cycles force
create-then-update dances and delete-ordering problems. (Does not apply to
relationships expressed only through `OUTPUT_ONLY` fields — those impose no
management burden on the caller.)

---

## 2. Resource names

A resource name uniquely identifies a resource and is the primary handle the API
exposes — clients use names, not tuples, self-links, or database IDs.

A name is a path that **alternates collection IDs and resource IDs**:

```
publishers/123/books/les-miserables
users/vhugo1802
```

Names follow URI-path conventions without a leading slash and are the durable,
version-free identity:

| Form | Example |
| ---- | ------- |
| Resource name (relative) | `publishers/123/books/les-miserables` |
| Full resource name | `//library.googleapis.com/publishers/123/books/les-miserables` |
| Resource URL | `https://library.googleapis.com/v1/publishers/123/books/les-miserables` |

**Rule:** Names omit the version. The full resource name persists unchanged
across API versions — which is why we identify by name, not URL.

- **Relative names** (`publishers/123/books/les-miserables`) — when the owning
  API is clear from context.
- **Full names** (`//service-name/relative-name`) — **only** when referring
  across different APIs.

### Structural rules

- Names **must** be unique within an API and use `/` to separate segments.
  Non-terminal segments **must not** contain `/`.
- Segments **should** use DNS-compatible (RFC 1123) characters; avoid uppercase,
  URL-escaped, and non-ASCII. If Unicode is unavoidable, use Normalization Form C.

### The `name` field

- A resource **must** expose a `string name` field holding its own resource
  name, annotated `IDENTIFIER`; it **should** be the first field.
- It **may** also expose the bare resource ID and a system-generated `uid` as
  separate `OUTPUT_ONLY` fields.
- Resources **must not** expose tuples, self-links, or other ID schemes. All
  ID-bearing fields are strings.

```proto
message Book {
  option (google.api.resource) = {
    type: "library.googleapis.com/Book"
    pattern: "publishers/{publisher}/books/{book}"
  };

  string name = 1 [(google.api.field_behavior) = IDENTIFIER];
}
```

### Collection identifiers

- **Must** be the plural noun (`books`, `shelves`); for non-pluralizable words
  (`info`, `moose`), use the singular.
- **Must** be concise American English in `camelCase` starting lowercase:
  `/[a-z][a-zA-Z0-9]*/`.
- **Must** be unique within a single resource name.
- Prefer the shorter form: `users/vhugo1802/events/...`, not
  `users/vhugo1802/userEvents/...`.

### Resource ID segments

User-specified IDs **should** conform to RFC 1034 (letters, digits, hyphens;
≤ 63 chars), restricted to lowercase: `^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$`.
System-generated IDs **should** document their format and length bounds.

An API **may** provide ID aliases for common lookups (e.g. `users/me`), but all
returned data **must** use the canonical resource name.

### Referencing another resource

Use a **string field holding the resource name** — never embed the other
resource's message.

- Name the field after the referenced message in `snake_case`; a leading
  adjective is fine (`dusty_book`).
- **Do not** add an `_id` suffix unless the field would otherwise be ambiguous.
- Annotate with `google.api.resource_reference`.

```proto
message Book {
  string name = 1;

  string shelf = 2 [(google.api.resource_reference) = {
    type: "library.googleapis.com/Shelf"
  }];
}
```

Embedding the full resource message is reserved for narrow cases (internal-only
APIs with tightly-coupled lifecycles, or the AIP-162 revisions pattern).
Embedding complicates lifecycles, bypasses per-resource permissions, and couples
otherwise-independent resources.

---

## 3. Standard methods

Standard methods divide into **collection methods** (`List`, `Create`) and
**resource methods** (`Get`, `Update`, `Delete`). Common conventions:

- RPC name is `<Verb><Resource>` (`GetBook`); request is `<Verb><Resource>Request`.
  No response wrapper for `Get`/`Create`/`Update` — the response **is** the resource.
- The resource-name field is `name`; the parent-collection field is `parent`.
- Each method **should** carry a `google.api.method_signature` annotation.

### 3.1 Get

```proto
rpc GetBook(GetBookRequest) returns (Book) {
  option (google.api.http) = {
    get: "/v1/{name=publishers/*/books/*}"
  };
  option (google.api.method_signature) = "name";
}

message GetBookRequest {
  string name = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference) = { type: "library.googleapis.com/Book" }
  ];
}
```

- HTTP verb **must** be `GET`; **must not** have a `body`.
- `name` **must** be the only path variable, **should** be `REQUIRED`; other
  parameters map to the query string.
- The request **must not** contain other required fields.
- `Get` is inherently **idempotent** and **must** have no side effects.
- Errors: `NOT_FOUND` when absent; `PERMISSION_DENIED` when the caller lacks
  access (checked first — see §8).

### 3.2 List

```proto
rpc ListBooks(ListBooksRequest) returns (ListBooksResponse) {
  option (google.api.http) = {
    get: "/v1/{parent=publishers/*}/books"
  };
  option (google.api.method_signature) = "parent";
}

message ListBooksRequest {
  string parent = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference) = { child_type: "library.googleapis.com/Book" }
  ];
  int32 page_size = 2;
  string page_token = 3;
}

message ListBooksResponse {
  repeated Book books = 1;
  string next_page_token = 2;
}
```

- HTTP verb **must** be `GET`; the collection ID (`books`) **must** be a literal
  in the path; `parent` **must** be the only path variable (omit for top-level
  resources), **should** be `REQUIRED`.
- The response **must** carry one repeated field of fully-populated resources
  plus `next_page_token` (§6).
- It **may** include `int32 total_size` (post-filter count; may be an estimate).
- `List` **must** have no side effects and return consistent results for all
  authorized callers (search methods relax this).

**Optional fields, added only on established need** (removing either later is breaking):

- `string filter` — filtering expression.
- `string order_by` — comma-separated fields, default ascending, `" desc"`
  suffix for descending, `.` for subfields: `"author.name desc, title"`. Uses
  each field type's natural comparator.
- `bool show_deleted` — include soft-deleted resources (excluded by default).

### 3.3 Create

```proto
rpc CreateBook(CreateBookRequest) returns (Book) {
  option (google.api.http) = {
    post: "/v1/{parent=publishers/*}/books"
    body: "book"
  };
  option (google.api.method_signature) = "parent,book";
}

message CreateBookRequest {
  string parent = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference) = { child_type: "library.googleapis.com/Book" }
  ];
  string book_id = 2;
  Book book = 3 [(google.api.field_behavior) = REQUIRED];
}
```

- HTTP verb **must** be `POST` to the parent collection; `body` **must** map to
  the resource field; the response **must** be the fully-populated resource.
- `parent` **must** exist (except top-level resources); the resource field
  **must** be present.
- `{resource}_id` sets the final name segment. Management-plane resources
  **must** let the user specify the ID; data-plane resources **should** (unless
  identical records are allowed, or the resource is never exposed declaratively).
  Mark it `OPTIONAL` to allow server-generated IDs.

| ID source | Resulting name |
| --------- | -------------- |
| User-specified | `publishers/lacroix/books/les-miserables` |
| Server-generated | `publishers/012345678-abcd/books/12341234-5678-abcd` |

- Errors: a duplicate name **must** return `ALREADY_EXISTS` (or
  `PERMISSION_DENIED` if the caller can't see the existing resource). For
  idempotent creates, accept a `request_id` (§5).

### 3.4 Update

```proto
rpc UpdateBook(UpdateBookRequest) returns (Book) {
  option (google.api.http) = {
    patch: "/v1/{book.name=publishers/*/books/*}"
    body: "book"
  };
  option (google.api.method_signature) = "book,update_mask";
}

message UpdateBookRequest {
  Book book = 1 [(google.api.field_behavior) = REQUIRED];
  google.protobuf.FieldMask update_mask = 2;
}
```

- **Use `PATCH`, not `PUT`.** Google APIs do not support `PUT`: with `PUT`,
  adding a field later is breaking — an old client omitting it would erase it.
  `PATCH` updates only the named fields.
- The resource field maps to the body and **must** carry the `name`. The field
  mask **must** be a `google.protobuf.FieldMask` named `update_mask` and **must**
  be optional — omitting it implies "all populated fields." It **should** support
  the `*` wildcard for full replacement (the closest thing to `PUT`).
- **Side effects:** `Update` **should not** trigger them — use a custom method.
  State fields **must not** be directly writable. The response **must** include
  all updated fields (unless input-only or a justified partial response).
- **`allow_missing` (upsert):** when `true`, a missing resource is created (mask
  ignored, all fields applied); a fully-matching existing resource is returned
  unchanged; otherwise the named fields are updated. The caller still **must**
  hold update permission.
- **`etag`:** when provided it **must** match the server's value; a mismatch
  **must** fail with `ABORTED` (HTTP 409).
- Errors: `NOT_FOUND` unless `allow_missing` is set; `ABORTED` on etag mismatch.

### 3.5 Delete

```proto
rpc DeleteBook(DeleteBookRequest) returns (google.protobuf.Empty) {
  option (google.api.http) = {
    delete: "/v1/{name=publishers/*/books/*}"
  };
  option (google.api.method_signature) = "name";
}

message DeleteBookRequest {
  string name = 1 [
    (google.api.field_behavior) = REQUIRED,
    (google.api.resource_reference) = { type: "library.googleapis.com/Book" }
  ];
}
```

- HTTP verb **must** be `DELETE`; `name` is the only path variable; no `body`.
- The response **should** be `google.protobuf.Empty`:

| Scenario | Response type |
| -------- | ------------- |
| Standard delete | `google.protobuf.Empty` |
| Soft delete | The resource |
| Long-running delete | `google.longrunning.Operation` (`response_type: "google.protobuf.Empty"`) |

Optional behaviors:

- **`bool force` (cascade):** delete **must** fail with `FAILED_PRECONDITION` if
  children exist and `force` is unset/false. Singletons **must** be deletable
  without `force` (their lifecycle is tied to the parent).
- **`string etag`:** mismatch **must** fail with `ABORTED`. Declarative-friendly
  resources **must** provide it.
- **`bool allow_missing`:** when `true`, deleting a missing resource succeeds as
  a no-op (etag ignored). Declarative-friendly resources **should** expose it.

Errors (permission checked before existence): `PERMISSION_DENIED` (403),
`NOT_FOUND` (404), `FAILED_PRECONDITION` (400), `ABORTED` (409).

---

## 4. Custom methods

Custom methods cover what standard methods cannot cleanly express (transactions,
import/export, analysis, `Move`, `Cancel`, `BatchGet`, …). **Prefer standard
methods** wherever possible — their semantics are consistent and automatable.

A custom method does **not** introduce a new HTTP verb. It uses a normal verb
(usually `POST`) and names the custom verb after a **colon** in the URI:

```proto
rpc ArchiveBook(ArchiveBookRequest) returns (ArchiveBookResponse) {
  option (google.api.http) = {
    post: "/v1/{name=publishers/*/books/*}:archive"
    body: "*"
  };
}
```

### Rules

- **Naming:** `<Verb><Noun>` in `UpperCamelCase`; the URI verb after the colon is
  the same verb in `camelCase`. No prepositions (`For`, `With`); don't reuse a
  standard-method verb; use a `LongRunning` suffix rather than `Async`.
- **HTTP verb:** `GET` **must** be used for retrieval with no side effects;
  `POST` **must** be used for anything with side effects (and any billable
  stateless method).
- **Messages:** request **should** be `<Rpc>Request`, response `<Rpc>Response`.
  When acting on a specific resource it **may** return that resource.

**Resource-based** — variable **must** be `name` and the only path variable;
`body` **should** be `"*"`:

```proto
post: "/v1/{name=publishers/*/books/*}:archive"
```

**Collection-based** — variable **must** be `parent`; the collection key is a literal:

```proto
post: "/v1/{parent=publishers/*}/books:sort"
```

**Stateless** (not attached to a resource) — put both verb and noun after the
colon; avoid faux collection keys:

```proto
post: "/v1/{project=projects/*}:translateText"
```

**Rule:** Declarative-friendly resources **should not** use custom methods,
except inherently imperative operations like `Move` or `Rename` that no
declarative tool would expect to manage.

---

## 5. Standard fields

Reuse these names and types whenever the concept applies — consistency lets
clients and tooling carry knowledge from one resource to the next.

### Names and identifiers

| Field | Type | Notes |
| ----- | ---- | ----- |
| `name` | `string` | The resource name. First field. |
| `parent` | `string` | Parent resource name (List/Create requests). |
| `uid` | `string`, `OUTPUT_ONLY` | System-assigned unique ID, UUID4. |
| `display_name` | `string` | Mutable, user-set label (≤ 63 chars, not unique). |
| `title` | `string` | Formal/official name of an entity (e.g. a company name). |
| `given_name` / `family_name` | `string` | A person's names — not `first_name` / `last_name`. |

### Timestamps (`google.protobuf.Timestamp`)

| Field | Notes |
| ----- | ----- |
| `create_time` | `OUTPUT_ONLY`. When created. |
| `update_time` | `OUTPUT_ONLY`. Most recent update. |
| `delete_time` | `OUTPUT_ONLY`. When soft-deleted. |
| `expire_time` | When the resource/attribute is no longer valid. |
| `purge_time` | When a soft-deleted resource will be permanently purged. |

### Other well-known fields

| Field | Type | Notes |
| ----- | ---- | ----- |
| `annotations` | `map<string, string>` | Small arbitrary client data (Kubernetes-style limits). |
| `etag` | `string` | Optimistic-concurrency token; mismatch → `ABORTED`. |
| `request_id` | `string` | Idempotency token for create/mutating calls. |
| `validate_only` | `bool` | Dry-run: validate without applying. |
| `filter` | `string` | List filtering expression. |
| `order_by` | `string` | List sort order. |
| `show_deleted` | `bool` | Include soft-deleted resources in `List`. |
| `page_size` / `page_token` / `next_page_token` | `int32` / `string` | Pagination (§6). |
| `ip_address` (or `*_ip_address`) | `string` | IP address with a documented format (IPV4 / IPV6 / IPV4_OR_IPV6). |

**Rule:** A field that semantically matches one of these **must** use the
standard name and type. Don't invent `created_at` for `create_time`, or `label`
for `display_name`.

---

## 6. Pagination

**Rule:** Any method returning a collection **must** support pagination from day
one. Adding it later is breaking — existing clients expect the full collection,
and client-library signatures change.

```proto
message ListBooksRequest {
  string parent = 1 [(google.api.field_behavior) = REQUIRED];
  int32 page_size = 2;
  string page_token = 3;
}

message ListBooksResponse {
  repeated Book books = 1;
  string next_page_token = 2;
}
```

### Request

- **`page_size` (`int32`)** — caller's maximum. **Must not** be required;
  **must** default sensibly when 0/unspecified. Over-max values **should** be
  coerced down; negative values **must** return `INVALID_ARGUMENT`. The server
  **may** return fewer than requested, even mid-collection.
- **`page_token` (`string`)** — opaque continuation token from a previous
  response. **Must not** be required. All **other** parameters **must** match the
  original request, or the server **should** return `INVALID_ARGUMENT`.

### Response

- The repeated results field **should** be field number 1.
- **`next_page_token` (`string`)** — **must** be empty exactly when the end is
  reached (the *only* end-of-collection signal), and **must** be set otherwise.
- **`total_size`** — **may** be provided; **may** be an estimate (document it).

### Page tokens

- **Must** be opaque, URL-safe strings the caller **must not** parse.
- **Must** carry only continuation data — never authorization info. A token
  **may** base64-encode a serialized proto for non-sensitive cursors, and **may**
  expire after a reasonable period (≈ 3 days).

A `skip` (offset) field is permitted: it **must** count individual resources
(not pages); an unfulfillable skip **must** return `200 OK` with empty results
and no `next_page_token`.

---

## 7. Long-running operations

When a method takes meaningful time (rule of thumb: **> ~10 seconds**), it
**must not** block. It returns a `google.longrunning.Operation` the caller polls.

```proto
rpc CreateBook(CreateBookRequest) returns (google.longrunning.Operation) {
  option (google.api.http) = {
    post: "/v1/{parent=publishers/*}/books"
    body: "book"
  };
  option (google.longrunning.operation_info) = {
    response_type: "Book"
    metadata_type: "OperationMetadata"
  };
}
```

- The `operation_info` annotation **must** declare `response_type` (the eventual
  result; not `Empty` unless genuinely never needed) and `metadata_type`
  (progress info; same caveat). Both types **must** be defined in this file or an
  imported one.
- An API returning `Operation` **must** implement the standard
  `google.longrunning.Operations` service and **must not** define its own LRO
  interface. That service provides `GetOperation`, `ListOperations`,
  `DeleteOperation`, `CancelOperation`, `WaitOperation`.
- `Create`, `Update`, `Delete` **may** return an `Operation`; `response_type`
  **must** match what the synchronous method would return. Declarative-friendly
  resources **should** use LROs for these.
- The result **must not** be streaming, and the `Operation` proto **must not** be
  copied/redefined.

### Errors and lifecycle

- Failures **before** the operation starts return a normal error response (§8).
- Failures **during** execution go in `Operation.error` (`google.rpc.Status`);
  non-terminal issues **may** appear in metadata.
- Concurrency: a resource **may** queue operations, **may** reject a concurrent
  one with `ABORTED`, or (declaratively) **may** preempt the prior operation and
  mark it `ABORTED`.
- Completed operations **should** remain queryable for ≈ 30 days.
- Changing `response_type` or `metadata_type` is a **breaking change**.

---

## 8. Errors

Every error **must** be a `google.rpc.Status` with three fields:

- **`code`** — a value from the canonical `google.rpc.Code` enum.
- **`message`** — developer-facing, human-readable debug string, in English,
  brief but actionable. **Never** put PII or raw stack traces here.
- **`details`** — a list of `google.protobuf.Any` payloads, each type included
  **at most once**.

Over HTTP/JSON:

```json
{
  "error": {
    "code": 404,
    "message": "Book \"les-miserables\" not found.",
    "status": "NOT_FOUND",
    "details": [ /* ... */ ]
  }
}
```

### Canonical codes → HTTP status

| Code | HTTP | Meaning |
| ---- | ---- | ------- |
| `OK` | 200 | Success. |
| `INVALID_ARGUMENT` | 400 | Malformed request, independent of state. |
| `FAILED_PRECONDITION` | 400 | Request invalid in the current system state. |
| `OUT_OF_RANGE` | 400 | Past the valid range. |
| `UNAUTHENTICATED` | 401 | Missing/invalid credentials. |
| `PERMISSION_DENIED` | 403 | Authenticated but not authorized. |
| `NOT_FOUND` | 404 | Resource does not exist. |
| `ABORTED` | 409 | Concurrency conflict (e.g. etag mismatch). |
| `ALREADY_EXISTS` | 409 | Resource the client tried to create already exists. |
| `RESOURCE_EXHAUSTED` | 429 | Quota / rate limit. |
| `CANCELLED` | 499 | Client cancelled. |
| `INTERNAL` | 500 | Server-side invariant broken. |
| `UNIMPLEMENTED` | 501 | Method not implemented. |
| `UNAVAILABLE` | 503 | Transient; client may retry with backoff. |
| `DEADLINE_EXCEEDED` | 504 | Deadline passed before completion. |

**Rule:** Check permission **before** existence. If the caller lacks permission,
return `PERMISSION_DENIED` whether or not the resource exists — only return
`NOT_FOUND` to a caller who *would* be allowed to see it. This avoids leaking
resource existence through error codes.

### Error details

- **`ErrorInfo`** **must** be on every error:
  - `reason` — `UPPER_SNAKE_CASE`, ≤ 63 chars (`NO_STOCK`, `CPU_AVAILABILITY`).
  - `domain` — globally unique, usually the service name (`pubsub.googleapis.com`).
    The `(reason, domain)` pair **must** identify an error consistently.
  - `metadata` — dynamic key/value context. Any request-specific value in
    `message` **must** also be in `metadata`, so clients read it without parsing prose.
- **`BadRequest`** — field-level validation failures.
- **`PreconditionFailure`** — unmet preconditions.
- **`LocalizedMessage`** — user-facing message in a BCP-47 locale; use when
  `message` itself can't change for compatibility.
- **`Help`** — links to docs (`description` + absolute `url`).

### Client and stability guidance

- Clients **should** branch on `code` and on `ErrorInfo.reason` + `domain`, read
  context from `metadata`, show `LocalizedMessage`, and follow `Help`.
- If an RPC has **always** returned `ErrorInfo`, its `message` **may** evolve;
  otherwise `message` **must** stay stable (improve wording via
  `LocalizedMessage`). New `metadata` keys **may** be added; existing ones
  **must** be preserved.
- APIs **should not** support partial errors — they push complexity onto every
  client. The exception is bulk work, surfaced through a long-running operation.

---

## 9. Naming conventions

Names **must** be simple, intuitive, and consistent — clear to developers for
whom English is a second language. Use a small, familiar vocabulary.

### Case

| Element | Case |
| ------- | ---- |
| Message / enum / service (`service`) | `UpperCamelCase` |
| RPC method | `UpperCamelCase` (`VerbNoun`) |
| Field (proto) | `snake_case` |
| Field (JSON) | `camelCase` (generated from the proto name) |
| Enum value | `UPPER_SNAKE_CASE` |
| Collection ID (in resource names) | `camelCase`, plural |

### Rules

- Use correct **American English** (`license`, not `licence`) and intuitive words
  (`delete`, not `erase`). Use the same name for the same concept across APIs;
  never overload one name for two concepts.
- **Avoid vague names** — `instance`, `info`, `service` are ambiguous. A name
  **must** clearly describe its concept and distinguish it from related ones.
- **Avoid language keywords** (`File`, `class`, …); they need extra review and
  can collide in generated code. Disambiguate a `service` name with an `Api` or
  `Service` suffix when it conflicts.
- **Message names** stay short; drop redundant words and adjectives (keep an
  adjective only when a contrasting message exists). They **should not** contain
  prepositions (`With`, `For`) — model that as a field instead.
- Method names follow `VerbNoun`. Standard methods (`Get`, `List`, `Create`,
  `Update`, `Delete`) and their batch variants are reserved; everything else is a
  custom method (§4).
- Acronyms **should not** be used unless dominant in colloquial use. Abbreviate
  only well-understood terms (`API`, `config`, `id`).

---

## 10. Versioning

Every API **must** declare a **major version** in both the protobuf package and
the REST URI path: `v1`, `v2`. Only the major number — never `v1.0` or `v1.4.2`.
Minor/patch-equivalent changes roll into the major version in place, and so
**must** be backwards-compatible (§11).

### Cross-version rules

- A new major version **must not** depend on a previous major version of the same API.
- Multiple major versions **must** run side-by-side in one client for a
  reasonable transition window.
- A retired version **must** go through a well-communicated deprecation period.

### Stability channels (recommended)

Up to three long-lived channels per major version, by suffix:

| Channel | Form | Notes |
| ------- | ---- | ----- |
| Stable | `v1` | No suffix. |
| Beta | `v1beta` | Superset of stable. |
| Alpha | `v1alpha` | Superset of beta. |

- Functionality nests: beta ⊇ stable, alpha ⊇ beta.
- A feature **may** be deprecated in any channel but **must not** graduate while
  deprecated (alpha→beta or beta→stable). Deprecated beta features are removable
  after ≥ 180 days; alpha is removable without notice.

(Two older alternatives exist — *release-based* `v1beta1`/`v1alpha5`, and
*visibility-based* labels like `PREVIEW`/`INTERNAL` — but channel-based
versioning is preferred for new services.)

A genuinely incompatible change goes in a **new major version**.

---

## 11. Backwards compatibility

An API is a contract. Within a major version, existing client code **must not**
break, and old clients **must** keep working against newer servers. Three facets:

- **Source compatibility** — existing code still compiles against newer client libraries.
- **Wire compatibility** — existing code still talks to newer servers.
- **Semantic compatibility** — existing code still gets the expected behavior.

A change failing any of these is **breaking** and **must** wait for a new major
version (§10).

### Quick reference

| Change | Compatible? | Notes |
| ------ | ----------- | ----- |
| Add an optional field | ✅ | Default behavior **must** match pre-existing semantics. |
| Add a method / message / service | ✅ | Old code unaware of it **must** behave identically. |
| Add an enum value | ✅ | Free for request-only enums; document client handling for response/resource enums. |
| Continue populating a server-set field | ✅ (required) | A field the server used to populate **must** keep being populated. |
| Add a **required** field | ❌ | Breaks every existing caller. |
| Remove or rename anything | ❌ | Rename = remove + add. Add the new one, keep the old. |
| Change a field/message **type** | ❌ | Breaks generated code even when wire-compatible. |
| Move a field between files | ❌ | Breaks imports/includes (C++, Python). |
| Move a field into/out of a `oneof` | ❌ | Breaks generated Go stubs. |
| Change a resource **name format** | ❌ | Affects v1↔v2 interop; the valid name set **should not** change. |
| Change a static **default value** | ❌ | Semantically changes behavior. |
| Start serializing previously-omitted defaults | ❌ | Changes the wire shape clients parse. |
| Change a field's **format/algorithm** (even `OUTPUT_ONLY`) | ❌ | e.g. IPv4 → IPv6; clients parse/hash/store these. |
| Add pagination to an existing list | ❌ | Old clients expect the full collection (§6). |

**Why string lengths/formats matter:** callers store resource names in
fixed-width columns and URLs, and parse/hash field values. Quietly lengthening a
name or changing a value's construction breaks those systems even though the
proto looks unchanged.

---

## 12. File and directory structure

- APIs **must** use **proto3** syntax exclusively.
- Each API **must** live in a single package ending in its version component, and
  the directory **must** mirror the package:

  ```proto
  syntax = "proto3";
  package google.cloud.translation.v3;   // → google/cloud/translation/v3/
  ```

- **File names** use `snake_case` and **must not** contain the version
  (`translation.proto`, never `v3.proto`). There **should** be an obvious entry
  file named after the API; multiple services **may** have separate entry files.
  Filenames become client-library module names, so keep them descriptive and
  keyword-free.

### Element order within a `.proto` file

Separate each block with a blank line:

1. License / copyright notice.
2. `syntax`.
3. `package`.
4. `import` statements, alphabetically ordered.
5. File-level `option` statements.
6. `service` definitions (grouped by resource; standard methods before custom).
7. Resource `message`s (parents before children).
8. RPC request/response messages (matching method order; request before response).
9. Remaining messages.
10. Top-level enums.

### Packaging options

- **Java:** `java_package` **must** be set (proto package with TLD prefix, e.g.
  `com.google.example.v1`); `java_multiple_files` **must** be `true`;
  `java_outer_classname` **must** be the filename in PascalCase + `Proto` (e.g.
  `LibraryProto`).
- **Other languages:** set package options consistently across all files or none.
  C#/Ruby/PHP **must** specify PascalCase compound names; `go_package`'s terminal
  segment is suffixed `pb`. Options **should** be alphabetically ordered.

---

## 13. Documentation

Every API element — service, method, message, field, enum, enum value — **must**
have a leading comment.

- **Voice:** grammatically correct American English. A method/field comment's
  first sentence omits the subject and uses third-person present:
  *"Creates a book under the given publisher."* Avoid jargon, slang, metaphors,
  and pop-culture references that won't translate.
- **Cover the contract:** what it is and how it's used; success/failure behavior
  and idempotency; units; side effects; common errors; accepted input formats and
  ranges (inclusive vs. exclusive); string constraints (length, charset,
  truncate-vs-error); presence conditions and defaults.
- **Format:** CommonMark only. **No headings, no tables** (tooling can't render
  them), no raw HTML, no ASCII-art (link to an image). Wrap field/method names
  and literals like `true` in backticks. Links **must** be absolute (including
  `https`) and **must not** assume a particular doc host.
- **Cross-references:** `[Book][google.example.v1.Book]`,
  `[Sci-Fi genre][Genre.GENRE_SCI_FI]`, or `[Book][]`. Reference the original
  definition — containing field names **must not** be used in references.
- **Comments are leading only** — not trailing, not detached (both leading and
  trailing on one element commonly leaks internal notes). Internal-only content
  is wrapped in `(--` … `--)`.
- **Deprecation:** set the `deprecated` option to `true` **and** begin the first
  comment line with `Deprecated: `, pointing to the replacement.

---

## 14. Glossary

| Term | Definition |
| ---- | ---------- |
| **API** | Application programming interface — a local interface (client library) or a Network API. |
| **API backend** | Servers and infrastructure implementing an API service's business logic. |
| **API consumer** | The entity consuming an API service (for Google APIs, typically a project). |
| **API definition** | The definition of an API, usually a Protocol Buffer `service`. One definition can back many services. |
| **API frontend** | Servers/infrastructure providing common functions (load balancing, auth) across services. |
| **API interface** | The IDL element grouping methods — a Protocol Buffers `service`. |
| **API method** | A single operation, typically an `rpc`. |
| **API producer** | The entity that produces an API service (typically the owning team). |
| **API product** | An API service plus its ToS, docs, and client libraries, presented to customers. |
| **API service** | A deployed implementation of one or more APIs, on one or more network addresses. |
| **API service definition** | The combination of `.proto` definitions and `.yaml` service configs. |
| **API service endpoint** | A network address that handles incoming API requests. |
| **API service name** | The logical identifier of a service (RFC 1035 DNS-compatible). |
| **API title** | The user-facing product title (e.g. "Cloud Pub/Sub API"). |
| **API request** | A single method invocation — the usual unit for billing, logging, monitoring, rate limiting. |
| **API version** | The version of an API or co-defined group of APIs. |
| **Client** | A program calling an API, or a generic tool (e.g. a CLI) that exposes it. |
| **Declarative clients** | Clients that consume a desired-state representation of resources and act to achieve it (also "infrastructure as code"). |
| **Network API** | An API operating across a network via protocols such as HTTP. |
| **User** | A human using an API directly (e.g. via cURL). |
| **Collection** | A grouping of resources of the same type, named by a plural collection ID. |
| **Resource** | An individually-named entity with fields, possibly owning sub-resources. |
| **Resource name** | The unique path identifying a resource (`publishers/123/books/456`). |
| **Standard methods** | `Get`, `List`, `Create`, `Update`, `Delete`. |
| **Custom method** | Any non-standard method, expressed with a `:verb` suffix in the URI (§4). |
| **Management plane** | Operations that manage resources (create/configure); strong-consistency guarantees apply. |
| **Data plane** | High-volume operations on the data a resource holds. |

---

## 15. Source map (AIP index)

Consolidates the following AIPs. Consult the source for edge cases not covered here.

| § | Topic | AIP |
| - | ----- | --- |
| 1 | Resource-oriented design | [AIP-121](https://google.aip.dev/121) |
| 2 | Resource names | [AIP-122](https://google.aip.dev/122) |
| 3 | Methods overview | [AIP-130](https://google.aip.dev/130) |
| 3.1 | Get | [AIP-131](https://google.aip.dev/131) |
| 3.2 | List | [AIP-132](https://google.aip.dev/132) |
| 3.3 | Create | [AIP-133](https://google.aip.dev/133) |
| 3.4 | Update | [AIP-134](https://google.aip.dev/134) |
| 3.5 | Delete | [AIP-135](https://google.aip.dev/135) |
| 4 | Custom methods | [AIP-136](https://google.aip.dev/136) |
| 5 | Standard fields | [AIP-148](https://google.aip.dev/148) |
| 6 | Pagination | [AIP-158](https://google.aip.dev/158) |
| 7 | Long-running operations | [AIP-151](https://google.aip.dev/151) |
| 8 | Errors | [AIP-193](https://google.aip.dev/193) |
| 9 | Naming conventions | [AIP-190](https://google.aip.dev/190) |
| 10 | Versioning | [AIP-185](https://google.aip.dev/185) |
| 11 | Backwards compatibility | [AIP-180](https://google.aip.dev/180) |
| 12 | File and directory structure | [AIP-191](https://google.aip.dev/191) |
| 13 | Documentation | [AIP-192](https://google.aip.dev/192) |
| 14 | Glossary | [AIP-9](https://google.aip.dev/9) |

Related AIPs worth reading when relevant: soft delete/undelete
([AIP-164](https://google.aip.dev/164)), bulk delete by filter
([AIP-165](https://google.aip.dev/165)), etags ([AIP-154](https://google.aip.dev/154)),
request idempotency ([AIP-155](https://google.aip.dev/155)), list filtering
([AIP-160](https://google.aip.dev/160)), declarative-friendly interfaces
([AIP-128](https://google.aip.dev/128)), field behavior
([AIP-203](https://google.aip.dev/203)), and singletons
([AIP-156](https://google.aip.dev/156)).

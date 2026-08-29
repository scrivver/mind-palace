# Contract: Engram Folder Listing API

**Component owner**: Engram (`engram/backend/internal/api/`)

**Consumers**: Mind Palace Flutter client (`app/`)

**Status**: Proposed for feature 009

Both changes are additive. A client that sends neither new parameter observes the current behavior
and the current response shape.

## Shared parameters

| Parameter | Values | Default | Meaning |
|---|---|---|---|
| `path` | display-path prefix | `""` (root) | Directory to list. Normalized server-side. |
| `scope` | `all`, `folder` | `all` | `folder` restricts to direct children of `path`. |

### Path normalization

The server normalizes `path` by converting `\` to `/`, splitting on `/`, trimming each segment, and
dropping segments that are empty, `.`, or `..`. Segments are rejoined with `/`. This mirrors
`GalleryFolderPath._normalizePath` in `app/lib/widgets/gallery/gallery_view_model.dart` exactly, so
client and server agree on what a path means.

A `scope` value other than `all` or `folder` is a `400`. An unnormalizable `path` normalizes to the
root rather than erroring.

### Prefix matching

The normalized path, when non-empty, becomes the prefix `<path>/`. Matching escapes `\`, `%`, and
`_` and uses `ESCAPE '\'`, so a folder named `my_docs` matches literally.

### Filters

`q`, `tag`, `type`, `from`, `to`, `status`, and `device` behave identically on both endpoints and
are applied before folder derivation, so counts always agree with contents.

## `GET /api/files`

Existing endpoint. Response remains a bare JSON array of file objects — unchanged.

With `scope=folder`, results are restricted to files whose display path is a **direct** child of
`path`: the prefix matches and the remainder contains no further `/`. Pagination via `limit` and
`offset` is unchanged.

With `scope=all` (or omitted), `path` is ignored and behavior is exactly as today.

```
GET /api/files?scope=folder&path=docs&limit=50&offset=0
```

```json
[
  {
    "id": "…",
    "filename": "docs/myfile.pdf",
    "file_path": "files/alice/2026/07/docs/myfile.pdf",
    "…": "…"
  }
]
```

## `GET /api/folders`

New endpoint. Returns every immediate subfolder of `path` for the authenticated owner.

The response is complete and **not paginated**: a directory level holds far fewer folders than
files, and a partial folder list is precisely the defect this feature exists to fix.

```
GET /api/folders?path=
```

```json
[
  { "name": "docs",     "path": "docs",     "file_count": 12 },
  { "name": "invoices", "path": "invoices", "file_count": 3 }
]
```

`file_count` is **recursive** — every file beneath `path/name`, at any depth, matching the active
filters. This preserves the count semantics the client previously computed in `visibleFoldersFor`.

Ordering is case-insensitive ascending by `name`, matching the previous client-side sort.

An empty directory returns `[]`, not `404`.

## Authentication

Unchanged. Both endpoints sit behind the existing `protected` mux and its `MultiAuthenticator`
(`engram/backend/internal/auth/multi.go:29`), which accepts a Reliquary-issued JWT or an OIDC access
token. All queries are owner-scoped by the authenticated username.

## Client behavior

- Folder view: request `GET /api/folders?path=<p>` and `GET /api/files?scope=folder&path=<p>`.
- All-files view: request `GET /api/files` unchanged, with no `scope` or `path`.
- Active search: force `scope=all` and render no folder rows, preserving today's behavior where
  search flattens the tree.

## Non-goals

- `total_count` on `GET /api/files`. Deferred; `hasMore` continues to be inferred from page size.
- `status=all`. Deferred; pending and failed files remain hidden by default.
- Folder listing in Reliquary. Its manifest has no display path and no prefix query.

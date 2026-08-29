# Gallery UI Contract

This contract describes Phase 1 user-visible behavior and `/vault` route state for the gallery view modes. Phase 1 does not change backend APIs. Phase 2 backend API targets are documented separately in this file as a future contract direction.

## Route Query Parameters

Base route: `/vault`

| Parameter | Values | Default | Meaning |
|-----------|--------|---------|---------|
| `q` | string | empty | Existing search query |
| `type` | `image`, `video`, `audio`, `pdf`, `other` | all types | Existing file-type filter |
| `tags` | comma-separated tag names | empty | Existing selected tag filters |
| `view` | `grid`, `list` | `grid` | Gallery layout mode |
| `group` | `folders`, `all` | implementation default | Directory grouping mode |
| `path` | URL-encoded normalized path | empty | Current folder path when `group=folders` |

## Route Behavior

- The gallery must parse all existing search/filter parameters exactly as before.
- Unknown `view` values fall back to `grid`.
- Unknown `group` values fall back to the implementation default.
- `path` is only meaningful in folder mode; all-files mode may preserve it in the URL only if doing so does not confuse navigation.
- Generated `/vault` URLs should omit default values where practical, but must preserve non-default search/filter/view/group/path state.

## Folder Mode Behavior

- Root folder path is the empty string.
- Folder entries are derived from normalized `EngramFile.filePath`.
- Only immediate child folders and direct child files for the current folder are visible when search is empty.
- Opening a folder updates `path`.
- Going up removes one path segment.
- If search is active, matching files are shown globally across directories and folder rows may be hidden.

## All-Files Mode Behavior

- Folder entries are hidden.
- All matching files are visible regardless of directory.
- Each file row/card must expose directory context when the filename alone could be ambiguous, especially in list mode.
- Opening a file uses the existing file detail route `/file/:fileId`.

## View Mode Behavior

- Grid mode uses card-style file/folder presentation.
- List mode uses compact rows.
- Changing view mode must preserve grouping mode, current folder, search query, file-type filter, tag filters, loaded files, and scroll behavior as much as practical.

## Infinite Scroll Behavior

- The gallery loads the first page for the active search/filter/sort state.
- When the user scrolls near the bottom, the gallery requests the next page automatically.
- Existing visible items remain interactive while the next page loads.
- A bottom loading indicator is shown during load-more requests.
- Refresh, search, filter, sort, grouping, or folder path changes reset pagination to the first page.
- Phase 1 uses existing Engram `offset`/`limit` semantics and may infer `hasMore` from page size.
- Phase 1 must not add manual next/previous page buttons.

## Phase 2 Backend API Direction

Target all-files/search endpoint shape:

```text
GET /api/files?limit=50&cursor=...&q=...&type=...&tag=...
```

```json
{
  "items": [],
  "next_cursor": "opaque-or-null",
  "has_more": false
}
```

Target folder browse endpoint shape:

```text
GET /api/files/browse?path=2026/06&limit=50&cursor=...
```

```json
{
  "folders": [],
  "files": [],
  "next_cursor": "opaque-or-null",
  "has_more": false
}
```

- Cursor values are opaque to clients.
- Cursor semantics must include the active sort and a stable tiebreaker server-side.
- Existing offset/limit behavior should remain available until the Flutter client has migrated.

## Backend Filename Follow-Up

Folder grouping should ultimately be derived from a user-facing relative path,
not from the storage object key. The current frontend can fall back to
`file_path`, but that is a temporary compatibility behavior because
`file_path` includes storage layout such as owner/date prefixes.

Reliquary should publish the uploaded relative path as the canonical display
filename/path in its file event when a folder upload provides one. For example,
an upload named `docs/myfile.pdf` should reach Engram as:

```json
{
  "filename": "docs/myfile.pdf",
  "file_path": "files/alice/2026/07/docs/myfile.pdf"
}
```

Engram should then return that user-facing value to the Flutter gallery so the
frontend can derive folder `docs` without inspecting `file_path`.

## Non-Goals

- No new Engram API endpoints in Phase 1.
- No Reliquary storage contract changes.
- No persisted user preference store.
- No display of empty directories without files.

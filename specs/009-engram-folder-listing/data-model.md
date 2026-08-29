# Data Model: Engram Folder Listing

**Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

## Existing entities

### `files` (PostgreSQL, Engram)

Unchanged in shape. Columns relevant to this feature:

| Column | Role in this feature |
|---|---|
| `filename` | User-facing display path, e.g. `docs/myfile.pdf`. Sole input to folder grouping. |
| `file_path` | Storage identity. Never an input to folder grouping. |
| `owner` | Scopes every query. |
| `status` | Filters every query; defaults to `ready`. |

Storage identity remains `(storage_type, file_path)` with the unique index from migration 004.

## Derived entity

### Folder

Computed per request; never stored.

| Field | Type | Description |
|---|---|---|
| `name` | string | The single path segment, e.g. `docs`. |
| `path` | string | Full display-path prefix, e.g. `projects/docs`. |
| `file_count` | int | Recursive count of matching files beneath `path`. |

Go: `model.Folder` in `engram/backend/internal/model/file.go`.
Dart: the existing `FolderEntry` in `app/lib/widgets/gallery/gallery_view_model.dart`, gaining a
`fromJson` constructor that maps `file_count` onto its existing `count` field. `FolderTile` and
`FolderRow` consume `FolderEntry` directly and stay untouched.

## Observed database state (2026-08-28)

The diagnostic in [quickstart.md](./quickstart.md) step 0 was run against the local database before
this design was finalized:

| Metric | Count |
|---|---|
| total rows (`storage_type='s3'`) | 20 |
| `legacy_layout` (`file_path` outside `files/`) | 0 |
| `backfill_targets` | 0 |
| `filename_is_key` | 0 |
| `has_display_path` (`filename` contains `/`) | 0 |
| rows not `status='ready'` | 0 |

Every key is `files/akadmin/2026/{06,07}/<basename>` and every `filename` is a bare basename,
consistent with a dataset containing no folder uploads.

**Consequence**: there is no legacy data to repair. Migration 005 carries no backfill.

## Migration 005: `folder_listing_index`

### Up

```sql
-- Prefix matching support for folder listing.
--
-- This deployment initialises PostgreSQL with `initdb --no-locale`
-- (infra/postgresql.nix), so the database collation is C and a plain btree
-- already serves `filename LIKE 'docs/%'`. The text_pattern_ops opclass is
-- used anyway so the index stays correct if Engram is ever pointed at a
-- database created with a non-C collation, where a plain btree would be
-- skipped for prefix matching.
--
-- The composite leads with `owner` because every query in this feature is
-- owner-scoped before it matches a prefix.
CREATE INDEX idx_files_owner_filename
    ON files (owner, filename text_pattern_ops);
```

### Down

```sql
DROP INDEX IF EXISTS idx_files_owner_filename;
```

Fully reversible. No data is modified.

## Deferred: display-path backfill

Not part of this feature. Recorded here so it is not rediscovered from scratch.

If the [quickstart.md](./quickstart.md) diagnostic ever reports `backfill_targets > 0` — rows
ingested before feature 008, holding a basename-only `filename` alongside a current-layout key that
carries folder structure — this repairs them:

```sql
UPDATE files
SET filename = regexp_replace(file_path, '^files/[^/]+/[0-9]{4}/[0-9]{2}/', ''),
    updated_at = now()
WHERE storage_type = 's3'
  AND position('/' in filename) = 0
  AND file_path ~ '^files/[^/]+/[0-9]{4}/[0-9]{2}/.+/';
```

It is idempotent — the `position()` guard stops matching once applied — and not reversible, though
the original value is recoverable from `file_path`.

**Known side effect if it is ever run**: `filename` feeds the generated `tsv` column, so rewriting it
regenerates that column and makes folder names searchable. This widens search results slightly and
belongs in the Engram changelog at that time.

Until then, the client fallback in `displayPathForFile` handles basename-only rows by deriving the
display path from `file_path` (User Story 3 makes that fallback safe), so nothing is user-visibly
broken in the meantime.

## Deferred: pre-restructure keys

Rows whose `file_path` does not start with `files/` predate the key restructure. The diagnostic
currently reports **zero** of them. Should any appear, they are not repairable by migration: the
object is no longer at that key, and `userOwnsKey`
(`reliquary/backend/handler/handler.go:812-823`) rejects anything outside `files/<user>/`, so the
file is already undownloadable. Repair versus deletion is an operator decision requiring a check
against `indexes/<user>/files.json`.

## Row shapes the diagnostic distinguishes

| Shape | `filename` | `file_path` | Present locally | Handling |
|---|---|---|---|---|
| Post-008 folder upload | `docs/a.pdf` | `files/u/2026/07/docs/a.pdf` | no | already correct |
| Post-008 flat upload | `a.pdf` | `files/u/2026/07/a.pdf` | yes, all 20 | already correct |
| Pre-008 folder upload | `a.pdf` | `files/u/2026/07/docs/a.pdf` | no | deferred backfill |
| Pre-restructure key | `a.pdf` | `u/2026/07/a.pdf` | no | operator decision |

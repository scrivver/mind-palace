# Research: Engram Folder Listing

**Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

## R1: Where does the vault file list come from?

**Finding**: Engram, not Reliquary.

`app/lib/providers/file_list_provider.dart:109` calls `EngramService.listFiles`, which issues
`GET {engram}/api/files`. `ReliquaryService.listFiles` (`app/lib/reliquary_service.dart:51`) and
`app/lib/models/file_item.dart` exist but have no callers — dead code. Reliquary serves upload,
presign, batch download, delete, admin, and status.

**Consequence**: Directory listing belongs in Engram, which already owns the query engine.

## R2: Why is the folder tree incomplete?

**Finding**: It is derived client-side from the loaded page.

`visibleFoldersFor` and `visibleFilesFor` (`app/lib/widgets/gallery/gallery_view_model.dart`)
operate on `FileListState.files`, which holds only the pages fetched so far — 50 rows per page,
ordered `created_at DESC`. Folders whose files have not been paged in are invisible, and entering a
folder shows only that folder's files from the loaded pages.

**Rejected alternative**: switching the list source to Reliquary. Reliquary paginates by slicing its
manifest in memory (`reliquary/backend/handler/handler.go:752-760`) and offers no prefix or delimiter
mode, so the client-side derivation — and therefore the defect — would survive the migration. It
would additionally forfeit server-side search, tag, type, and date filters, which exist only in
Engram, and regress the display path, since Reliquary's manifest has no display-path field and
`original_name` is a basename (`handler.go:211`).

**Decision**: implement directory listing in Engram. Revisit the source-of-truth question separately.

## R3: Is `filename` a safe grouping key?

**Finding**: Yes for rows ingested after feature 008; not for older rows.

Feature 008 established `filename` as the user-facing display path and `file_path` as storage
identity. Reliquary emits it (`reliquary/backend/handler/handler.go:400-417`), ingestion persists it
verbatim (`engram/ingestion/worker/db.py:54-57`), and the API returns it.

Older rows carry a basename only. The client compensates in `displayPathForFile`
(`app/lib/widgets/gallery/gallery_view_model.dart:190-213`) by stripping `files/<user>/<yyyy>/<mm>/`
off `file_path`.

**Decision**: normalize the data once in a migration rather than carry a `CASE` expression in every
query. A `CASE` over `filename`/`file_path` cannot use an index; a backfilled column can.

## R4: Bug archaeology — was the display path ever the storage path?

**Finding**: No. The historical bug was truncation to a basename, not substitution of the key.

`git log -L` over the `Filename:` field in `reliquary/backend/handler/handler.go` shows exactly two
values across its whole history: `path.Base(key)` from commit `562e599`, then `displayName` from
commit `91ec709`. There are only two emission sites in Reliquary (`handler.go:391` delete,
`handler.go:408` create). The S3 bucket-notification branch of ingestion
(`engram/ingestion/worker/handler.py:78`) has also always taken a basename.

The full-path appearance originates in the **client** fallback. `displayPathForFile`'s final branch
returns `parts.join('/')` — the entire storage key — when the key matches none of its expected
layouts. A key in the pre-restructure layout `<username>/<year>/<month>/<filename>` reaches that
branch and renders as a folder tree `<username> > <year> > <month>`.

Corroboration that the older layout existed and was never fully migrated:
`storage.MigrateLegacyPrefix` (`reliquary/backend/storage/migrate.go:12`) moves `user/` to
`<admin>/` only; no migration moves `<username>/…` to `files/<username>/…` anywhere in the
codebase. `.data/minio/data/reliquary/akadmin/checksums.json` remains outside the `files/`
namespace as residue of it.

**Decision**: fix the fallback so it can never return a storage key, independently of the backend
work. Track as User Story 3.

## R5: What legacy data actually exists?

**Finding**: none. Object storage and the database are both clean.

Every object under `.data/minio/data/reliquary/files/` uses the current layout
`files/akadmin/2026/{06,07}/<basename>`, with matching `thumbs/` entries. The only objects outside
`files/` are `akadmin/checksums.json` and `admin/users.json` — residue of the pre-restructure
layout, not file objects.

The database was reachable over the unix socket at `.data/postgres` (`infra/postgresql.nix` sets
`unix_socket_directories` to `$PGDATA` and `listen_addresses = ''`, so there is no TCP listener).
The diagnostic reports 20 rows, all `storage_type='s3'`, all `status='ready'`, with
`legacy_layout=0`, `backfill_targets=0`, `filename_is_key=0`, and `has_display_path=0`. Every
`filename` is a bare basename, consistent with a dataset containing no folder uploads.

**Decision**: drop the backfill from the feature. Migration 005 adds an index only. The backfill SQL
and the pre-restructure-key discussion are preserved in [data-model.md](./data-model.md) as deferred
work, to be revisited only if the diagnostic ever reports a non-zero count. Keep the diagnostic
itself as a documented pre-flight check, since it is cheap and the answer differs per deployment.

**Consequence for testing**: with no folder uploads in the dataset, folder view correctly shows a
flat root. Exercising this feature requires uploading nested content first.


## R6: Will a prefix query use an index?

**Finding**: yes, already — the deployment collation is `C`.

`infra/postgresql.nix` initialises the cluster with `initdb --no-locale`, and
`pg_database.datcollate` for `engram` confirms `C`. Under C collation PostgreSQL can use a plain
btree for `filename LIKE 'docs/%'`, so the existing `idx_files_filename` from migration 001 would
already serve prefix matching. An earlier assumption that a `text_pattern_ops` opclass was required
was wrong for this deployment.

**Decision**: still add `idx_files_owner_filename` on `(owner, filename text_pattern_ops)`, for two
reasons. The composite leads with `owner`, which every query in this feature filters on before
matching a prefix, so it is a better shape than the single-column index. And `text_pattern_ops`
keeps the index correct if Engram is ever pointed at a database created with a non-C collation,
where a plain btree would be skipped for prefix matching. The opclass costs nothing under C.

**Related hazard, unchanged**: `_` and `%` are `LIKE` metacharacters regardless of collation. A
folder named `my_docs` would match `myXdocs` unescaped. Escape the prefix in Go and use `ESCAPE '\'`.


## R7: Should folder counts be recursive?

**Finding**: Yes, to preserve existing behavior.

`visibleFoldersFor` counts every file whose path starts with the prefix and contains at least one
further separator, grouped by first segment — a recursive count. Matching it avoids a visible change
in the numbers users already see.

## R8: How should filters interact with folder listing?

**Finding**: They must share one predicate builder.

If the folder query and the file query build their `WHERE` clauses separately, counts drift from
contents whenever a filter is active. Extracting the filter construction currently inlined in
`handleListFiles` (`engram/backend/internal/api/files.go:84-158`) into a shared helper also makes it
unit-testable: `fakeDB` in `files_test.go:19` discards the SQL entirely, so query correctness has no
coverage today.

# Quickstart: Engram Folder Listing

**Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

All commands run from the repository root inside `nix develop`.

## 0. Diagnose legacy rows

The database listens on a unix socket only — `infra/postgresql.nix` sets
`unix_socket_directories` to `$PGDATA` and `listen_addresses = ''`. Connect with:

```bash
psql -h "$PWD/.data/postgres" -d engram
```

**Result on 2026-08-28**: 20 rows, all `storage_type='s3'`, all `status='ready'`, with
`legacy_layout=0`, `backfill_targets=0`, `filename_is_key=0`, `has_display_path=0`. Nothing to
repair, which is why migration 005 is index-only. Re-run this against any other deployment before
assuming the same.

```sql
SELECT count(*) FILTER (WHERE file_path NOT LIKE 'files/%')  AS legacy_layout,
       count(*) FILTER (WHERE position('/' in filename) > 0) AS has_display_path,
       count(*) FILTER (WHERE filename = file_path)          AS filename_is_key,
       count(*) FILTER (WHERE position('/' in filename) = 0
                          AND file_path ~ '^files/[^/]+/[0-9]{4}/[0-9]{2}/.+/')
                                                             AS backfill_targets,
       count(*)                                              AS total
FROM files
WHERE storage_type = 's3';
```

Interpretation:

- All zero — nothing to do. This is the current local state.
- `backfill_targets > 0` — rows ingested before feature 008. Apply the deferred backfill from
  [data-model.md](./data-model.md), and note that it regenerates the `tsv` column.
- `legacy_layout > 0` — rows pointing at pre-restructure keys. Those files are already
  undownloadable, because presign rejects any key outside `files/<user>/`. Decide per deployment
  whether to repoint `file_path` (only if the object genuinely moved to `files/<user>/…`, checked
  against `indexes/<user>/files.json`) or delete the rows as ghosts. Record the decision in the PR.
- `filename_is_key > 0` — unexpected. No known code path produces it; investigate before migrating.

To list the offending rows:

```sql
SELECT id, filename, file_path FROM files
WHERE storage_type = 's3' AND file_path NOT LIKE 'files/%'
ORDER BY created_at;
```

## 1. Apply the migration

Migrations run automatically on Engram backend startup via `db.RunMigrations`. To verify:

```bash
psql -h "$PWD/.data/postgres" -d engram -c "\d files"   # expect idx_files_owner_filename
```

Confirm it modified no data — the row count and every `filename` should be unchanged:

```bash
psql -h "$PWD/.data/postgres" -d engram -c "SELECT count(*) FROM files;"
```

## 2. Engram backend tests

```bash
cd engram/backend && gofmt -l . && go test ./...
```

Focused:

```bash
cd engram/backend && go test ./internal/api -run 'Folder|Path|Scope|Filters'
```

## 3. Flutter checks

```bash
cd app && dart format --output=none --set-exit-if-changed lib test
cd app && flutter analyze
cd app && flutter test test/gallery
```

## 4. End-to-end verification

The current dataset contains **no folder uploads** — every key is a flat basename under the month
directory. Folder view correctly showing a flat root is therefore not a regression. To exercise the
feature you must create nested content first.

```bash
bin/mind-palace-up          # or the documented root launcher
```

1. Upload a folder through `/vault` containing at least two levels, e.g. `docs/a.pdf`,
   `docs/b.pdf`, `docs/notes/c.pdf`.
2. Upload enough additional flat files that the total exceeds one page (50).
3. Open `/vault?group=folders` without scrolling. **Expect** `docs` listed with `file_count = 3`.
4. Enter `docs`. **Expect** `a.pdf`, `b.pdf`, and a `notes` folder with `file_count = 1`.
5. Apply a type filter. **Expect** folder counts to shrink accordingly.
6. Type a search query while inside `docs`. **Expect** matches from outside `docs` and no folder rows.
7. Create a folder named `my_docs` and confirm it is reachable and lists only its own files.

## 5. Verify the storage-key fallback fix

No infrastructure needed — this is covered by unit tests:

```bash
cd app && flutter test test/gallery/gallery_view_model_test.dart
```

Assert that a file with `filename=report.pdf` and `file_path=akadmin/2026/06/report.pdf` projects to
`report.pdf`, producing no folder.

## 6. Submodule commit order

Per constitution principle II, commit inside `engram/` first, then update the root pointer alongside
the `app/` changes.

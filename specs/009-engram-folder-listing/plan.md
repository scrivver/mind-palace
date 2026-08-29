# Implementation Plan: Engram Folder Listing

**Branch**: `009-engram-folder-listing` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-engram-folder-listing/spec.md`

## Summary

Move vault directory listing from the Flutter client into Engram. Add a `GET /api/folders` endpoint
and a directory scope on `GET /api/files`, both sharing one filter builder so folder counts always
agree with folder contents. Add the index that prefix matching wants. Separately, repair the client display-path
fallback so a storage key can never be rendered as a folder tree.

## Technical Context

**Language/Version**: Go 1.x (Engram backend), Dart/Flutter (root app). No Python changes.

**Primary Dependencies**: Existing stdlib HTTP, pgx, golang-migrate, Riverpod. No new dependencies.

**Storage**: PostgreSQL `files` table. One migration adding an index; no row data is modified.
Object storage keys are untouched. The database is reached over the unix socket at `.data/postgres`
(`listen_addresses = ''`, so there is no TCP listener).

**Testing**: `cd engram/backend && go test ./...`; `cd app && flutter analyze && flutter test test/gallery`.
Full commands in [quickstart.md](./quickstart.md).

**Target Platform**: Engram backend service and the Flutter client, local and deployed stacks.

**Project Type**: Backend read API plus client consumption, in a Nix-managed monorepo with Git submodules.

**Performance Goals**: Folder listing is a single indexed aggregate per directory level. Prefix
predicates must use `idx_files_owner_filename`; no sequential scan on the `files` table.

**Constraints**: `GET /api/files` must stay backward compatible in both parameters and response
shape. Storage identity `(storage_type, file_path)` is unchanged. No queue, auth, or storage key
changes. The migration must not modify row data.

**Scale/Scope**: Two Engram handlers plus a shared filter builder, one index migration, one Flutter
service method, one provider, one view model, one screen. The local database holds 20 rows, so
correctness — not query performance — is what the tests must establish.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: All verification runs from root `nix develop` using component
  commands recorded in quickstart. No new dependencies in any manifest.
- **Component boundaries**: Engram owns metadata read access, so directory listing belongs there;
  `engram/README.md` and `engram/CLAUDE.md` were read before design. The client change is confined
  to `app/`. Reliquary is not modified. Submodule commits land in `engram/` before the root pointer
  moves.
- **Contract-driven integration**: The Engram read API contract is captured in
  [contracts/folder-listing-contract.md](./contracts/folder-listing-contract.md) before
  implementation. The canonical file-event contract is unaffected. Both endpoints are read-only, so
  idempotency is trivial; the migration's guards make it idempotent too.
- **Verification proportional to change**: Go unit tests for the pure helpers where none exist
  today, handler tests for parameter validation and response shape, Dart tests for the fallback and
  folder parsing, plus a documented manual UI pass since folder browsing is a visible workflow.
- **State and secret hygiene**: One index-only migration, declared here and in the PR. No row data is
  modified. No secrets, no environment variables, no new `.data/` state. The diagnostic query is
  documentation, not committed state.

Initial gate result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/009-engram-folder-listing/
├── plan.md
├── spec.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── folder-listing-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
engram/
  backend/
    internal/api/files.go
    internal/api/files_test.go
    internal/api/router.go
    internal/model/file.go
    internal/db/migrations/
      005_folder_listing_index.up.sql
      005_folder_listing_index.down.sql
  CLAUDE.md
  README.md
  docs/architecture.md

app/
  lib/
    engram_service.dart
    providers/file_list_provider.dart
    widgets/gallery/gallery_view_model.dart
    screens/gallery_screen.dart
  test/gallery/
    gallery_view_model_test.dart
    gallery_view_modes_test.dart
```

**Structure Decision**: Keep `filename` as the single display-path field rather than adding a
`display_path` column, so every query reads one indexed column instead of an unindexable `CASE`
expression over `filename` and `file_path`. Feature 008 already made `filename` the display path for
new ingests, and the diagnostic confirms no legacy rows need repair to make that uniform.

## Phase 0: Research

See [research.md](./research.md). Key outcomes:

- The vault list is served by Engram; the Reliquary list path is dead code (R1).
- Switching the list source to Reliquary would not fix the defect and would forfeit search and
  filters (R2) — rejected.
- The historical display-path bug was truncation to a basename, never substitution of the storage
  key; the full-path appearance comes from the client fallback (R4).
- Object storage and the database are both clean: 20 rows, zero legacy shapes, so no backfill ships (R5).
- The deployment collation is `C`, so prefix matching is already indexable; the new composite index is
  about leading with `owner` and staying correct on a non-C database. `LIKE` escaping is still required (R6).

## Phase 1: Design

See [data-model.md](./data-model.md),
[contracts/folder-listing-contract.md](./contracts/folder-listing-contract.md), and
[quickstart.md](./quickstart.md).

Design decisions:

1. **Additive API.** `GET /api/files` keeps its bare-array response and gains `path` and `scope`.
   A new `GET /api/folders` returns folder entries. No existing caller changes behavior.
2. **One filter builder.** Extract the filter construction inlined in `handleListFiles`
   (`files.go:84-158`) into a pure `buildFileFilters` used by both handlers. This guarantees counts
   match contents and gives the SQL its first test coverage — `fakeDB` discards queries entirely.
3. **Folders unpaginated.** A partial folder list is the defect being fixed.
4. **Recursive counts.** Matches what `visibleFoldersFor` computed, so displayed numbers do not shift.
5. **Diagnose before migrating.** The diagnostic ran first and reported zero repairable rows, so
   migration 005 is index-only. The backfill SQL and the pre-restructure-key handling are recorded
   as deferred work in `data-model.md` rather than written speculatively.
6. **Client fallback hardened independently.** Returning a basename instead of the whole key is
   correct regardless of the backend work, and lands as its own story.

## Post-Design Constitution Check

- **Nix-first reproducibility**: Unchanged; verification is component commands from the root shell.
- **Component boundaries**: Engram owns both endpoints and the migration; the client consumes them.
  Reliquary untouched. Submodule-first commit order recorded in quickstart step 6.
- **Contract-driven integration**: API contract written before implementation, including
  normalization, escaping, ordering, and count semantics.
- **Verification proportional to change**: Tests precede implementation in each story; the manual UI
  pass is documented because the current dataset cannot exercise folder view.
- **State and secret hygiene**: Migration impact declared and reduced to a single `CREATE INDEX`; no
  secrets or environment variables.

Post-design gate result: PASS.

## Complexity Tracking

No constitution violations. No accepted risks.

An earlier revision of this plan carried one: a `filename` backfill that would have regenerated the
generated `tsv` column and widened the search surface. Running the diagnostic first showed there was
nothing to back fill, so the risk was removed rather than accepted. The SQL survives as deferred
work in [data-model.md](./data-model.md).

## Deferred

Explicitly out of scope, listed so they are not silently dropped:

- `total_count` on `GET /api/files`, which would replace the `files.length == pageSize` inference in
  `file_list_provider.dart:120` and correct the gallery header count.
- `status=all` support, so pending and failed files are visible rather than hidden by the default
  `status=ready` filter.
- Reconciliation between Reliquary's manifest and Engram's rows, the durable fix for files that
  exist in object storage but never reached the database.
- The `filename` backfill and the disposition of pre-restructure keys, both currently zero-row and
  both specified in [data-model.md](./data-model.md).

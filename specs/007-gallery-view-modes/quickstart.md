# Quickstart: Gallery View Modes

## Prerequisites

- Enter the repository dev environment from the root:

```bash
nix develop
```

- Ensure submodules are initialized if using local services:

```bash
git submodule update --init --recursive
```

## Static Verification

Run Flutter analysis after implementation:

```bash
cd app && flutter analyze
```

Run focused gallery tests:

```bash
cd app && flutter test test/gallery
```

If the implementation touches shared widgets or route parsing broadly, run the full app test suite:

```bash
cd app && flutter test
```

## Manual Smoke Test

Start the app using the existing launcher:

```bash
start-app
```

Use a dataset with files in nested paths, for example:

```text
files/alice/2026/06/report.pdf
files/alice/2026/06/notes.md
files/alice/photos/image.jpg
files/alice/photos/trips/cover.jpg
```

### Scenario 1: Folder Browsing

1. Open `/vault`.
2. Enable folder grouping.
3. Verify root shows folders such as `2026` and `photos`.
4. Open `2026`, then `06`.
5. Verify only direct files in `2026/06` are shown.
6. Use the back/up control and verify parent folders restore correctly.

Expected outcome: folder navigation works without app reloads and file detail navigation still opens `/file/:fileId`.

### Scenario 2: Grid/List Toggle

1. Open `/vault`.
2. Select list view.
3. Verify folders/files render as rows with name and metadata.
4. Select grid view.
5. Verify the same logical items render as cards.

Expected outcome: toggling view mode does not clear search, type filters, tag filters, grouping mode, or folder path.

### Scenario 3: All-Files Mode

1. Open `/vault`.
2. Enable all-files mode.
3. Verify files from multiple directories appear together.
4. Verify list mode shows enough path context to distinguish duplicate filenames.
5. Open a file detail and return to the gallery.

Expected outcome: all-files mode preserves existing gallery behavior while adding path context.

### Scenario 4: Route State

1. Navigate to a non-default state such as list view, folder mode, and path `2026/06`.
2. Refresh the browser page.
3. Verify the gallery restores the same view/group/path where possible.
4. Change search/type/tag filters and verify query parameters continue to round-trip.

Expected outcome: `/vault` query parameters preserve gallery state without breaking existing search/filter routing.

### Scenario 5: Scroll Down To Load

1. Use a dataset with more files than the configured gallery page size.
2. Open `/vault`.
3. Scroll near the bottom in grid/all-files mode.
4. Verify a bottom loading indicator appears and additional files are appended.
5. Switch to list mode and repeat.
6. Enable folder grouping and repeat in a folder that has enough loaded or loadable files.

Expected outcome: additional files load automatically without next/previous page buttons. Changing search, filters, grouping, or folder path resets pagination for the new result set.

## Phase 2 Validation Targets

These checks apply only after the backend API improvement is planned and implemented:

- `GET /api/files` or a versioned replacement returns `items`, `next_cursor`, and `has_more`.
- The Flutter client stops inferring `hasMore` from `items.length == limit`.
- Cursor pagination remains stable when files are added or deleted while scrolling.
- A folder browse endpoint, if added, returns immediate child folders and direct files for a normalized path.
- Reliquary emits folder-upload display paths through the user-facing filename
  field, for example `filename=docs/myfile.pdf`, while keeping `file_path` as
  the storage key.

## Implementation Validation Notes

Automated validation run during Phase 1 implementation:

- `cd app && flutter test test/gallery` passed.
- `cd app && flutter test` passed.
- `cd app && flutter analyze` passed.

Manual browser smoke testing was not run in this implementation pass.

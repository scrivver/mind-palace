# Implementation Plan: Frontend Performance Optimization

**Branch**: `005-frontend-performance` | **Date**: 2026-06-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-frontend-performance/spec.md`

## Summary

Fix laggy mount/unmount and scroll performance in the Mind Palace Flutter app by making the gallery grid viewport-recycled, memoizing network-backed previews, localizing upload drag/progress state, adding stable keys to list items, and replacing broad Riverpod watches with `select`-based slices. All work is confined to `app/` and preserves existing visual behavior.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x

**Primary Dependencies**: `flutter_riverpod`, `go_router`, `dio`, `desktop_drop`, `file_picker`, `pdfrx`. No new runtime dependencies.

**Storage**: N/A — client-side widget/provider state only.

**Testing**: `cd app && flutter analyze` and `cd app && flutter test`. Manual smoke test with `start-app`.

**Target Platform**: Linux desktop (primary), Flutter web (secondary).

**Project Type**: Flutter desktop/web app performance optimization.

**Performance Goals**: 60 fps during gallery scroll; preview network requests happen at most once per file detail visit; upload drag/progress updates rebuild only the affected sub-tree.

**Constraints**:
- Zero visual or behavioral change.
- Must preserve conditional import pattern for web/native service abstractions.
- Each optimization step must leave `flutter analyze` clean and `flutter test` passing.
- No backend changes.

**Scale/Scope**: ~8-12 files in `app/lib/screens/`, `app/lib/widgets/`, and `app/lib/providers/`. Estimated ~300-500 lines changed.

## Constitution Check

- **Nix-first reproducibility**: Verification uses `cd app && flutter analyze` and `cd app && flutter test` from the root `nix develop` environment. Manual regression uses `start-app`.
- **Component boundaries**: Changes are limited to `app/`. No submodule work.
- **Contract-driven integration**: No API, event, queue, storage, schema, or authentication contract changes.
- **Verification proportional to change**: Flutter analysis and tests after each step. Widget tests added for preview caching and gallery key stability. Manual smoke test of login → gallery → file detail → upload → settings.
- **State and secret hygiene**: No new runtime state outside existing providers/widget state. No secrets or environment variables. `.data/` impact unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/005-frontend-performance/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (empty — no external contracts)
└── tasks.md             # Phase 2 output (generated later by /speckit-tasks)
```

### Source Code (repository root)

```text
app/
  lib/
    screens/
      gallery_screen.dart            # Replace nested scroll with SliverGrid, use select
      upload_screen.dart             # Localize drag state, use select
      file_detail_screen.dart        # Stable keys for tag chips
      admin_screen.dart              # Memoize filtered users
      settings_screen.dart           # Stable keys for theme cards
    widgets/
      gallery/
        file_tile.dart               # Add ValueKey, keep alive, cache thumbnail decode size
        filter_dropdown_panel.dart   # Keep draft state local
      file_detail/
        image_preview.dart           # Memoize presign future, cache decode size
        pdf_preview.dart             # Memoize PDF bytes future
      upload/
        upload_file_tile.dart        # Add ValueKey
    providers/
      file_list_provider.dart        # Fine-grained selectors if needed
      upload_provider.dart           # Fine-grained selectors if needed
      service_providers.dart         # Fine-grained selectors for router/auth
  test/                              # New widget tests for preview/cache behavior
```

**Structure Decision**: Keep changes localized to existing screens and widgets. Avoid large reorganization; this feature is about optimization, not restructuring.

## Complexity Tracking

No constitution violations required.

---

## Phase 0: Research

### Unknowns from Technical Context

1. **Gallery recycling mechanism** — How should the gallery combine app bar, filters, and grid so the grid recycles off-screen tiles?
2. **Preview future caching** — Should preview futures live in widget state or in a Riverpod provider/family?
3. **Image decode sizing** — What is the right `cacheWidth`/`cacheHeight` strategy for thumbnails vs. full previews?
4. **Upload drag localization** — What is the smallest widget boundary that can own drag hover state?
5. **Riverpod select granularity** — Which providers should expose selectors, and which widgets should consume them?

### Research Resolution

#### 1. Gallery Recycling Mechanism

**Decision**: Replace the current `SingleChildScrollView` + `GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` with a `CustomScrollView` whose slivers include the app bar, filter chips, and a `SliverGrid` for the file tiles.

**Rationale**: `CustomScrollView` lets each sliver participate in a single scrollable viewport. `SliverGrid` builds only visible children, which eliminates the upfront build cost and enables element recycling. The existing filter header becomes a `SliverToBoxAdapter` or `SliverPersistentHeader`.

**Alternatives considered**:
- Keep `SingleChildScrollView` and replace inner `GridView` with a `Wrap` — would still build all tiles.
- Use a `NestedScrollView` — unnecessary complexity; the header is not large enough to justify nested scrolling.

#### 2. Preview Future Caching

**Decision**: Cache preview futures in local `State` fields using `initState`/`didUpdateWidget` guards, and expose a small `PreviewCache` helper if the same file is visited repeatedly during the session.

**Rationale**: Most file detail visits are short-lived; a `State`-level memoized future is the smallest change that stops re-fetching on every parent rebuild. A provider-level cache could be added later if cross-screen caching is needed. PDF bytes and presigned image URLs are keyed by `file.id`/`filePath`.

**Alternatives considered**:
- Riverpod `FutureProvider.family` — excellent but requires more provider wiring for minimal gain; local state is sufficient for the reported issue.
- `CachedNetworkImage` — adds a dependency and is mainly useful for disk caching across app restarts; not needed for the immediate rebuild issue.

#### 3. Image Decode Sizing

**Decision**: Cap decode size to the rendered pixel dimensions:
- Thumbnails in `FileTile`: `cacheWidth`/`cacheHeight` based on tile size × `MediaQuery.devicePixelRatio`.
- Full image preview: cap to the smaller of image dimensions and screen size × device pixel ratio.

**Rationale**: Flutter's `Image.network` will decode the image at the requested cache size, reducing GPU memory and raster time. This is especially important for high-resolution photos.

**Alternatives considered**:
- Let Reliquary generate thumbnail sizes server-side — useful but out of scope for a client-only performance pass.
- Use `ResizeImage` — equivalent to `cacheWidth`/`cacheHeight`; direct widget parameters are simpler.

#### 4. Upload Drag Localization

**Decision**: Extract the drop zone into a dedicated `UploadDropZone` `StatefulWidget` that owns `_isDragging` and uses `StatefulBuilder`/`ListenableBuilder` for hover animation. The parent `UploadScreen` watches only the upload queue via `select`.

**Rationale**: Encapsulating hover state in a small widget prevents the entire screen from rebuilding. It also makes the drop zone reusable and easier to test.

**Alternatives considered**:
- `ValueNotifier` + `ListenableBuilder` inside `UploadScreen` — works but keeps logic in a large file; a dedicated widget is cleaner.
- Keep `setState` on `UploadScreen` — rejected because it is the root cause of the jank.

#### 5. Riverpod Select Granularity

**Decision**: Apply `select` at the point of consumption:
- `GalleryScreen` watches `fileListProvider.select((s) => s.files)` for the grid and `select((s) => s.isLoading)` for the loader.
- `UploadScreen` watches `uploadProvider.select((s) => s.selectedFiles)` for the list and `select((s) => s.isUploading)` for the header button.
- `routerProvider` watches only `appAuthProvider.select((s) => s.isLoggedIn)` instead of full async service providers.

**Rationale**: `select` lets widgets rebuild only when the slice they actually render changes. This is the idiomatic Riverpod solution to broad rebuilds.

**Alternatives considered**:
- Split every field into its own `StateProvider` — creates too many providers and fragments state.
- Use `Consumer` with narrow selectors — same effect as `select`; `select` is more concise.

---

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](./data-model.md) for the optimized provider/state boundaries and widget keying strategy.

Key design points:
- `FileListState` remains the source of truth; consumers use `select`.
- `UploadState` remains the source of truth; consumers use `select`.
- `PreviewCache` is a lightweight in-memory helper keyed by `fileId` + preview type.
- Widget keys are derived from stable identifiers (`file.id`, `task.id`, `username`, `setting.name`).

### API Contracts

No new API contracts. All changes are internal to the Flutter app. See [contracts/](./contracts/).

### Quickstart Guide

See [quickstart.md](./quickstart.md) for runnable validation scenarios.

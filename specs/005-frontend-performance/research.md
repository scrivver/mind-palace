# Research: Frontend Performance Optimization

## Decision: Gallery Layout

**Decision**: Replace `SingleChildScrollView` + `GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` with `CustomScrollView` + `SliverGrid`.

**Rationale**: The current nested scroll layout disables viewport recycling, forcing Flutter to build every gallery tile on mount. `CustomScrollView` unifies headers and grid in one scrollable viewport and lets `SliverGrid` build only visible children. This directly addresses the laggy mount/unmount behavior in the gallery.

**Alternatives considered**:
- `Wrap` inside `SingleChildScrollView` — still builds all items.
- `NestedScrollView` — overkill for a single header and grid.

## Decision: Preview Future Caching

**Decision**: Memoize preview futures in widget `State` using an explicit cached future field, guarded by `didUpdateWidget` to reset only when the target file changes. Add a small in-memory `PreviewCache` helper keyed by `fileId` if the same file is revisited in the same session.

**Rationale**: The observed flicker/re-fetch is caused by creating a new future inside `build` every time the parent rebuilds. A stable future field stops the re-request while keeping the change minimal. No backend or provider restructuring is required.

**Alternatives considered**:
- Riverpod `FutureProvider.family` — idiomatic but more invasive; can be adopted later if cross-screen caching is needed.
- `CachedNetworkImage` — solves disk caching across restarts but does not stop the presigned URL from being regenerated on every rebuild.

## Decision: Image Decode Sizing

**Decision**: Pass `cacheWidth` and `cacheHeight` to `Image.network` calls, capped to rendered pixel size (tile size or screen size × `devicePixelRatio`).

**Rationale**: Decoding a full-resolution image into memory and then downscaling at render time wastes memory and GPU time. `cacheWidth`/`cacheHeight` tells the engine to decode at the smaller size.

**Alternatives considered**:
- Server-side thumbnail generation — useful future improvement but out of scope for a client-only pass.
- `ResizeImage` widget — functionally equivalent; direct parameters are simpler.

## Decision: Upload Drag State Localization

**Decision**: Extract the drop zone into a dedicated `UploadDropZone` `StatefulWidget` that owns `_isDragging`. The parent watches only the upload queue slice it needs.

**Rationale**: `setState` on the whole `UploadScreen` rebuilds the entire file queue whenever the drag cursor enters or leaves the window. Moving hover state into a small widget limits rebuilds to the drop zone itself.

**Alternatives considered**:
- `ValueNotifier` inside `UploadScreen` — still keeps logic in a large file; dedicated widget is cleaner.
- Keep current `setState` — rejected because it is the source of the jank.

## Decision: Riverpod Select Granularity

**Decision**: Use `ref.watch(provider.select((s) => s.field))` at the point of consumption for gallery files, loading flags, upload queue, and auth login state. Avoid watching whole async service providers in the router.

**Rationale**: `select` is the idiomatic Riverpod tool for fine-grained rebuilds. It avoids fragmenting state into many tiny providers while still ensuring widgets rebuild only when the data they render changes.

**Alternatives considered**:
- One provider per field — creates too many providers and fragments related state.
- `Consumer` widgets with manual equality — equivalent to `select` but more verbose.

## Decision: List Item Keys

**Decision**: Add stable `ValueKey` widgets to `FileTile`, `UploadFileTile`, `_UserTile`, tag chips, and theme setting cards.

**Rationale**: Without keys, Flutter cannot efficiently reuse elements when lists are reordered, filtered, or paginated. Stable keys preserve widget state and reduce element churn.

**Alternatives considered**:
- Use index-based keys — unstable when filtering/sorting; rejected.
- No keys — current behavior; rejected because it contributes to mount cost.

## Decision: Admin Search Memoization

**Decision**: Compute `_filteredUsers` with `useMemoized` (or equivalent memoization in `State`) keyed by `_query` and the user list.

**Rationale**: Filtering the full user list on every build is wasteful. Memoizing ensures the filter runs only when inputs change, keeping the search field responsive.

**Alternatives considered**:
- Debounce only — still recomputes on every build after debounce window.
- Move filtering into a provider — reasonable but more coupling for a single-screen concern; memoization in the widget is sufficient.

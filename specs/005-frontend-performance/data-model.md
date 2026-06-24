# Data Model: Frontend Performance Optimization

This document defines the optimized widget keying strategy, provider consumption boundaries, and conceptual cache entities for the performance feature.

## Provider Consumption Boundaries

No new providers are required. Existing providers are consumed with finer granularity via `select`.

### Existing Providers

| Provider | Current Watch Pattern | Optimized Watch Pattern |
|----------|----------------------|-------------------------|
| `fileListProvider` | `ref.watch(fileListProvider)` (whole state) | `ref.watch(fileListProvider.select((s) => s.files))` for grid; `select((s) => s.isLoading)` for loader; `select((s) => s.hasMore)` for pagination button |
| `uploadProvider` | `ref.watch(uploadProvider)` (whole state) | `ref.watch(uploadProvider.select((s) => s.selectedFiles))` for list; `select((s) => s.isUploading)` for header |
| `appAuthProvider` / `authServiceProvider` | Full async provider watch in router | `ref.watch(appAuthProvider.select((s) => s.isLoggedIn))` |

### Selectors to Add (if not present)

```dart
extension FileListStateX on FileListState {
  bool get isLoading => ...;
  bool get hasMore => ...;
}

extension UploadStateX on UploadState {
  bool get isUploading => ...;
}
```

## Widget Keying

Stable keys derived from stable identifiers.

| Widget | Key Source | Rationale |
|--------|-----------|-----------|
| `FileTile` | `ValueKey(file.id)` | `EngramFile.id` is stable across pagination/filtering |
| `UploadFileTile` | `ValueKey(task.id)` | Upload task ID is unique and stable |
| `_UserTile` | `ValueKey(user['username'])` | Username is the unique identifier in admin list |
| Tag chip | `ValueKey(tag)` | Tag string is unique within a file |
| Theme setting card | `ValueKey(setting.name)` | Setting name is unique |

## Cache Entities

### `PreviewCache`

Conceptual in-memory cache for file previews. Implemented as a simple static helper or provider-scoped cache.

```dart
class PreviewCache {
  final Map<String, Future<Uint8List>> _pdfBytes = {};
  final Map<String, Future<String>> _presignedUrls = {};

  Future<Uint8List> pdfBytes(String fileId, Future<Uint8List> Function() fetch);
  Future<String> presignUrl(String fileId, Future<String> Function() fetch);
}
```

- Key: `fileId` or `filePath`.
- Lifetime: Session-scoped. Reset on app restart.
- Invalidation: Explicit only (e.g., when file is deleted). No TTL required for first iteration.

### `ThumbnailCache`

Optional future enhancement: a Riverpod provider family keyed by `filePath` that caches presigned thumbnail URLs across the session. For this feature, per-tile memoization with `AutomaticKeepAliveClientMixin` is sufficient.

## State Transitions

No new state transitions. Existing provider states (`FileListState`, `UploadState`, auth state) remain unchanged. Only widget rebuild boundaries change.

## Validation Rules

- Every `ListView`/`GridView` item builder must pass a stable `Key` to its child.
- Every `ref.watch` inside a screen must use `select` unless the whole object is genuinely needed.
- `Image.network` calls for thumbnails and previews must include `cacheWidth`/`cacheHeight`.
- `FutureBuilder` futures for previews must be cached in `State`, not recreated in `build`.

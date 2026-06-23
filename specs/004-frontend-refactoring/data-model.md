# Data Model: Frontend Codebase Refactoring

This document defines the refactored module boundaries, provider hierarchy, route definitions, and shared utility interfaces.

---

## Provider Hierarchy (Riverpod)

All providers are top-level declarations using `riverpod_annotation` code generation.

```
                      ┌──────────────────────────┐
                      │  serverUrlStoreProvider   │
                      │  (SharedPreferences URL) │
                      └──────────┬───────────────┘
                                 │
               ┌─────────────────┼─────────────────┐
               ▼                 ▼                   ▼
   ┌────────────────────┐ ┌──────────────┐ ┌──────────────────┐
   │ authServiceProvider │ │ engramService │  │ reliquaryService │
   │   (AuthService)    │ │   Provider    │  │    Provider      │
   │                    │ │ (EngramService)│  │(ReliquaryService)│
   └───────┬────────────┘ └──────┬───────┘  └────────┬─────────┘
           │                     │                    │
           │            ┌────────┴────────┐           │
           │            │ fileListProvider │           │
           │            │ (search/filter/ │           │
           │            │  paginate)      │           │
           │            └─────────────────┘           │
           │                                          │
           │            ┌────────────────┐            │
           │            │uploadProvider   │            │
           │            │(queue/status/   │            │
           │            │ progress/retry) │            │
           │            └────────────────┘            │
           │                                          │
           └────────────┬─────────────────────────────┘
                        ▼
              ┌─────────────────────┐
              │ themeServiceProvider │
              │  (Stream<ThemeMode>) │
              └─────────────────────┘
```

### Provider Definitions

| Provider | Type | Description |
|----------|------|-------------|
| `serverUrlStoreProvider` | `Provider<ServerUrlStore>` | Wraps static `ServerUrlStore` class |
| `authServiceProvider` | `Provider<AuthService>` | Creates `AuthService` with URL from `ServerUrlStore` |
| `engramServiceProvider` | `Provider<EngramService>` | Creates `EngramService` with URL and auth token callback |
| `reliquaryServiceProvider` | `Provider<ReliquaryService>` | Creates `ReliquaryService` with URL and auth token callback |
| `themeServiceProvider` | `Provider<ThemeService>` | Singleton wrapping `ThemeService` stream |
| `fileListProvider` | `StateNotifierProvider<FileListNotifier, FileListState>` | Gallery file list with search/filter/pagination |
| `uploadProvider` | `StateNotifierProvider<UploadNotifier, UploadState>` | Upload queue with status/progress/retry |

### FileListState

```dart
@freezed
class FileListState with _$FileListState {
  const factory FileListState({
    @Default([]) List<EngramFile> files,
    @Default(false) bool isLoading,
    String? error,
    @Default('') String searchQuery,
    String? selectedTag,
    String? selectedType,
    @Default(0) int currentPage,
    @Default(false) bool hasMore,
  }) = _FileListState;
}
```

### UploadState

```dart
@freezed
class UploadState with _$UploadState {
  const factory UploadState({
    @Default([]) List<UploadTask> queue,
    @Default(false) bool isUploading,
  }) = _UploadState;
}

@freezed
class UploadTask with _$UploadTask {
  const factory UploadTask({
    required String id,
    required String fileName,
    required int totalBytes,
    @Default(0) int uploadedBytes,
    @Default(UploadStatus.pending) UploadStatus status,
    String? error,
  }) = _UploadTask;
}

enum UploadStatus { pending, uploading, completed, failed }
```

---

## Route Definitions (go_router)

```dart
GoRouter(
  initialLocation: '/vault',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(sidebar: Sidebar(), body: child),
      routes: [
        GoRoute(path: '/vault',      builder: (_, __) => const GalleryScreen()),
        GoRoute(path: '/status',     builder: (_, __) => const StatusScreen()),
        GoRoute(path: '/settings',   builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/upload',     builder: (_, __) => const UploadScreen()),
        GoRoute(
          path: '/file/:fileId',
          builder: (_, state) => FileDetailScreen(fileId: state.pathParameters['fileId']!),
        ),
      ],
    ),
  ],
)
```

### Gate routes (login, server setup)

These sit outside the `ShellRoute`:

```dart
GoRoute(path: '/setup',   builder: (_, __) => const ServerSetupScreen()),
GoRoute(path: '/login',   builder: (_, __) => const LoginView()),
```

The router redirects to `/setup` if no server URL is configured, `/login` if not authenticated, and the `ShellRoute` if authenticated.

---

## Shared Utility Interfaces

### `utils/format.dart`

```dart
class FormatUtils {
  /// "1.5 MB", "342 KB", etc.
  static String formatBytes(int bytes, {int decimals = 1});

  /// "Just now", "5m ago", "2h ago", "3d ago"
  static String relativeTime(DateTime dateTime, {DateTime? now});
}

/// Maps MIME type to Material icon
IconData iconForMime(String mimeType);
```

### `utils/logger.dart`

```dart
class LoggerService {
  void info(String message, {Object? error, StackTrace? stackTrace});
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
  void debug(String message);
}
```

Uses `dart:developer` `log()` under the hood.

---

## Widget Extraction Boundaries

### `widgets/gallery/`

| File | Source | Exported Widget |
|------|--------|----------------|
| `file_tile.dart` | `_FileTile` in `gallery_screen.dart` | `class FileTile extends StatefulWidget` |
| `filter_dropdown_panel.dart` | `_FilterDropdownPanel` + `_FilterDropdownPanelState` | `class FilterDropdownPanel extends StatefulWidget` |
| `quick_filter_chip.dart` | `_QuickFilterChip` in `gallery_screen.dart` | `class QuickFilterChip extends StatelessWidget` |

### `widgets/upload/`

| File | Source | Exported Widget |
|------|--------|----------------|
| `upload_file_tile.dart` | `_UploadFileTile` in `upload_screen.dart` | `class UploadFileTile extends StatelessWidget` |
| `upload_progress.dart` | `_UploadProgress` in `upload_screen.dart` | `class UploadProgress extends StatelessWidget` |
| `dashed_border_painter.dart` | `_DashedBorderPainter` in `upload_screen.dart` | `class DashedBorderPainter extends CustomPainter` |
| `upload_service.dart` | *New* | `class UploadService` — manages queue, progress, retry |

### `widgets/file_detail/`

| File | Source | Exported Widget |
|------|--------|----------------|
| `image_preview.dart` | Image preview section of `file_detail_screen.dart` | `class ImagePreview extends StatelessWidget` |
| `pdf_preview.dart` | PDF preview section of `file_detail_screen.dart` | `class PdfPreview extends StatelessWidget` |
| `extracted_text_dialog.dart` | Extracted text dialog in `file_detail_screen.dart` | `Future<void> showExtractedTextDialog(BuildContext, String)` |
| `delete_dialog.dart` | `_DeleteDialog` in `file_detail_screen.dart` | `Future<bool?> showDeleteDialog(BuildContext, String)` |

---

## Auth Config Probing Consolidation

The `GET /api/auth/config` endpoint probing currently lives in 3-4 places. After refactoring:

1. `ServerUrlStore.validateUrl(String url)` — static method that probes the endpoint and returns `AuthConfig`.
2. `AuthService.probeConfig(String baseUrl)` — existing static method, kept for internal auth service use.
3. `ServerUrlStore.validateUrl` is used by `ServerSetupScreen`, `SettingsScreen`, and `main.dart`.

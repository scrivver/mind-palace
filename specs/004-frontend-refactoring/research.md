# Research: Frontend Codebase Refactoring

## Technology Choices

### 1. State Management / DI: Riverpod

- **Decision**: `flutter_riverpod` + `riverpod_annotation`
- **Rationale**: Compile-safe DI without `BuildContext` dependency; supports code generation; naturally replaces both `HomePage`'s manual DI and `setState`-based state management; autodispose prevents memory leaks.
- **Alternatives considered**:
  - **Provider** — requires `BuildContext`, couples to widget tree, less flexible autodispose.
  - **BLoC** — excessive boilerplate for ~6.4kLOC codebase; would need event/state classes per screen.
  - **GetIt** — DI-only; still needs separate state management solution.
  - **GetX** — magical dependencies make refactoring harder to reason about.

### 2. Navigation: go_router

- **Decision**: `go_router`
- **Rationale**: Declarative routing with `ShellRoute` for sidebar wrapping; `StatefulShellBranch` maps to current screen tabs; detail route with file ID parameter; browser back button and deep linking work automatically.
- **Alternatives considered**:
  - **Navigator 2.0 raw** — overly verbose for current needs.
  - **Keep index-based routing** — viable fallback but doesn't support future web deep-linking.

### 3. Logging: Custom LoggerService

- **Decision**: Dart `dart:developer` `log()` wrapped in a `LoggerService` class
- **Rationale**: No third-party dependency needed; wrapper enables future replacement; centralized debug output control.
- **Alternatives considered**:
  - **`logging` package** — unnecessary dependency for this codebase size.
  - **`logger` package** — pretty-printing is cosmetic for a dev tool.

### 4. Refactoring Sequence

| Step | Description | Verifiable By |
|------|-------------|--------------|
| 1 | Create `utils/format.dart`, `utils/logger.dart` | `flutter analyze` |
| 2 | Replace inline duplicates with utility imports | `flutter analyze` |
| 3 | Add Riverpod providers wrapping existing services | `flutter analyze` + app runs |
| 4 | Migrate to go_router with ShellRoute | All screen navigation works |
| 5 | Split `gallery_screen.dart` → `widgets/gallery/*` | Gallery loads and filters |
| 6 | Split `upload_screen.dart` → `widgets/upload/*` | Upload flow works |
| 7 | Split `file_detail_screen.dart` → `widgets/file_detail/*` | File detail renders |
| 8 | Strip `HomePage` god class | App starts and navigates |
| 9 | Add test coverage | `flutter test` passes |
| 10 | Final cleanup | `flutter analyze` clean |

### 5. Conditional Import Compatibility

Riverpod works fine with the existing conditional import pattern. Services using `export 'foo_web.dart' if (dart.library.io) 'foo_native.dart'` remain unchanged. Providers simply `ref.read` these services as they exist today.

# Research: Settings Page

## 1. Theme Persistence Mechanism

**Decision**: Use `shared_preferences` for theme persistence.

**Rationale**: `shared_preferences` is the standard Flutter plugin for simple key-value persistence. It works on all Flutter platforms (Linux desktop uses a JSON file in the app's data directory; web uses `localStorage`). The `shared_preferences` package is already a transitive dependency via Flutter's ecosystem and can be added explicitly with `flutter pub add shared_preferences`. Theme preference is a single `String` enum value (`"light"`, `"dark"`, `"system"`) — well within `shared_preferences`' sweet spot.

**Alternatives considered**:
- Raw file I/O via `dart:io` — platform-specific and doesn't work on web.
- `flutter_secure_storage` — overkill for a non-sensitive theme preference.
- Riverpod `StateNotifier` with in-memory only — would not persist across restarts.

## 2. Password Reset Authentik URL

**Decision**: Open `https://[AUTHENTIK_URL]/if/flow/password-reset/` in a new browser tab using `launchUrl` from `url_launcher`.

**Rationale**: Authentik provides a standard password reset flow at `/if/flow/password-reset/`. Opening in a new tab keeps the Mind Palace app session intact. The Authentik base URL is already configured in `main.dart` as `_authentikBase` and is available via `authService`.

**Alternatives considered**:
- Embedding the Authentik flow in an iframe — more complex and may have CORS issues.
- Custom password reset form — would require Authentik Admin API integration (Service account, API token) and backend coordination, beyond v1 scope.

## 3. Stitch Design Specifics

**Decision**: The Stitch design (screen: "Settings / Theme & Password Reset", desktop 2560×2408) shows two sections in card-based layout. The sidebar is already present. The content area shows:

- **Settings** heading at top
- **Appearance** card with radio-style selection showing three theme options (Light, Dark, System) with a visual preview circle/icon for each
- **Account** card with "Reset Password" list tile and external link icon

**Rationale**: The two-section card layout matches the existing app design language seen in the Status page (cards with borders, section headers, list tiles with icons). The appearance section uses radio tiles for mutually exclusive selection.

**Alternatives considered**:
- Tab-based layout — not aligned with Stitch design.
- Dropdown for theme — less discoverable than radio tiles.
- Toggle switch — only supports two states; doesn't work for three options.

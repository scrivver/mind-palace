# Feature Specification: Client-Side Routing & Auth Flow Restructure

**Feature Branch**: `006-client-routing`

**Created**: 2026-06-25

**Status**: Draft

**Input**: User observation: manual URL entry in browser address bar does not navigate to the correct page; OIDC callback relies on a JS hack in `index.html`.

## User Scenarios & Testing

### User Story 1 — Deep-link to any page (Priority: P1)

As a user, when I type a URL like `/settings` or `/status` directly into the browser address bar, I want to land on that page (after auth resolves) instead of being redirected to `/loading` and then to a default page.

**Why this priority**: Bookmarking and sharing links is fundamental web behavior. The current redirect to `/loading` overwrites the browser URL before auth completes, and the `_pendingRedirect` workaround is unreliable.

**Independent Test**: Open a fresh browser, type `http://localhost:3000/settings`, press Enter. After login (if unauthenticated) or immediately (if authenticated), land on the Settings screen.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I type `/settings` in the address bar, **Then** the settings page renders without first flashing `/loading` or `/vault`.
2. **Given** I am not authenticated, **When** I type `/settings` in the address bar, **Then** I see the login page, and after login I land on `/settings`.
3. **Given** I refresh the page on `/settings`, **When** auth state resolves, **Then** I remain on `/settings`.
4. **Given** I type an unknown path, **When** the app loads, **Then** a 404/fallback is shown (same behavior as current).

---

### User Story 2 — OIDC callback without JS hack (Priority: P1)

As a developer, I want the OIDC redirect (`/callback?code=...`) to be handled entirely in Dart, without a pre-load `<script>` in `index.html` that manipulates `sessionStorage` and `history`.

**Why this priority**: The JS hack is fragile, opaque, and bypasses Dart's routing layer. A Dart-native solution is more maintainable and testable.

**Independent Test**: Perform an OIDC login flow end-to-end. The callback URL is processed by Dart code, tokens are stored, and the user lands on `/vault`. No errors or flashes.

**Acceptance Scenarios**:

1. **Given** the OIDC provider redirects to `/callback?code=xxx&state=yyy`, **When** the app loads, **Then** the token exchange completes and the URL is cleaned up.
2. **Given** the token exchange succeeds, **When** auth resolves, **Then** the user is redirected to `/vault`.
3. **Given** the params are malformed or missing, **When** the callback is processed, **Then** the user is redirected to `/login` with an appropriate error.

---

### User Story 3 — Clean redirect flow (Priority: P2)

As a developer, I want the router's redirect function to have a single responsibility (auth gating) so that loading state and splash screens are handled independently.

**Why this priority**: The current redirect function conflates three concerns: loading splash, auth guard, and URL restoration. This coupling is why deep-linking breaks.

**Independent Test**: No functional change visible to the user. Verified by `flutter analyze` and the scenarios in User Story 1.

---

### Edge Cases

- What happens when the user rapidly navigates while auth is still resolving? The redirect should return `null` (no redirect) so GoRouter matches the requested route; the loading overlay shows on top.
- What if the OIDC callback URL arrives while auth is still resolving? `completeRedirectIfPresent` runs during `initialize()` before the redirect re-evaluates, so the callback params are available in `Uri.base`.
- What if `history.replaceState` in `_clearOidcCallbackUrl()` changes the URL under GoRouter? GoRouter handles `replaceState` via the `PopStateEvent` listener; the route state stays consistent.

## Requirements

### Functional Requirements

- **FR-001**: The router redirect function MUST NOT redirect based on `isLoading` state. Auth loading MUST NOT change the browser URL.
- **FR-002**: The loading indicator MUST be rendered as an overlay via `MaterialApp.router`'s `builder` parameter, not via a GoRouter route.
- **FR-003**: The `_pendingRedirect` module variable and `/loading` route MUST be removed.
- **FR-004**: The OIDC callback parameters MUST be read from `Uri.base` inside `completeRedirectIfPresent()`.
- **FR-005**: The JS hack in `app/web/index.html` MUST be removed. The `sessionStorage` fallback in `_oidcCallbackParams()` may remain as a safety net.
- **FR-006**: `flutter analyze` MUST report zero errors after each change.

### Key Entities

- **GoRouter redirect**: Remains for auth gating only (login guard, setup guard).
- **Loading overlay**: New `Consumer`-based overlay in `MaterialApp.router.builder` that wraps the routed child in a `Stack` with a conditional `CircularProgressIndicator`.
- **`/callback` route**: Remains as a no-op route (`SizedBox.shrink()`) — GoRouter matches it to keep the URL stable while `completeRedirectIfPresent()` runs.
- **`auth_service_web.dart`**: `_oidcCallbackParams()` already has a `Uri.base` fallback — no change needed beyond removing the JS hack in `index.html`.

### Contracts & Integration Impact

- **Affected Components**: `app/web/index.html`, `app/lib/main.dart`, `app/lib/router/app_router.dart`.
- **Contracts**: No API, event, queue, storage, or authentication contract changes.
- **State & Migrations**: No migrations. The `_pendingRedirect` and `_lastAuthState` globals in `app_router.dart` are removed.
- **Idempotency/Retry Behavior**: No event-producing changes.
- **Secrets/Configuration**: No new secrets or environment variables.

## Success Criteria

- **SC-001**: Manual URL entry (`/settings`, `/status`, `/vault`, `/upload`) lands on the correct page after auth resolves.
- **SC-002**: OIDC login flow completes without JS errors or missing params, with the JS hack removed from `index.html`.
- **SC-003**: `flutter analyze` reports zero errors.
- **SC-004**: The browser URL does not flash `/loading` during app initialization.

## Assumptions

- `Uri.base` reliably contains query parameters during Dart init for path URL strategy in Flutter web (verified against Flutter 3.x web behavior).
- The existing `sessionStorage` fallback in `_oidcCallbackParams()` can remain as an inert safety net without the `index.html` script feeding it.
- GoRouter's `refreshListenable` works correctly when the router config is a Riverpod `Provider` that gets replaced — confirmed working from the example app.
- The `builder` parameter of `MaterialApp.router` fires on every rebuild, allowing the loading overlay to react to auth state changes.

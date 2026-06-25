# Implementation Plan: Client-Side Routing & Auth Flow Restructure

**Branch**: `006-client-routing` | **Date**: 2026-06-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-client-routing/spec.md`

## Summary

Restructure GoRouter's redirect logic and the auth-loading UX so that manual URL entry (deep-linking) works correctly and the OIDC callback flow is handled entirely in Dart. The core idea: separate the loading indicator from GoRouter's redirect so the browser URL never changes before auth resolves.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x

**Primary Dependencies**: `flutter_riverpod`, `go_router`. No new dependencies.

**Storage**: `localStorage` / `sessionStorage` via `dart:html` (web) — existing.

**Testing**: `cd app && flutter analyze`. Manual smoke test with `start-app` on web, verifying deep-link entry and OIDC login.

**Target Platform**: Flutter web (primary — this is a web routing issue), Linux desktop (secondary — path strategy is no-op).

**Key Constraint**: The browser URL must never transition through `/loading`. The loading state must be purely visual.

**Root cause**: `app_router.dart` redirect intercepts ALL routes when `authState.isLoading` is true, redirecting to `/loading` and saving the original URL to `_pendingRedirect`. The `/loading` redirect changes the browser URL before auth resolves. By the time auth completes and a new GoRouter instance is created, the browser URL is `/loading`, not the original target. The `_pendingRedirect` module variable attempts to restore the original URL but is unreliable across multiple GoRouter instance recreations triggered by Riverpod's `Provider` re-evaluation.

**Callback issue**: The JS hack in `index.html` exists because the `/callback` URL contains query params that Flutter web's bootstrap doesn't reliably surface through `Uri.base`. With the routing fix, the URL never changes during init, so `Uri.base.queryParameters` is available when `completeRedirectIfPresent()` runs.

**Scale**: 4 files changed (`app/web/index.html`, `app/lib/main.dart`, `app/lib/router/app_router.dart`, `app/lib/providers/service_providers.dart`). ~100 lines changed.

## Constitution Check

- **Nix-first reproducibility**: Verification uses `cd app && flutter analyze`. Manual regression uses `start-app`.
- **Component boundaries**: Changes are limited to `app/`. No submodule work.
- **Contract-driven integration**: No API, event, queue, storage, schema, or authentication contract changes.
- **Verification proportional to change**: Flutter analysis. Manual deep-link and OIDC login test on web.
- **State and secret hygiene**: No new runtime state outside existing providers. No secrets or environment variables.
- **Gates**: No violations. All routing logic changes are scoped to the Flutter app layer.

## Complexity Tracking

No constitution violations required.

---

## Phase 0: Research

### Unknowns from Technical Context

1. **GoRouter redirect + `builder` interaction** — Does GoRouter run the redirect when `MaterialApp.router.builder` provides a wrapping `Stack`? Verified: yes — redirect runs entirely before the builder is called. The builder simply wraps whatever route GoRouter resolved.
2. **`Uri.base` reliability for query params** — Can `Uri.base` be relied upon to carry query params during Dart init on web with path URL strategy? Done — `auth_service_web.dart` already implements this as the fallback path in `_oidcCallbackParams()`.
3. **GoRouter `refreshListenable` across `Provider` re-evaluation** — Does GoRouter handle the redirect correctly when the router config is a new instance from a Riverpod `Provider`? Yes — GoRouter's `refreshListenable` fires on the new instance and re-evaluates the redirect.

### Research Resolution

All three unknowns resolved without additional investigation. The existing codebase patterns confirm feasibility.

---

## Phase 1: Design

### Data Model

No new data models. Changes are structural:

- **Remove**: `_pendingRedirect`, `_loadingTarget()`, `/loading` route, `refreshListenable`, `_AuthRefreshNotifier`, `_authRefreshProvider`.
- **Simplify** `routerProvider`: Remove dependency on `_authRefreshProvider`. Keep watches on `authServiceProvider`, `engramServiceProvider`, `reliquaryServiceProvider` for service injection.
- **Add**: `Consumer` in `MaterialApp.router.builder` that watches `appAuthProvider` and overlays a `CircularProgressIndicator` when `isLoading`.

### Redirect Logic (simplified)

```dart
redirect: (context, state) {
  if (authState.isLoading) return null;   // ← key change
  if (needsSetup && path != '/setup') return '/setup';
  if (!authState.isLoggedIn && path != '/login' && path != '/setup') return '/login';
  if (authState.isLoggedIn && path == '/login') return '/vault';
  return null;
},
```

The redirect has one job: **auth gating**. Loading is handled in `builder`.

### Loading Overlay

```dart
MaterialApp.router(
  routerConfig: ref.watch(routerProvider),
  builder: (context, child) {
    return Consumer(builder: (context, ref, child) {
      final isLoading = ref.watch(appAuthProvider.select((s) => s.isLoading));
      return Stack(
        children: [
          if (child != null) child,
          if (isLoading)
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        ],
      );
    }, child: child);
  },
);
```

### Callback Flow (after JS hack removal)

1. OIDC provider redirects to `/callback?code=xxx&state=yyy`
2. GoRouter matches `/callback` route (no redirect — `isLoading` returns null)
3. `completeRedirectIfPresent()` → `_oidcCallbackParams()` → reads `Uri.base.queryParameters` → finds `code` and `state`
4. Token exchange succeeds → `_clearOidcCallbackUrl()` replaces URL with origin
5. Auth state changes to `isLoggedIn: true`
6. GoRouter re-evaluates redirect → `/login`? No, already logged in → `/callback` shows no content → but redirect: `isLoggedIn && path == '/callback'`? No special rule for callback... → `return null` → stays on `/callback`
7. Auth `isLoggedIn` true, path is `/callback` — not `/login`, so redirect returns null

Wait — there's a gap. After callback, the user is on `/callback` which shows nothing. We need the redirect to also redirect away from `/callback` when logged in.

Let me add that to the redirect:

```dart
if (authState.isLoggedIn && (path == '/callback' || path == '/login')) return '/vault';
```

Or more generally:

```dart
if (authState.isLoggedIn && path == '/callback') return '/vault';
if (authState.isLoggedIn && path == '/login') return '/vault';
```

### Contracts

No new contracts. The loading overlay is purely a UI concern.

### Quickstart Guide

See [quickstart.md](./quickstart.md) for validation scenarios.

---

## Phase 2: Tasks

See [tasks.md](./tasks.md) for the ordered task list.

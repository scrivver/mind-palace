---
name: frontend-routing-state-architecture
description: Use when designing, reviewing, or refactoring frontend client-side routing, Riverpod/state management, deep links, auth redirects, route guards, not-found handling, or screen data-loading architecture.
---

# Frontend Routing And State Architecture

Use this skill when working on frontend architecture where route management and state management interact, especially Flutter apps using `go_router` and Riverpod.

## Core Mental Model

Use this model as the default architecture:

```text
URL = user intent
Router = maps intent to screen
State providers = resolve intent into data and app state
Screen = renders state
```

Each route should be able to boot from zero context using only:

- the current URL path
- route path parameters
- query parameters
- global app/session state
- provider-managed domain state

Do not make a route depend on the previous screen or a navigation-only object unless there is a concrete, short-lived transition requirement.

## Route Entry States

Design every route for three entry modes:

- Cold entry: direct URL, refresh, browser restore, SSO return, copied link.
- Warm navigation: user clicked from another page and providers may already have cached data.
- Transition state: auth, service clients, or route data are still resolving.

Cold entry is the architecture test. If `/file/:id`, `/settings`, or `/status` cannot refresh cleanly, state ownership is probably wrong.

## Routing Guidelines

Keep the router stable.

- Do not rebuild `GoRouter` because service/client `FutureProvider`s completed.
- Create the router once when practical.
- Use a `refreshListenable` or equivalent auth refresh mechanism to re-run redirects.
- Let route builders watch providers inside `Consumer` widgets instead of watching async services while constructing the router.

Redirect only for routing, auth, setup, and authorization decisions.

- Do not redirect just because page data is loading.
- Show route-level loading or skeleton UI while data resolves.
- Unknown paths should have explicit not-found handling, not default router errors.
- Route guards should prevent protected screens from mounting before privileged providers fetch data.

## Auth Redirects

Use explicit auth states:

- loading or unknown
- authenticated
- unauthenticated
- error, if the app needs it

Recommended redirect policy:

```text
if auth is loading:
  do not mount privileged routes that can fetch protected data

if route requires setup and setup is incomplete:
  redirect to setup

if route is unknown:
  redirect/render not found

if user is unauthenticated and route requires auth:
  redirect to /login?from=<current-uri>

if user is authenticated and visits /login or /callback:
  redirect to a validated post-login destination or default route

if user lacks authorization for a route:
  redirect/render not found or forbidden, intentionally
```

For SSO, assume the IdP will replace the current app URL. Persist the intended destination before leaving the app.

Recommended SSO return flow:

```text
user opens /status
router redirects to /login?from=/status
user starts SSO
app persists /status in session/local/secure storage
IdP redirects back to /callback
app completes auth
router consumes persisted destination
app clears persisted destination
router lands on /status
```

Always validate stored or query-supplied return URLs.

- Reject absolute URLs or URLs with a host/scheme.
- Reject login/callback/setup as final destinations.
- Reject unknown app routes.
- Fall back to the default authenticated route.

## Authorization And Permission Failures

Do not rely on hidden nav items as authorization.

- Hide nav items for UX.
- Enforce access in the router/route guard.
- Also gate protected route builders so privileged screens do not mount during auth-loading windows.

Decide deliberately between not-found and forbidden.

- Use not-found when the product should not reveal that an admin/private route exists.
- Use forbidden when the product should explain that the user lacks permission.

Do not globally log out on every `401` if backend endpoints may use `401` for permission failures.

- Prefer backend `401` for invalid/expired credentials.
- Prefer backend `403` for authenticated-but-not-authorized.
- Client logout callbacks should be conservative.
- Page-level providers should surface permission errors as page states when possible.

## State Ownership Guidelines

Put state in the URL when it represents shareable or restorable user intent.

Examples:

- selected entity ID
- active tab if meaningful/bookmarkable
- search query
- filters
- sort order
- pagination cursor if user-visible

Put state in providers when it is domain data, shared cache, async status, or cross-screen workflow state.

Examples:

- current auth session
- current user/role
- service clients
- file list data
- file detail data
- storage stats
- admin user list
- upload queue, if uploads should survive navigation

Put state in widget/local state when it is ephemeral UI state.

Examples:

- text editing controller
- focus state
- hover state
- open/closed dropdown
- temporary dialog form values
- local scroll controller

When in doubt, ask: should refresh, browser back, or a copied URL restore this state? If yes, strongly consider URL state.

## Provider Patterns

Prefer route-scoped providers for route-owned data.

Examples:

```dart
final fileDetailProvider = FutureProvider.family<File, String>((ref, fileId) async {
  final service = await ref.watch(fileServiceProvider.future);
  return service.getFile(fileId);
});
```

Use screen providers for screen data that is not path-specific:

```dart
final storageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = await ref.watch(storageServiceProvider.future);
  return service.getStats();
});
```

Avoid one-shot `initState` fetches when a provider can own the loading lifecycle.

- Screens should usually render `AsyncValue` loading/data/error states.
- Refresh actions should invalidate or refresh providers.
- Mutation actions should invalidate affected providers after success.

It is acceptable for screens to keep local state for form controls and transient UI state.

## Screen Contract

Screens should not generally receive large domain objects just because another screen had them.

Prefer:

```text
/file/:fileId -> FileDetailScreen(fileId) -> fileDetailProvider(fileId)
```

Avoid:

```text
Gallery selected object -> FileDetailScreen(initialFile)
```

Passing a lightweight initial object can be acceptable for optimistic transitions, but the route must still be able to reload the canonical data from the URL alone.

## Loading And Error UX

Use the smallest useful loading scope.

- Auth resolving: app-level loading overlay or loading route.
- Service client resolving: page-level loading if only that page needs it.
- Route data resolving: route skeleton or focused spinner.
- Mutation in progress: local button/progress state.

Error handling should match the failure type.

- Unknown route: not-found page.
- Known entity missing: entity-level not-found or page-local missing state.
- Permission denied: forbidden or not-found based on product policy.
- Network/server error: retryable page error.

Do not collapse all errors into logout.

## Query State And Browser History

When syncing search/filter state to URL:

- Debounce text search updates.
- Consider replacing current history entry for high-frequency search edits.
- Consider pushing a new history entry for deliberate filter/tab changes.
- Keep text controllers synchronized from provider/query state.

If browser back becomes noisy, use replacement-style navigation for search edits while preserving normal navigation for page changes.

## Setup And Configuration State

Setup-required state should be reactive.

- Avoid capturing setup flags once inside router construction if they can change at runtime.
- Re-read setup state during redirect evaluation or expose it through a provider.
- After setup changes, invalidate dependent service providers and navigate intentionally.

## Upload Or Workflow State

Cross-route workflow state must be a deliberate product decision.

For upload queues:

- Keep globally if uploads should survive navigation.
- Clear on route exit only if users expect upload state to be abandoned.
- Add explicit clear-completed/clear-all actions when global persistence is used.
- Do not put local file objects or upload progress in URLs.

## Data Accuracy Decisions

Do not present fabricated data as real metrics.

- If backend exposes used bytes but not quota, show “Storage Used”, not “X of 100 GB”.
- If quota/capacity is important, add it to the backend contract first.
- Clearly separate placeholder/design copy from real operational metrics.

## Architecture Decision Checklist

Before implementing a route or screen, answer:

- What URL represents this screen’s intent?
- Which path/query params define its starting state?
- Can this route cold-load after refresh?
- Which provider owns the domain data?
- Which states are loading, empty, error, forbidden, and not-found?
- Does auth-loading accidentally mount protected screens?
- Does SSO preserve the intended destination?
- Does logout happen only for true auth loss?
- Does browser back behave predictably?
- Are any displayed values fabricated or stale?

## Review Heuristics

Flag these as architecture smells:

- A route screen assumes a previous screen passed a populated object.
- `GoRouter` is recreated when service providers complete.
- Unknown routes use the default router error page.
- A hidden nav item is the only admin protection.
- A protected provider fetches before auth/role is known.
- SSO loses the original target route.
- Search/filter UI state is not reflected in URL but should be shareable.
- A screen fetches data in `initState` even though a provider could own it.
- Every `401` logs the user out.
- UI shows capacity/quota values the backend does not provide.

## Recommended Implementation Order

When refactoring an existing app, prefer this order:

1. Stabilize router creation and auth refresh behavior.
2. Preserve login/SSO return destinations.
3. Add explicit known-route and not-found handling.
4. Enforce route-level authorization and protected builder gates.
5. Convert direct-entry routes to route-scoped providers.
6. Move screen-owned fetch state into providers.
7. Decide URL ownership for search/filter/tab state.
8. Tighten permission/error handling and avoid accidental logout.
9. Remove fabricated metrics or make backend contracts explicit.
10. Run analyze/tests and manually test cold-entry URLs.

## Manual Test Cases

For apps with auth and deep links, manually verify:

- Refresh `/settings` while authenticated.
- Open `/status` unauthenticated, password login, land on `/status`.
- Open `/status` unauthenticated, SSO login, land on `/status`.
- Open `/admin` as admin, admin screen loads.
- Open `/admin` as normal user, not-found/forbidden appears and user stays logged in.
- Open an unknown route, not-found appears.
- Open `/file/:id` directly, file loads or shows a precise missing/forbidden state.
- Change gallery search/filter, refresh, state restores from URL.
- Use browser back after gallery search/filter changes.
- Trigger a page-level permission error and confirm it does not log out unless credentials are actually invalid.

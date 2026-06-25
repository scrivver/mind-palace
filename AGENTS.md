# Repository Guidelines

## Project Structure & Module Organization

This repository is a Nix-managed monorepo. The primary Flutter client lives in `app/lib/`, organized into screens, models, and service clients. Shared development infrastructure is defined in `infra/`, with root launchers in `bin/` and shell definitions in `shells/`.

`reliquary/`, `engram/`, and `synapse/` are Git submodules:

- `reliquary/`: Go storage API and Flutter frontend.
- `engram/`: Go API/watcher plus Python ingestion worker.
- `synapse/`: Go reconciliation and transfer workers.

Initialize components with `git submodule update --init --recursive`. Read each component's `README.md` and `CLAUDE.md` before making component-specific changes. Runtime state belongs under `.data/` and must not be committed.

## Build, Test, and Development Commands

Run commands from the repository root unless noted:

- `nix develop`: enter the complete Go, Python, Flutter, and infrastructure environment.
- `dev`: launch PostgreSQL, RabbitMQ, MinIO, Caddy, Authentik, the backends, workers, and primary app with process-compose.
- `start-infra`: start only PostgreSQL, RabbitMQ, MinIO, Caddy, and Authentik for targeted debugging.
- `start-app`: run only the main Flutter Linux client.
- `shutdown-infra`: stop the active process-compose stack without deleting `.data/`.
- `cd app && flutter analyze`: run Dart static analysis.
- `cd app && flutter test`: run Flutter tests.
- `cd reliquary/backend && go test ./...`: run the current Go unit tests.
- `cd engram && bin/test-ingest`: exercise Engram's end-to-end ingestion path.

## Coding Style & Naming Conventions

Use standard formatters: `gofmt` for Go and `dart format .` for Dart. Follow `flutter_lints` from `app/analysis_options.yaml`. Python uses four-space indentation, `snake_case` functions/modules, and type hints where they clarify interfaces. Use `PascalCase` for Dart types, `lowerCamelCase` for Dart members, and idiomatic Go exported/unexported naming. Keep environment variables uppercase, for example `RABBITMQ_AMQP_PORT`.

## Testing Guidelines

Place Go tests beside source as `*_test.go`, Flutter tests under `test/` as `*_test.dart`, and Python tests as `test_*.py`. Add focused tests for changed behavior; use integration scripts when changes cross storage, queues, or databases. Run the relevant component suite before submitting.

## Pubspec Lock JSON

The Nix Flutter build (`nix/app-web.nix`) reads `app/pubspec.lock.json`, not the raw YAML `pubspec.lock`. Regenerate after every `flutter pub` operation:

```bash
./bin/update-pubspec-lock-json
git add app/pubspec.lock.json && git commit -m "app: update pubspec.lock.json"
```

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, often scoped by component, such as `gallery: add tag filter` or `dev shell: add tesseract`. Keep commits focused. For submodule changes, commit inside the submodule first, then update the root pointer explicitly.

Pull requests should explain behavior, list verification commands, link relevant issues, and include screenshots for Flutter UI changes. Call out schema, infrastructure, environment-variable, or submodule updates.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan at
`specs/006-client-routing/plan.md`.
<!-- SPECKIT END -->

<!-- CONVERSATION SUMMARY -->
## Session Summary (2026-06-22)

- Reviewed `specs/003-settings-page/` — plan and spec define a 4-task settings page feature.
- **Implemented Task 2.1 (Avatar section)**: Created `Avatar` model (`app/lib/models/avatar.dart`), `GravatarService` (`app/lib/services/gravatar_service.dart`), wired `AvatarPicker` into `SettingsScreen`. Verified with `flutter analyze` — clean.
- **Reviewed Status screen** (`app/lib/screens/status_screen.dart`): Only hardcoded value is the 100 GB storage capacity placeholder at line 343. All other data comes from real API endpoints (`engram.getStats()`, `reliquary.getStats()`, `engram.getActivity()`). `GravatarService` has a TODO for caching.
- **Stripped Engram stats endpoint**: Removed hardcoded lore fields (`efficiency_pct`, `active_process`, `sync_frequency`, `latency_ms`, `sync_speed_mbps`, `uptime_pct`) from Engram's `GET /api/stats` — kept only real `status`, `total_files`, `files_by_status`. (`engram/backend/internal/model/stats.go`, `engram/backend/internal/api/stats.go`)
- **Cleaned up Status screen**: Removed Engram Engine card, Metric Tiles, and Recent Activity sections; removed unused `EngramService` dependency. Screen now shows only Storage Capacity from Reliquary.
- **Fixed Storage Capacity bug**: Was summing file counts as bytes — now uses `total_size` from Reliquary. (`app/lib/screens/status_screen.dart`)
- **Updated Upload screen to match Stitch design**: Added back arrow button, replaced drop zone icon/text/button to match "Upload Manager (Updated Nav)" design, updated file tiles to show "size • status" format. (`app/lib/screens/upload_screen.dart`)
<!-- END CONVERSATION SUMMARY -->

<!-- NEW SESSION 2026-06-25 -->

## Session Summary (2026-06-25)

### Done
- **SSO redirect URL race fixed** — HTML pre-load `<script>` in `app/web/index.html` strips `/callback?code=...&state=...` from the browser URL and stashes params in `sessionStorage` before Flutter's engine captures the bootstrap URL. Dart's `_oidcCallbackParams()` reads `sessionStorage` first, falls back to `Uri.base`.
- **Caddy bypass for app** — `bin/start-app` now accesses Flutter dev server directly at port 3000, API calls go through Caddy at port 2080 via `--dart-define=DEFAULT_API_BASE_URL=http://localhost:2080`. Caddy dependency removed from `app` process in `flake.nix`.
- **`ServerUrlStore`** updated to read `DEFAULT_API_BASE_URL` dart-define first, then fall back to `http://127.0.0.1:2080` on localhost, empty (same-origin) for production.
- **Theme not applying at runtime** fixed — `onThemeChanged` callback in `app_router.dart` now updates `ref.read(currentThemeProvider.notifier).state = setting`.
- **Gallery screen disposed error** fixed — `Future(() { ... })` in `initState` replaced with `WidgetsBinding.instance.addPostFrameCallback` + `mounted` check.
- **`/settings` initial-route error** fixed — root cause was `main.dart:68-79`: pre-auth code returned a plain `MaterialApp` (not `.router`), which used `WidgetsBinding.instance.platformDispatcher.defaultRouteName` (`/settings`) as `initialRoute`. Flutter's `WidgetsApp._initialRouteName` always prefers `defaultRouteName` over `widget.initialRoute` when they differ from `/`. **Fix:** removed the conditional `MaterialApp`; always use `MaterialApp.router` from the start with a GoRouter that shows a `/loading` route while `AppAuthState.isLoading` is `true`. Changed `AppAuthState` default to `isLoading: true` so GoRouter can distinguish "before-init" from "logged-out".
- **Redirect loop on logout** fixed — `logout()` used `AppAuthState()` which inherited the new `isLoading: true` default, causing `/login→/loading→/loading→/login→/loading→/loading`. Fix: explicit `isLoading: false` in `logout()`.
- **`/loading` redirect no longer falls through to `!isLoggedIn` guard** — added early return `null` for `/loading` while `isLoading` is true, and a separate `if (path == '/loading')` branch for post-loading redirect. Uses a `_pendingRedirect` module-level variable to save the original URL before the loading guard intercepts it (best-effort deep-link preservation across GoRouter instances).
- **Spec 006 complete — client routing fixed** —
  - **Root cause**: `routerProvider` watched `authServiceProvider`/`engramServiceProvider`/`reliquaryServiceProvider`. When those `FutureProvider`s completed, a new `GoRouter` was created which could lose the browser URL and fall back to `initialLocation: '/vault'`.
  - **Fix**: removed all `ref.watch()` on service providers from `routerProvider`. GoRouter is now created once. Added `RouterRefreshNotifier` + `refreshListenable` for auth-based redirect re-evaluation without router recreation.
  - **Route builders** use `Consumer` + `ref.watch()` internally so they rebuild reactively when services become ready — fixes stale loading spinner on initial nav.
  - **ShellRoute builder** watches `appAuthProvider` so the username chip populates after auth completes.
  - **`fileListProvider`** (`FileListNotifier`) accepts late-binding engram via `ref.listen` — calls `loadFiles()`/`loadTags()` when `engramServiceProvider` completes, fixing gallery being empty on initial load.

### Blocked / Open
- Deep-linking during the auth-loading phase (e.g. refresh on `/settings` → land on `/settings` after auth) doesn't work because `_effectiveInitialLocation` may reflect `/loading` URL by the time the post-auth `GoRouter` is created. Low priority — normal flows work correctly.

<!-- END CONVERSATION SUMMARY -->

# Mind Palace Documentation

## Deployment

- **[Dogfood deployment](dogfood-deployment.md)** — Both local-development and packaged-Compose deployment paths, smoke checklist, troubleshooting, and failure report template.
- **`specs/001-dogfood-deployment/`** — Deployment spec, service-boundary decisions, and task tracking.

## Architecture

- **[Reliquary production architecture](reliquary-production-architecture.md)** — Target production topology, current constraints, and required application changes for horizontal API scaling.
- **[Next steps / roadmap](next-steps-plan.md)** — Event contract stabilization, removal of Reliquary archival, explicit Reliquary event emission, and infrastructure cutover phases.

## Component specs

Each feature or cross-cutting change is documented in `specs/` with a spec, plan, and task breakdown:

| Spec | Scope | Status |
|------|-------|--------|
| `specs/001-dogfood-deployment/` | Compose packaging, service boundaries, smoke testing | 89/90 tasks done |
| `specs/002-sanctuary-health/` | Service health status screen, Engram + Reliquary stats | All tasks done |
| `specs/003-settings-page/` | Theme preset selection, password reset, avatar picker | All tasks done |
| `specs/004-frontend-refactoring/` | Riverpod DI, go_router, HomePage elimination, widget extraction | 44/44 tasks done |

## Implementation details

### Flutter app (`app/`)

```
app/lib/
├── main.dart                  Entry point, ProviderScope, MaterialApp.router
├── auth_models.dart           OAuth token models
├── auth_service.dart          Abstract auth interface (web/native)
├── auth_service_web.dart      Web OIDC via Authentik
├── auth_service_native.dart   Desktop OAuth via loopback
├── engram_service.dart        Engram API client (metadata, search, stats)
├── reliquary_service.dart     Reliquary API client (upload, download, delete)
├── upload_file.dart           Abstract upload interface (web/native)
├── upload_file_web.dart       Web multipart upload
├── upload_file_native.dart    Native file-picker upload
├── models/                    Data classes (avatar, tag, etc.)
├── providers/                 Riverpod providers (services, file list, upload, theme)
├── router/app_router.dart     GoRouter config with ShellRoute, auth gates
├── screens/                   Full-page screens (gallery, upload, file detail, settings, status)
├── services/                  Flutter-side services (gravatar, server URL store)
├── theme/                     Theme definitions (4 presets, MaterialApp.router bridge)
├── utils/format.dart          Format utilities (bytes, relative time, MIME icons)
└── widgets/                   Reusable extracted widgets (gallery, upload, file detail)
```

Key providers and their roles:

| Provider | Type | Purpose |
|----------|------|---------|
| `engramServiceProvider` | `FutureProvider<EngramService>` | Engram API client (lazy-init via auth config) |
| `reliquaryServiceProvider` | `FutureProvider<ReliquaryService>` | Reliquary API client (lazy-init via auth config) |
| `appAuthProvider` | `ChangeNotifierProvider<AppAuthNotifier>` | Auth state (logged in/out), login/logout actions |
| `currentThemeProvider` | `StateProvider<ThemeSetting>` | Active theme preset enum |
| `fileListProvider` | `StateNotifierProvider<FileListNotifier, FileListState>` | Gallery files, filters (type/tag), pagination |
| `uploadProvider` | `StateNotifierProvider<UploadNotifier, UploadState>` | Upload queue, progress, completion tracking |

### Go backends

Each backend documents its API surface and events in its own README and `contracts/` directory:

- **Reliquary**: `reliquary/README.md` — storage API, thumbnail worker, event emission.
- **Engram**: `engram/README.md` — metadata API, ingestion worker, file-event contract at `engram/contracts/file-events/README.md`.
- **Synapse**: `synapse/README.md` — transfer worker, reconciler, job queues.

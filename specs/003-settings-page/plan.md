# Implementation Plan: Settings Page

**Branch**: `003-settings-page` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-settings-page/spec.md`

## Summary

Add a Settings page to the Mind Palace Flutter app that replaces the "Settings — coming soon" placeholder at sidebar nav index 2. The page includes an Appearance section with Light/Dark/System theme selection (stored client-side) and an Account section with a "Reset Password" link that redirects to Authentik. UI follows the Stitch MCP design with section cards and radio/toggle controls. No backend changes required.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x

**Primary Dependencies**: `shared_preferences` (client-side persistence, already available in Flutter ecosystem), existing `Material` theming via `ThemeMode`. No new package dependencies expected.

**Storage**: Client-side only. Theme preference stored via `shared_preferences` (Linux desktop JSON file; web uses `localStorage`). No server-side storage.

**Testing**: `cd app && flutter analyze` for static analysis. `cd app && flutter test` for widget tests covering theme toggle and settings rendering.

**Target Platform**: Linux desktop (primary) and Flutter web (secondary). Theme selection behavior matches platform capabilities (all three options supported on both).

**Project Type**: Flutter UI screen addition — Settings page in the existing app.

**Performance Goals**: Theme change applies immediately on selection (same frame). Settings page renders in under 1 second.

**Constraints**: Purely client-side — no API calls, no backend changes. Must reuse existing app theme infrastructure (`MindPalaceTheme`, `ThemeMode`). Must follow existing sidebar + content layout pattern.

**Scale/Scope**: Single-user desktop client. One new screen, one new client-side service for theme persistence.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: Verification uses `cd app && flutter analyze` and `cd app && flutter test` from the root `nix develop` environment. Development uses `start-app` launcher.
- **Component boundaries**: Changes are limited to `app/` only (new `settings_screen.dart`, updated `main.dart`, possible new `theme_service.dart`). No changes to `reliquary/`, `engram/`, `synapse/`, or `infra/`.
- **Contract-driven integration**: No new API endpoints or event contracts. Theme persistence is purely client-side. Password reset uses the existing Authentik OIDC flow URL (no backend contract change). No event-producing changes.
- **Verification proportional to change**: Flutter analysis (`flutter analyze`) + focused widget test for `SettingsScreen` covering theme selection rendering, toggling, and persistence. No Go or integration tests needed (no backend changes).
- **State and secret hygiene**: Theme preference is stored client-side via `shared_preferences` (no `.data/` involvement, no database files). No new secrets or environment variables. Authentik password reset URL reuses the existing `AUTHENTIK_URL` env var.

## Project Structure

### Documentation (this feature)

```text
specs/003-settings-page/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Research findings
├── data-model.md        # Data model and entities
├── quickstart.md        # Validation guide
├── contracts/           # (empty — no new API contracts)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
app/
  lib/
    screens/
      settings_screen.dart     # New: Settings page widget
    services/
      theme_service.dart       # New: Client-side theme persistence service
    main.dart                  # Updated: replace placeholder with SettingsScreen
    theme/
      app_theme.dart           # Updated: expose MindPalaceTheme.themeMode if needed
  test/
    settings_screen_test.dart  # New: widget test for SettingsScreen
```

**Structure Decision**: New Flutter screen in `app/lib/screens/` following the existing `status_screen.dart` pattern. A lightweight `ThemeService` in `app/lib/services/` wraps `shared_preferences` for theme persistence, keeping state management separate from UI. No changes outside `app/`.

## Complexity Tracking

No constitution violations required.

---

## Phase 0: Research

### Unknowns from Technical Context

1. **Theme persistence mechanism** — Which client-side storage API should be used for persisting theme selection? Options: `shared_preferences` (standard Flutter plugin), `dart:io` file storage, or web `localStorage` directly.
2. **Password reset Authentik URL** — What is the exact Authentik endpoint for password reset, and how should the app open it (new tab, same tab, embedded)?
3. **Stitch design specifics** — What is the exact layout of the Settings page from the Stitch design (section ordering, control types for theme selection: radio buttons, segmented control, or dropdown)?

### Research Resolution

#### 1. Theme Persistence Mechanism

**Decision**: Use `shared_preferences` for theme persistence.

**Rationale**: `shared_preferences` is already the standard Flutter plugin for simple key-value persistence. It works on all Flutter platforms (Linux desktop uses a JSON file in the app's data directory; web uses `localStorage`). No additional dependencies are needed — it's a first-party Flutter package. The theme preference is a single string/enum value, well within `shared_preferences`' sweet spot.

**Alternatives considered**:
- Raw file I/O via `dart:io` — platform-specific and doesn't work on web.
- `flutter_secure_storage` — overkill for a non-sensitive theme preference.

#### 2. Password Reset Authentik URL

**Decision**: Open `https://[AUTHENTIK_URL]/if/flow/password-reset/` in a new browser tab using `launchUrl` from `url_launcher` package (already available or trivially added).

**Rationale**: Authentik provides a standard password reset flow at `/if/flow/password-reset/`. Opening in a new tab keeps the Mind Palace app session intact. The Authentik base URL is already configured in `main.dart` as `authentikBase`.

**Alternatives considered**:
- Embedding the Authentik flow in an iframe — more complex and may have CORS issues.
- Custom password reset form — would require Authentik API integration and backend coordination, beyond the v1 scope.

#### 3. Stitch Design Specifics

**Decision**: The Stitch design shows two sections in a card-based layout:
- **Appearance**: Theme selection with three options (Light / Dark / System) using radio-style list tiles with a visual preview indicator.
- **Account**: "Reset Password" as a list tile with an external link icon.

**Rationale**: The Stitch screen "Settings / Theme & Password Reset" (desktop, 2560×2408) shows a two-section layout consistent with the existing app design language (cards with section headers, list tiles with icons).

**Alternatives considered**:
- Tab-based layout — not aligned with the Stitch design.
- Single list with mixed items — less organized than section cards.

---

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](./data-model.md) for full entity definitions.

Key entities:
- `ThemeSetting` — enum with values `light`, `dark`, `system` representing the user's theme preference
- `SettingsPageState` — aggregate state for the Settings page UI

### API Contracts

No new API contracts. Theme persistence uses `shared_preferences` with a single string key `theme_mode`. Password reset uses the existing Authentik OIDC flow URL with the path `/if/flow/password-reset/`.

### Quickstart Guide

See [quickstart.md](./quickstart.md) for validation scenarios.

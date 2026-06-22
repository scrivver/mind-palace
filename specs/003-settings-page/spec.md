# Feature Specification: Settings Page

**Feature Branch**: `003-settings-page`

**Created**: 2026-06-22

**Status**: Draft

**Input**: User description: "Plan for the settings page implementation according to Stitch design. Theme selection can be implemented client-side only, no server storage required."

## User Scenarios & Testing

### User Story 1 - Configure Application Theme (Priority: P1)

As a Mind Palace user, I can open the Settings page from the sidebar and change the application theme (light/dark/system) so the visual appearance matches my preference.

**Why this priority**: Theme selection is the primary reason users will visit Settings. It is purely client-side and has no backend dependency.

**Independent Test**: Navigate to Settings via sidebar, toggle between light and dark themes, and verify the UI updates immediately. Reopen the app and verify the theme persists across restarts.

**Acceptance Scenarios**:

1. **Given** the user is logged into Mind Palace, **When** they click "Settings" in the sidebar, **Then** the Settings page replaces the current view with the Settings dashboard.
2. **Given** the Settings page is displayed, **When** the page loads, **Then** the user sees a "Settings" heading with sections for Appearance and Account.
3. **Given** the Appearance section is visible, **When** the user selects "Light" theme, **Then** the entire application UI updates to light mode immediately.
4. **Given** the Appearance section is visible, **When** the user selects "Dark" theme, **Then** the entire application UI updates to dark mode immediately.
5. **Given** the Appearance section is visible, **When** the user selects "System" theme, **Then** the application follows the system-level theme preference.
6. **Given** the user has selected a theme preference, **When** they close and reopen the app, **Then** the theme preference is remembered and applied on startup.

---

### User Story 2 - Reset Password (Priority: P2)

As a user, I can initiate a password reset from the Settings page so I can update my credentials without leaving the application.

**Why this priority**: Password management is a standard account feature but depends on Authentik configuration rather than the Mind Palace backend.

**Independent Test**: Click the "Reset Password" link in the Settings Account section and verify it redirects to the Authentik password reset flow.

**Acceptance Scenarios**:

1. **Given** the Settings page is displayed, **When** the user views the Account section, **Then** a "Reset Password" link or button is visible.
2. **Given** the user clicks "Reset Password", **When** the action is triggered, **Then** the user is redirected to the Authentik password reset page in a new browser tab.

---

### User Story 3 - Settings Persistence and Responsiveness (Priority: P3)

As a user, I expect Settings changes to take effect immediately and be remembered across sessions.

**Why this priority**: Persistence is critical for theme selection usability.

**Independent Test**: Change theme to dark, refresh the page, and verify dark mode persists without errors.

**Acceptance Scenarios**:

1. **Given** the user has changed a setting, **When** any page in the application is viewed, **Then** the setting change is reflected everywhere (not just on the Settings page).
2. **Given** the user reloads the application, **When** the Settings page loads, **Then** the previously selected theme is applied.

---

### Edge Cases

- What happens when the user rapidly toggles between themes?
- What happens when local storage is unavailable or full?
- What happens when Authentik password reset URL fails to load?
- How does the theme selection UI behave when only two options exist (or when "System" is unsupported on some platforms)?
- Does the theme change affect all screens including Gallery, Status, and Settings itself?

## Requirements

### Functional Requirements

- **FR-001**: The system MUST display a "Settings" navigation item in the sidebar (already exists as placeholder) that navigates to the Settings page when selected.
- **FR-002**: The Settings page MUST display a "Settings" heading with sections for Appearance and Account.
- **FR-003**: The Appearance section MUST provide theme selection options: Light, Dark, and System (follow system preference).
- **FR-004**: Theme selection MUST be stored client-side (no backend API calls) and persist across application restarts.
- **FR-005**: The theme MUST apply immediately when selected, affecting all screens (Gallery, Status, Settings, etc.).
- **FR-006**: The Account section MUST display a "Reset Password" link or button that opens the Authentik password reset URL in a new tab.
- **FR-007**: The Settings page MUST reuse the existing sidebar layout pattern and replace the "Settings — coming soon" placeholder at nav index 2.
- **FR-008**: The Settings page MUST degrade gracefully if local storage is unavailable (fall back to default light theme without crashing).

### Key Entities

- **ThemePreference**: A client-side stored value (light, dark, or system) that determines the application's visual appearance.
- **SettingsSection**: A named grouping of related settings (Appearance, Account) displayed as cards on the Settings page.

### Contracts & Integration Impact

- **Affected Components**: `app/` only. No backend changes required.
- **Contracts**: No new API endpoints. Theme selection is purely client-side using shared preferences or local storage. Password reset uses the existing Authentik OIDC flow URL.
- **State & Migrations**: Theme preference stored in local storage (e.g., `shared_preferences` or `localStorage`). No database migrations.
- **Idempotency/Retry Behavior**: Theme changes are idempotent; password reset is a one-shot redirect.
- **Secrets/Configuration**: No new secrets. Authentik URL already configured in `main.dart`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user can open the Settings page from the sidebar within 1 second.
- **SC-002**: Theme changes take effect immediately (within the same frame) when the user selects a new option.
- **SC-003**: The selected theme persists across application restarts without requiring login.
- **SC-004**: The Settings page renders without errors on first launch and on every subsequent navigation.

## Assumptions

- The sidebar already has a "Settings" item at nav index 2 (confirmed).
- Theme switching is purely client-side and does not require server coordination.
- Password reset is handled by Authentik's existing OIDC flow (no custom password reset implementation needed).
- The application already supports light and dark themes via `MindPalaceTheme.light()` and `MindPalaceTheme.dark()`.
- Desktop layout is the primary target; responsive behavior matches the existing app pattern.
- Client-side storage uses the same mechanism already available in the app (Dart `shared_preferences` or web `localStorage`).

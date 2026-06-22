---

description: "Task list for Settings Page feature"
---

# Tasks: Settings Page

**Input**: Design documents from `specs/003-settings-page/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

- **Root Flutter app**: `app/lib/`, `app/test/`
- Use exact paths from plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add client-side dependency for theme persistence

- [x] T001 Add `shared_preferences` dependency via `flutter pub add shared_preferences` in `app/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Theme persistence service that ALL user stories depend on

- [x] T002 Create `ThemeService` in `app/lib/services/theme_service.dart` wrapping `shared_preferences` for reading/writing the `theme_mode` key, with `getTheme()`, `setTheme(ThemeSetting)`, and a `themeModeStream` for reactive updates

**Checkpoint**: Foundation ready — theme persistence available for UI

---

## Phase 3: User Story 1 — Configure Application Theme (Priority: P1) 🎯 MVP

**Goal**: Display Settings page with Appearance section allowing the user to select Light, Dark, or System theme, persisting the choice across app restarts and applying it immediately to all screens.

**Independent Test**: Navigate to Settings via sidebar, select each theme option, and verify the entire app UI updates accordingly. Close and reopen the app to confirm persistence.

### Implementation for User Story 1

- [x] T003 [P] [US1] Create `SettingsScreen` StatefulWidget with Appearance section containing three radio-list tiles (Light, Dark, System) with icons and labels in `app/lib/screens/settings_screen.dart`
- [x] T004 [US1] Wire SettingsScreen into `app/lib/main.dart`: replace `"Settings — coming soon"` placeholder at `_buildScreen` case 2, add ThemeService initialization, and change `MindPalaceApp.themeMode` from hardcoded `ThemeMode.light` to reactive state driven by `ThemeService`

**Checkpoint**: US1 complete — Settings page renders Appearance section, theme changes apply globally and persist

---

## Phase 4: User Story 2 — Reset Password (Priority: P2)

**Goal**: Display Account section on the Settings page with a "Reset Password" link that opens the Authentik password reset flow in a new tab.

**Independent Test**: Click "Reset Password" and verify Authentik password reset page opens in a new browser tab.

### Implementation for User Story 2

- [x] T005 [US2] Add Account section with "Reset Password" list tile and external link icon to `SettingsScreen` in `app/lib/screens/settings_screen.dart`, opening `$authentikBase/if/flow/password-reset/` via `launchUrl`

**Checkpoint**: US2 complete — Account section visible with working password reset link

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verification, cleanup, and documentation

- [x] T006 Run `cd app && flutter analyze` — fix any static analysis issues
- [x] T007 Write widget test for SettingsScreen in `app/test/settings_screen_test.dart` covering theme selection rendering, theme toggle, and password reset link presence
- [x] T008 Verify no runtime state, secrets, local database files, or `.data/` content are included in the diff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (ThemeService needed for theme persistence)
- **US2 (Phase 4)**: Depends on Phase 3 (SettingsScreen widget must exist)
- **Polish (Phase 5)**: Depends on Phases 3-4 — verification suite

### User Story Dependencies

- **US1 (P1)**: Independent — can start after foundational
- **US2 (P2)**: Depends on US1 (needs SettingsScreen widget to exist)

### Within Each Phase

- [P] tasks within a phase can run in parallel
- Non-[P] tasks run sequentially (dependencies within the phase)

---

## Parallel Execution Examples

### User Story 1

```bash
# T003 and T004 are sequential (screen must exist before wiring)
Task: "Create SettingsScreen widget in app/lib/screens/settings_screen.dart"
Task: "Wire into main.dart"
```

### Polish Phase

```bash
# T006, T007, T008 are independent
Task: "Run flutter analyze"
Task: "Write widget test"
Task: "Verify runtime state check"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (shared_preferences dependency)
2. Complete Phase 2: Foundational (ThemeService)
3. Complete Phase 3: User Story 1 (Appearance section + wire into main.dart)
4. **STOP and VALIDATE**: Test US1 independently — navigate to Settings, toggle themes, verify persistence
5. Demo-ready with core theme configuration

### Incremental Delivery

1. Complete Phases 1-2 → Foundation ready
2. Add US1 → Test independently → **MVP!**
3. Add US2 → Test independently → Password reset added
4. Polish → Verification suite passes

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- MVP scope = Phases 1 + 2 + 3 only (US1 — theme configuration)
- No backend changes required for any task
- `url_launcher` may need to be added via `flutter pub add url_launcher` if not already present

---

## Phase 6: Convergence

**Purpose**: Update feature artifacts to match the final implementation after Stitch-driven design
evolution. All acceptance scenarios, functional requirements, and plan decisions are satisfied in
code; the documents below have drifted from the current state.

- [ ] T009 Update `spec.md` FR-002 and US1/AC2: rename section labels from "Appearance" → "Theme Preference" and "Account" → "Reset Password" to match Stitch design (partial)
- [ ] T010 Update `spec.md` FR-003 and US1/AC3-5: replace Light/Dark/System toggle description with 4-visual-preset model (Mind Palace / Midnight / Warm / Neutral) and card-selector UI (partial)
- [ ] T011 Update `data-model.md` ThemeSetting entity: replace 3-value enum (`light`/`dark`/`system` with `ThemeMode`) with current 4-value enum (`mindPalace`/`midnight`/`warm`/`neutral` with `seedColor`/`brightness`) (partial)
- [ ] T012 Update `plan.md` Phase 0 research resolution #3: replace "radio-style list tiles" wording with card-based visual preset grid matching final Stitch layout (partial)

# Quickstart: Frontend Refactoring Validation

## Prerequisites

- Nix environment: `nix develop`
- App dependencies installed: `cd app && flutter pub get`
- Development server running: `start-app` (or `start-infra` if backend services needed)

## Validation Scenarios

Run these in order after each refactoring step.

### Scenario 1: Static Analysis

```bash
cd /home/chunhou/Dev/mind-palace/app && flutter analyze
```

**Expected**: Zero errors, zero warnings.

### Scenario 2: Existing Tests

```bash
cd /home/chunhou/Dev/mind-palace/app && flutter test
```

**Expected**: All existing tests pass. New tests are added alongside refactored modules.

### Scenario 3: App Start & Navigation

```bash
cd /home/chunhou/Dev/mind-palace && start-app
```

Manual validation:
1. **Server setup screen** appears if no URL configured — URL validation works.
2. **Login screen** appears — OIDC flow completes.
3. **Gallery screen** loads files from Engram API — search and filter work.
4. **File detail** opens when a file is tapped — preview, metadata, actions work.
5. **Upload screen** works — drag-drop and file picker function.
6. **Settings screen** renders — theme toggles apply immediately.
7. **Status screen** shows storage metrics.

**Expected**: All screens render without widget tree errors. No console errors.
All visual layout matches pre-refactoring.

### Scenario 4: Theme Persistence

1. Open Settings → change theme from Light to Dark.
2. Close and reopen the app.
3. Verify the dark theme is applied on restart.

**Expected**: Theme preference persists across sessions.

### Scenario 5: Auth Config Probing

1. Open Settings → change server URL.
2. Verify URL validation works (probes `/api/auth/config`).
3. Verify same validation works from `ServerSetupScreen`.

**Expected**: Both screens use the consolidated `ServerUrlStore.validateUrl()`.

### Scenario 6: Cross-Screen File Invalidation

1. Open Gallery → note a file.
2. Open File Detail for that file → delete it.
3. Go back to Gallery.

**Expected**: Deleted file no longer appears. This works via Riverpod `ref.invalidate(fileListProvider)` rather than the old `refreshTrigger` key.

## Step-by-Step Rollback

If a step fails verification, revert that step's changes and investigate before proceeding:

```
git add -A && git commit -m "004-refactor: step N checkpoint"  # before each step
git reset --hard HEAD~1                                        # if step N fails
```

Each step in the [research.md sequence](./research.md#4-refactoring-sequence) leaves a compilable, runnable state.

## Contracts

No API contracts changed. See [data-model.md](./data-model.md) for internal module boundaries and provider hierarchy.

# Quickstart: Frontend Performance Validation

## Prerequisites

- Nix environment: `nix develop`
- App dependencies installed: `cd app && flutter pub get`
- Development server running: `start-app` (or `start-infra` if backend services needed)

## Validation Scenarios

Run these after all optimization steps.

### Scenario 1: Static Analysis

```bash
cd /home/chunhou/Dev/mind-palace/app && flutter analyze
```

**Expected**: Zero errors, zero warnings.

### Scenario 2: Existing Tests

```bash
cd /home/chunhou/Dev/mind-palace/app && flutter test
```

**Expected**: All existing tests pass. New tests are added for preview caching and gallery keying.

### Scenario 3: Gallery Scroll Performance

```bash
cd /home/chunhou/Dev/mind-palace && start-app
```

Manual validation:
1. Log in and open the gallery with many files.
2. Scroll rapidly up and down.
3. Enable performance overlay (`flutter run --profile` or DevTools) and confirm frames stay near 60 fps.

**Expected**: Smooth scrolling; only visible tiles are built (can be verified by adding temporary logging in `SliverGrid` item builder).

### Scenario 4: File Detail Preview Stability

1. Open a file detail screen for an image or PDF.
2. Trigger a parent rebuild (e.g., toggle a tag, wait for a background refresh, or change window size if that causes rebuild).
3. Observe the preview.

**Expected**: Preview does not flicker or re-download. Network panel shows only one request for the preview.

### Scenario 5: Upload Drag & Progress

1. Open the upload screen.
2. Drag files over the drop zone repeatedly.
3. Upload multiple files.

**Expected**: Drop zone hover animation is smooth. Progress updates do not cause the header or unrelated tiles to rebuild.

### Scenario 6: Admin Search Responsiveness

1. Open the admin screen.
2. Type rapidly in the search field.

**Expected**: Search input stays responsive; filtered list updates without UI freezing.

### Scenario 7: Filter Overlay Draft State

1. Open the gallery.
2. Open the filter overlay.
3. Toggle tags and file types without applying.

**Expected**: The gallery behind the overlay does not rebuild while draft selections change.

## Step-by-Step Rollback

If a step fails verification, revert that step's changes and investigate before proceeding:

```bash
git add -A && git commit -m "005-perf: step N checkpoint"  # before each step
git reset --hard HEAD~1                                      # if step N fails
```

## Contracts

No external contracts changed. See [data-model.md](./data-model.md) for internal provider and keying boundaries.

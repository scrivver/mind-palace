# Quickstart: Settings Page Validation

## Prerequisites

- Flutter development environment (inside `nix develop`)
- Engram and Reliquary services running (via `dev` or `start-app`)

## Validation Scenarios

### Scenario 1: Settings Page Navigation

1. Launch the app
2. Log in via Authentik
3. Click "Settings" in the sidebar
4. **Expected**: The Settings page replaces the content area with a "Settings" heading, Appearance section, and Account section

### Scenario 2: Theme Toggle

1. Open Settings page
2. Click "Dark" in the Appearance section
3. **Expected**: The entire app UI switches to dark mode immediately
4. Click "Light" — switches back to light mode
5. Click "System" — follows OS theme preference

### Scenario 3: Theme Persistence Across Restart

1. Select "Dark" theme in Settings
2. Close and reopen the app
3. **Expected**: The app starts in dark mode
4. Navigate to Settings — "Dark" option is still selected

### Scenario 4: Theme Applies Globally

1. Select a theme in Settings
2. Navigate to Gallery, Status, and other pages
3. **Expected**: All pages reflect the selected theme

### Scenario 5: Password Reset Link

1. Open Settings page
2. Click "Reset Password" in the Account section
3. **Expected**: Authentik password reset page opens in a new browser tab

### Scenario 6: First Launch (No Saved Preference)

1. Clear app data or use a fresh profile
2. Launch the app and navigate to Settings
3. **Expected**: "System" option is selected by default; app follows OS theme

### Scenario 7: Degraded Local Storage

1. Simulate full/inaccessible local storage (platform-dependent)
2. Launch the app and navigate to Settings
3. **Expected**: App falls back to light theme without crashing; Settings page renders normally

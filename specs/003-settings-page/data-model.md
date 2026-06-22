# Data Model: Settings Page

## Key Entities

### ThemeSetting

An enum representing the user's preferred visual appearance.

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `value` | `String` | `"light"`, `"dark"`, `"system"` | Storage value for `shared_preferences` |
| `displayName` | `String` | `"Light"`, `"Dark"`, `"System"` | Human-readable label |
| `icon` | `IconData` | Wi-Fi brightness icons | Material icon shown in radio tile |
| `themeMode` | `ThemeMode` | `ThemeMode.light`, `ThemeMode.dark`, `ThemeMode.system` | Flutter theme mode for applying |

```dart
enum ThemeSetting {
  light(ThemeMode.light, 'Light'),
  dark(ThemeMode.dark, 'Dark'),
  system(ThemeMode.system, 'System');

  final ThemeMode themeMode;
  final String displayName;

  const ThemeSetting(this.themeMode, this.displayName);
}
```

### Persistence

| Key | Type | Description |
|-----|------|-------------|
| `theme_mode` | `String` | Stored in `shared_preferences`; one of `"light"`, `"dark"`, `"system"` |

### SettingsPageState

Local component state for the Settings page UI.

| Field | Type | Description |
|-------|------|-------------|
| `selectedTheme` | `ThemeSetting` | Currently selected/displayed theme |
| `isLoading` | `bool` | True while loading persisted preference on init |
| `themeService` | `ThemeService` | Service for reading/writing theme preference |
| `authService` | `AuthService` | Service for obtaining Authentik base URL |

## State Transitions

```
App Launch
    │
    ▼
ThemeService.init() → reads shared_preferences
    │
    ├── key found → parse value → apply ThemeSetting
    └── key missing → default to ThemeSetting.system
    │
    ▼
User selects theme in SettingsScreen
    │
    ▼
ThemeService.setTheme(setting) → writes shared_preferences
    │
    ▼
App-wide ThemeMode updates via MaterialApp state
```

## Validation Rules

- `theme_mode` value must be one of `"light"`, `"dark"`, `"system"`; default to `"system"` if invalid or missing
- No server-side validation needed — purely client-side

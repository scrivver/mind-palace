# Data Model: Settings Page

## Key Entities

### ThemeSetting

An enum representing the user's preferred visual appearance preset.

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `name` | `String` | `"mindPalace"`, `"midnight"`, `"warm"`, `"neutral"` | Enum variant name (storage key for `shared_preferences`) |
| `displayName` | `String` | `"Mind Palace"`, `"Midnight"`, `"Warm"`, `"Neutral"` | Human-readable label |
| `icon` | `IconData` | Material icons | Icon shown in the card selector |
| `seedColor` | `Color` | Hex color codes | Seed color for Material color scheme generation |
| `brightness` | `Brightness` | `Brightness.light`, `Brightness.dark` | Flutter brightness for theme mode |

```dart
enum ThemeSetting {
  mindPalace('Mind Palace', Icons.language, Color(0xFF6750A4), Brightness.light),
  midnight('Midnight', Icons.nightlight_round, Color(0xFF7C6FF7), Brightness.dark),
  warm('Warm', Icons.wb_sunny, Color(0xFFE63946), Brightness.light),
  neutral('Neutral', Icons.blur_on, Color(0xFF475569), Brightness.light);
}
```

### Persistence

| Key | Type | Description |
|-----|------|-------------|
| `theme_mode` | `String` | Stored in `shared_preferences`; one of `"mindPalace"`, `"midnight"`, `"warm"`, `"neutral"` (uses `ThemeSetting.name`) |

## State Transitions

```
App Launch
    │
    ▼
ThemeService.init() → reads shared_preferences
    │
    ├── key found → parse value → apply ThemeSetting
    └── key missing → default to ThemeSetting.mindPalace
    │
    ▼
User selects theme in SettingsScreen
    │
    ▼
ThemeService.setTheme(setting) → writes shared_preferences + emits to stream
    │
    ▼
currentThemeProvider updates → MaterialApp.router rebuilds with new seed/brightness
```

## Validation Rules

- `theme_mode` value must be one of the `ThemeSetting` enum names; default to `ThemeSetting.mindPalace` if invalid or missing
- No server-side validation needed — purely client-side

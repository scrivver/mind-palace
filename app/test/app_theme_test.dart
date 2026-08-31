import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mind_palace/theme/app_theme.dart';

/// Every style a screen can reach for. Regression guard: styles the theme does
/// not explicitly override used to keep the black baked in by
/// `GoogleFonts.interTextTheme()`, leaving subsection headers (titleMedium)
/// invisible on the dark surface.
const _allStyles = <String>[
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
  'titleMedium',
  'titleSmall',
  'bodyLarge',
  'bodyMedium',
  'bodySmall',
  'labelLarge',
  'labelMedium',
  'labelSmall',
];

TextStyle? _styleOf(TextTheme t, String name) => switch (name) {
  'displayLarge' => t.displayLarge,
  'displayMedium' => t.displayMedium,
  'displaySmall' => t.displaySmall,
  'headlineLarge' => t.headlineLarge,
  'headlineMedium' => t.headlineMedium,
  'headlineSmall' => t.headlineSmall,
  'titleLarge' => t.titleLarge,
  'titleMedium' => t.titleMedium,
  'titleSmall' => t.titleSmall,
  'bodyLarge' => t.bodyLarge,
  'bodyMedium' => t.bodyMedium,
  'bodySmall' => t.bodySmall,
  'labelLarge' => t.labelLarge,
  'labelMedium' => t.labelMedium,
  'labelSmall' => t.labelSmall,
  _ => null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeData lightTheme;
  late ThemeData darkTheme;

  setUpAll(() {
    // Building the theme kicks off google_fonts asset loads that fail offline
    // and surface as unhandled async errors. Only the resolved colors matter
    // here, so keep it offline and swallow those loads in a guarded zone.
    GoogleFonts.config.allowRuntimeFetching = false;
    runZonedGuarded(() {
      lightTheme = MindPalaceTheme.light();
      darkTheme = MindPalaceTheme.dark();
    }, (_, _) {});
  });

  group('MindPalaceTheme text colors follow brightness', () {
    test('dark theme uses onSurface for every text style', () {
      for (final name in _allStyles) {
        expect(
          _styleOf(darkTheme.textTheme, name)?.color,
          darkTheme.colorScheme.onSurface,
          reason: '$name must be readable on the dark surface',
        );
      }
    });

    test('light theme uses onSurface for every text style', () {
      for (final name in _allStyles) {
        expect(
          _styleOf(lightTheme.textTheme, name)?.color,
          lightTheme.colorScheme.onSurface,
          reason: '$name must be readable on the light surface',
        );
      }
    });

    test('subsection header (titleMedium) differs between themes', () {
      expect(
        darkTheme.textTheme.titleMedium!.color,
        isNot(lightTheme.textTheme.titleMedium!.color),
      );
    });
  });
}

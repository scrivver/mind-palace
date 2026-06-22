import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/screens/settings_screen.dart';
import 'package:mind_palace/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(ThemeService themeService, {ThemeSetting currentTheme = ThemeSetting.mindPalace, bool isExternalIdp = false}) {
  return MaterialApp(
    home: SettingsScreen(
      themeService: themeService,
      currentTheme: currentTheme,
      onThemeChanged: (_) {},
      isExternalIdp: isExternalIdp,
      authentikBase: 'http://127.0.0.1:9000',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders Settings heading and sections', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsAtLeast(1));
    expect(find.text('Reset Password'), findsAtLeast(1));
    expect(find.text('Theme Preference'), findsOneWidget);
  });

  testWidgets('shows all 4 theme preset options', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    expect(find.text('Mind Palace'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Midnight'), findsOneWidget);
    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Neutral'), findsOneWidget);
  });

  testWidgets('tapping a theme option changes selection', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();

    final setting = await themeService.getTheme();
    expect(setting, ThemeSetting.midnight);
  });

  testWidgets('shows Reset Password button in Account section',
      (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsAtLeast(1));
  });

  testWidgets('persists selected theme across rebuilds', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Warm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Warm'));
    await tester.pumpAndSettle();

    // Simulate app restart by reading the persisted value for currentTheme
    final persisted = await themeService.getTheme();
    await tester.pumpWidget(
        createTestApp(themeService, currentTheme: persisted));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(themeService.getTheme(), completion(ThemeSetting.warm));
  });
}

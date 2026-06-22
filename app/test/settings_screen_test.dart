import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/screens/settings_screen.dart';
import 'package:mind_palace/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(ThemeService themeService) {
  return MaterialApp(
    home: SettingsScreen(
      themeService: themeService,
      onThemeChanged: (_) {},
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
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('shows Light, Dark, System theme options', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('tapping a theme option changes selection', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final darkSetting = await themeService.getTheme();
    expect(darkSetting, ThemeSetting.dark);
  });

  testWidgets('shows Reset Password link in Account section',
      (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
  });

  testWidgets('persists selected theme across rebuilds', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Rebuild the widget tree to simulate app restart
    await tester.pumpWidget(createTestApp(themeService));
    await tester.pumpAndSettle();

    final theme = await themeService.getTheme();
    expect(theme, ThemeSetting.dark);
  });
}

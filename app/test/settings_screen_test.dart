import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/auth_service.dart';
import 'package:mind_palace/reliquary_service.dart';
import 'package:mind_palace/screens/settings_screen.dart';
import 'package:mind_palace/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends AuthService {
  final String? _provider;
  final String? _username;

  _FakeAuthService({String? provider, String? username})
    : _provider = provider,
      _username = username,
      super(issuer: '', clientId: '');

  @override
  Future<bool> completeRedirectIfPresent() async => false;

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<Map<String, dynamic>?> getIdTokenClaims() async => null;

  @override
  Future<Map<String, dynamic>?> getUserInfo() async => {
    'preferred_username': _username ?? 'admin',
  };

  @override
  Future<bool> isLoggedIn() async => true;

  @override
  Future<bool> isOidc() async => false;

  @override
  Future<bool> isPasswordMode() async => false;

  @override
  Future<bool> login() async => true;

  @override
  Future<bool> loginWithPassword(String username, String password) async =>
      true;

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getProvider() async => _provider;

  @override
  Future<String?> getRole() async => 'admin';

  @override
  Future<String?> getUsername() async => _username ?? 'admin';
}

Widget createTestApp(
  ThemeService themeService, {
  ThemeSetting currentTheme = ThemeSetting.mindPalace,
  String? provider,
}) {
  final auth = _FakeAuthService(provider: provider ?? 'password');
  final reliquary = ReliquaryService(
    auth: auth,
    baseUrl: 'http://localhost:2080/api/reliquary',
  );
  return MaterialApp(
    home: SettingsScreen(
      themeService: themeService,
      currentTheme: currentTheme,
      onThemeChanged: (_) {},
      reliquary: reliquary,
      auth: auth,
      onServerUrlChanged: () {},
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
    expect(find.text('Change Password'), findsAtLeast(1));
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

    // Scroll down to make theme options visible.
    await tester.drag(find.byType(SettingsScreen), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Midnight'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();

    final setting = await themeService.getTheme();
    expect(setting, ThemeSetting.midnight);
  });

  testWidgets('shows Change Password button for password provider', (
    tester,
  ) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService, provider: 'password'));
    await tester.pumpAndSettle();

    expect(find.text('Change Password'), findsAtLeast(1));
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
  });

  testWidgets('shows external IdP message for OIDC provider', (tester) async {
    final themeService = ThemeService();
    await tester.pumpWidget(createTestApp(themeService, provider: 'oidc'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Password management is handled by your external identity provider.',
      ),
      findsOneWidget,
    );
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
      createTestApp(themeService, currentTheme: persisted),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(themeService.getTheme(), completion(ThemeSetting.warm));
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'engram_service.dart';
import 'reliquary_service.dart';
import 'screens/login_view.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/status_screen.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';

const _authentikBase = String.fromEnvironment(
  'AUTHENTIK_URL',
  defaultValue: 'http://127.0.0.1:9000',
);
final String authentikIssuer = '$_authentikBase/application/o/mind-palace/';
const String clientId = 'mind-palace';

const String reliquaryBaseUrl = String.fromEnvironment(
  'RELIQUARY_URL',
  defaultValue: '',
);

const String engramBaseUrl = String.fromEnvironment(
  'ENGRAM_URL',
  defaultValue: '',
);

String get effectiveReliquaryBaseUrl {
  if (reliquaryBaseUrl.isNotEmpty) return reliquaryBaseUrl;
  return kIsWeb ? '/api/reliquary/' : 'http://127.0.0.1:2080/api/reliquary/';
}

String get effectiveEngramBaseUrl {
  if (engramBaseUrl.isNotEmpty) return engramBaseUrl;
  return kIsWeb ? '/api/engram/' : 'http://127.0.0.1:2080/api/engram/';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final themeService = ThemeService();
  runApp(MindPalaceApp(themeService: themeService));
}

class MindPalaceApp extends StatefulWidget {
  final ThemeService themeService;

  const MindPalaceApp({super.key, required this.themeService});

  @override
  State<MindPalaceApp> createState() => _MindPalaceAppState();
}

class _MindPalaceAppState extends State<MindPalaceApp> {
  ThemeSetting _themeSetting = ThemeSetting.mindPalace;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    widget.themeService.themeModeStream.listen((setting) {
      if (mounted) {
        setState(() => _themeSetting = setting);
      }
    });
  }

  Future<void> _loadTheme() async {
    final theme = await widget.themeService.getTheme();
    if (mounted) {
      setState(() => _themeSetting = theme);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mind Palace',
      debugShowCheckedModeBanner: false,
      theme: MindPalaceTheme.light(_themeSetting.seedColor),
      darkTheme: MindPalaceTheme.dark(_themeSetting.seedColor),
      themeMode: _themeSetting.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: HomePage(
        themeService: widget.themeService,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeService themeService;

  const HomePage({super.key, required this.themeService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService(
    issuer: authentikIssuer,
    clientId: clientId,
    engramBaseUrl: effectiveEngramBaseUrl,
  );

  bool _loading = true;
  bool _loggedIn = false;
  String? _username;
  String? _error;
  int _navIndex = 0;

  late final ReliquaryService _reliquary;
  late final EngramService _engram;

  @override
  void initState() {
    super.initState();
    _reliquary = ReliquaryService(
      auth: _auth,
      baseUrl: effectiveReliquaryBaseUrl,
      onUnauthorized: _logout,
    );
    _engram = EngramService(
      auth: _auth,
      baseUrl: effectiveEngramBaseUrl,
      onUnauthorized: _logout,
    );
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.completeRedirectIfPresent();
      final loggedIn = await _auth.isLoggedIn();
      if (loggedIn) {
        final userInfo = await _auth.getUserInfo();
        setState(() {
          _loggedIn = true;
          _username = userInfo?['preferred_username'] as String? ?? 'unknown';
        });
      } else {
        setState(() => _loggedIn = false);
      }
    } catch (e) {
      setState(() {
        _loggedIn = false;
        _error = e.toString();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await _auth.login();
      if (success) {
        final userInfo = await _auth.getUserInfo();
        setState(() {
          _loggedIn = true;
          _username = userInfo?['preferred_username'] as String? ?? 'unknown';
        });
      } else {
        setState(() => _error = 'Login was cancelled or failed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    setState(() {
      _loggedIn = false;
      _username = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_loggedIn) {
      return LoginView(
        onLogin: _login,
        error: _error,
        loading: _loading,
      );
    }

    return _buildAuthenticatedShell();
  }

  Widget _buildAuthenticatedShell() {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(
              selectedIndex: _navIndex,
              onDestinationChanged: (i) => setState(() => _navIndex = i),
              username: _username ?? '',
              onLogout: _logout,
            ),
            Expanded(child: _buildScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_navIndex) {
      case 1:
        return StatusScreen(
          engram: _engram,
          reliquary: _reliquary,
        );
      case 2:
        return SettingsScreen(
          themeService: widget.themeService,
          onThemeChanged: (setting) {},
          authentikBase: _authentikBase,
        );
      default:
        return GalleryScreen(
          engram: _engram,
          reliquary: _reliquary,
          onLogout: _logout,
          username: _username ?? '',
        );
    }
  }
}

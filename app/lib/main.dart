import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'auth_models.dart';
import 'auth_service.dart';
import 'engram_service.dart';
import 'reliquary_service.dart';
import 'models/engram_file.dart';
import 'screens/file_detail_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/login_view.dart';
import 'screens/server_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/status_screen.dart';
import 'screens/upload_screen.dart';
import 'services/server_url_store.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';

const String clientId = 'mind-palace';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On web the desktop_drop plugin may register and attempt to invoke
  // platform channel methods even when we don't use it. Install a no-op
  // handler for the 'desktop_drop' channel to prevent MissingPluginException
  // errors when desktop_drop_web invokes events.
  if (kIsWeb) {
    const channel = MethodChannel('desktop_drop');
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'entered':
        case 'updated':
        case 'exited':
        case 'performOperation_web':
          return null;
        default:
          return null;
      }
    });
  }
  await ServerUrlStore.load();
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
        currentTheme: _themeSetting,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeService themeService;
  final ThemeSetting currentTheme;

  const HomePage({super.key, required this.themeService, required this.currentTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AuthService? _auth;
  ReliquaryService? _reliquary;
  EngramService? _engram;

  bool _loading = true;
  bool _loggedIn = false;
  bool _needsServerSetup = false;
  bool _isOidc = true;
  String? _username;
  String? _error;
  int _navIndex = 0;
  EngramFile? _detailFile;
  int _detailRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _needsServerSetup = !kIsWeb && !ServerUrlStore.hasSavedUrls;
    if (!_needsServerSetup) {
      _initialize();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    String issuer = '';
    String oidcClientId = clientId;
    bool oidcEnabled = true;

    try {
      final configResp = await http.get(
        Uri.parse('${ServerUrlStore.engramBaseUrl}api/auth/config'),
      );
      if (configResp.statusCode == 200) {
        Map<String, dynamic>? body;
        try {
          body = jsonDecode(configResp.body) as Map<String, dynamic>;
        } catch (_) {
          // Non-JSON response (e.g. dev server HTML) — fall through to defaults.
        }
        if (body != null) {
          final authConfig = AuthConfig.fromJson(body);
          oidcEnabled = authConfig.oidc.enabled;
          issuer = oidcEnabled ? authConfig.oidc.issuerUrl : '';
          oidcClientId = oidcEnabled ? authConfig.oidc.clientId : clientId;
        }
      }
    } catch (_) {
      // Server unreachable — on web we fall through with defaults;
      // on native the gate will redirect to server setup below.
    }

    _auth = AuthService(
      issuer: issuer,
      clientId: oidcClientId,
      engramBaseUrl: ServerUrlStore.engramBaseUrl,
    );
    _reliquary = ReliquaryService(
      auth: _auth!,
      baseUrl: ServerUrlStore.reliquaryBaseUrl,
      onUnauthorized: _logout,
    );
    _engram = EngramService(
      auth: _auth!,
      baseUrl: ServerUrlStore.engramBaseUrl,
      onUnauthorized: _logout,
    );
    _isOidc = oidcEnabled;

    try {
      await _auth!.completeRedirectIfPresent();
      final loggedIn = await _auth!.isLoggedIn();
      if (loggedIn) {
        final userInfo = await _auth!.getUserInfo();
        setState(() {
          _loggedIn = true;
          _username = userInfo?['preferred_username'] as String? ?? 'unknown';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        if (!kIsWeb) _needsServerSetup = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onServerConfigured() async {
    _needsServerSetup = false;
    await _initialize();
  }

  Future<void> _onServerUrlChanged() async {
    await _initialize();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await _auth!.login();
      if (success) {
        final userInfo = await _auth!.getUserInfo();
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

  void _showServerSetup() {
    setState(() {
      _needsServerSetup = true;
      _error = null;
    });
  }

  Future<void> _logout() async {
    await _auth?.logout();
    setState(() {
      _loggedIn = false;
      _username = null;
    });
  }

  void _openDetail(EngramFile file) {
    setState(() {
      _detailFile = file;
      _navIndex = 4;
    });
  }

  void _closeDetail({bool deleted = false}) {
    setState(() {
      _detailFile = null;
      _navIndex = 0;
      if (deleted) _detailRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsServerSetup) {
      return ServerSetupScreen(
        initialUrl: ServerUrlStore.baseServerUrl,
        error: _error,
        onConfigured: _onServerConfigured,
      );
    }

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_loggedIn) {
      return LoginView(
        onLogin: _login,
        error: _error,
        loading: _loading,
        onConfigureServer: kIsWeb ? null : _showServerSetup,
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
          reliquary: _reliquary!,
        );
      case 2:
        return SettingsScreen(
          themeService: widget.themeService,
          currentTheme: widget.currentTheme,
          onThemeChanged: (setting) {},
          isExternalIdp: _isOidc,
          onServerUrlChanged: _onServerUrlChanged,
        );
      case 3:
        return UploadScreen(
          reliquary: _reliquary!,
          onLogout: _logout,
          username: _username ?? '',
          onBack: () => setState(() => _navIndex = 0),
        );
      case 4:
        return FileDetailScreen(
          initial: _detailFile!,
          engram: _engram!,
          reliquary: _reliquary!,
          onBack: _closeDetail,
        );
      default:
        return GalleryScreen(
          engram: _engram!,
          reliquary: _reliquary!,
          onLogout: _logout,
          username: _username ?? '',
          onNavigateToUpload: () => setState(() => _navIndex = 3),
          onOpenDetail: _openDetail,
          refreshTrigger: _detailRefreshKey,
        );
    }
  }
}

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'reliquary_service.dart';
import 'screens/gallery_screen.dart';

// Configure these to match your setup.
// In dev, run `source load-infra-env` to get the AUTHENTIK_URL.
const _authentikBase = String.fromEnvironment(
  'AUTHENTIK_URL',
  defaultValue: 'http://127.0.0.1:9000',
);
final String authentikIssuer = '$_authentikBase/application/o/mind-palace/';
const String clientId = 'mind-palace';

const String reliquaryBaseUrl = String.fromEnvironment(
  'RELIQUARY_URL',
  defaultValue: 'http://127.0.0.1:2080',
);

void main() {
  runApp(const MindPalaceApp());
}

class MindPalaceApp extends StatelessWidget {
  const MindPalaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mind Palace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService(
    issuer: authentikIssuer,
    clientId: clientId,
  );

  bool _loading = true;
  bool _loggedIn = false;
  String? _username;
  String? _error;

  late final ReliquaryService _reliquary;

  @override
  void initState() {
    super.initState();
    _reliquary = ReliquaryService(
      auth: _auth,
      baseUrl: reliquaryBaseUrl,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loggedIn) {
      return GalleryScreen(
        reliquary: _reliquary,
        onLogout: _logout,
        username: _username ?? '',
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Mind Palace',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Cold data storage, labeling & retrieval',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _login,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Authentik'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

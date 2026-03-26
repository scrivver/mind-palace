import 'dart:convert';

import 'package:flutter/material.dart';

import 'auth_service.dart';

// Configure these to match your authentik setup.
// In dev, run `source load-infra-env` to get the AUTHENTIK_URL.
const _authentikBase = String.fromEnvironment(
  'AUTHENTIK_URL',
  defaultValue: 'http://127.0.0.1:9000',
);
final String authentikIssuer = '$_authentikBase/application/o/mind-palace/';
const String clientId = 'mind-palace';

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
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _idClaims;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        final idClaims = await _auth.getIdTokenClaims();
        setState(() {
          _loggedIn = true;
          _userInfo = userInfo;
          _idClaims = idClaims;
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
        final idClaims = await _auth.getIdTokenClaims();
        setState(() {
          _loggedIn = true;
          _userInfo = userInfo;
          _idClaims = idClaims;
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
      _userInfo = null;
      _idClaims = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind Palace'),
        actions: [
          if (_loggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loggedIn
              ? _buildUserInfoView()
              : _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    return Center(
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
    );
  }

  Widget _buildUserInfoView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    child: Text(
                      (_userInfo?['preferred_username'] ?? '?')[0]
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userInfo?['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_userInfo?['email'] != null)
                          Text(
                            _userInfo!['email'],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (_userInfo?['preferred_username'] != null)
                          Text(
                            '@${_userInfo!['preferred_username']}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_userInfo != null) ...[
            Text(
              'User Info (from /userinfo)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildJsonCard(_userInfo!),
          ],
          if (_idClaims != null) ...[
            const SizedBox(height: 24),
            Text(
              'ID Token Claims',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildJsonCard(_idClaims!),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonCard(Map<String, dynamic> data) {
    final encoder = const JsonEncoder.withIndent('  ');
    return Card(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            encoder.convert(data),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

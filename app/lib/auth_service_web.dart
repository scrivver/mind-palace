import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_models.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final String issuer;
  final String clientId;
  final String mobileRedirectUrl;
  final String engramBaseUrl;
  final String reliquaryBaseUrl;
  final bool passwordMode;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _idTokenKey = 'id_token';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';
  static const _stateKey = 'oidc_state';
  static const _verifierKey = 'oidc_code_verifier';
  static const _passwordTokenKey = 'password_token';
  static const _providerKey = 'auth_provider';

  AuthConfig? _authConfig;
  Map<String, dynamic>? _oidcDiscovery;

  AuthService({
    required this.issuer,
    required this.clientId,
    this.mobileRedirectUrl = 'com.mindpalace.app://callback',
    this.engramBaseUrl = '/api/engram',
    this.reliquaryBaseUrl = '/api/reliquary',
    this.passwordMode = false,
  });

  Future<bool> completeRedirectIfPresent() async {
    final params = Uri.base.queryParameters;
    final isCallback =
        Uri.base.path.endsWith('/callback') || params.containsKey('code');
    if (!isCallback) {
      return false;
    }

    final expectedState = await _storage.read(key: _stateKey);
    final verifier = await _storage.read(key: _verifierKey);
    final returnedState = params['state'];
    final code = params['code'];

    if (params['error'] != null) {
      throw Exception('SSO provider error: ${params['error']}');
    }
    if (expectedState == null || verifier == null) {
      throw Exception('SSO session expired. Please try again.');
    }
    if (returnedState != expectedState) {
      throw Exception('SSO state mismatch. Please try again.');
    }
    if (code == null || code.isEmpty) {
      throw Exception('Missing authorization code from SSO provider.');
    }

    final cfg = await _getAuthConfig();
    final ok = await _exchangeToken({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': _redirectUri(cfg.oidc),
      'code_verifier': verifier,
      'client_id': cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId,
    });
    await _storage.delete(key: _stateKey);
    await _storage.delete(key: _verifierKey);
    if (!ok) {
      throw Exception('SSO token exchange failed.');
    }
    return true;
  }

  Future<bool> isLoggedIn() async {
    final passwordToken = await _storage.read(key: _passwordTokenKey);
    if (passwordToken != null) return true;
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null) return true;
    return _refreshTokens();
  }

  Future<bool> isOidc() async {
    try {
      final cfg = await _getAuthConfig();
      return cfg.oidc.enabled;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isPasswordMode() async {
    try {
      final cfg = await _getAuthConfig();
      return cfg.password.enabled;
    } catch (_) {
      return passwordMode;
    }
  }

  Future<bool> login() async {
    final cfg = await _getAuthConfig();
    if (cfg.none.enabled) return true;
    if (!cfg.oidc.enabled) return false;

    final discovery = await _discover();
    final authorizationEndpoint =
        discovery['authorization_endpoint'] as String?;
    if (authorizationEndpoint == null || authorizationEndpoint.isEmpty) {
      return false;
    }

    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _generateState();
    await _storage.write(key: _stateKey, value: state);
    await _storage.write(key: _verifierKey, value: verifier);

    final authUrl = Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId,
        'redirect_uri': _redirectUri(cfg.oidc),
        'scope': 'openid profile email offline_access',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    return launchUrl(authUrl, webOnlyWindowName: '_self');
  }

  Future<bool> loginWithPassword(String username, String password) async {
    try {
      final base = reliquaryBaseUrl.endsWith('/')
          ? reliquaryBaseUrl
          : '$reliquaryBaseUrl/';
      final response = await http.post(
        Uri.parse('${base}api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['token'] as String?;
      if (token == null || token.isEmpty) return false;

      await _storage.write(key: _passwordTokenKey, value: token);
      await _storage.write(key: _providerKey, value: 'password');
      final returnedUsername = body['username'] as String?;
      if (returnedUsername != null && returnedUsername.isNotEmpty) {
        await _storage.write(key: _usernameKey, value: returnedUsername);
      }
      final returnedRole = body['role'] as String?;
      if (returnedRole != null && returnedRole.isNotEmpty) {
        await _storage.write(key: _roleKey, value: returnedRole);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _idTokenKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _stateKey);
    await _storage.delete(key: _verifierKey);
    await _storage.delete(key: _passwordTokenKey);
    await _storage.delete(key: _providerKey);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _passwordTokenKey);
    if (token != null) return token;
    final oidcToken = await _storage.read(key: _accessTokenKey);
    if (oidcToken != null) return oidcToken;
    if (await _refreshTokens()) {
      return _storage.read(key: _accessTokenKey);
    }
    return null;
  }

  Future<String?> getProvider() async {
    return _storage.read(key: _providerKey);
  }

  Future<String?> getRole() async {
    return _storage.read(key: _roleKey);
  }

  Future<String?> getUsername() async {
    return _storage.read(key: _usernameKey);
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final username = await _storage.read(key: _usernameKey);
    if (username != null) {
      return {'preferred_username': username};
    }
    return getIdTokenClaims();
  }

  Future<Map<String, dynamic>?> getIdTokenClaims() async {
    final idToken = await _storage.read(key: _idTokenKey);
    if (idToken == null) return null;

    final parts = idToken.split('.');
    if (parts.length != 3) return null;

    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  Future<AuthConfig> _getAuthConfig() async {
    if (_authConfig != null) return _authConfig!;
    final base = reliquaryBaseUrl.endsWith('/')
        ? reliquaryBaseUrl
        : '$reliquaryBaseUrl/';
    final response = await http.get(Uri.parse('${base}api/auth/config'));
    if (response.statusCode != 200) {
      throw Exception('Auth config failed: ${response.statusCode}');
    }
    _authConfig = AuthConfig.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return _authConfig!;
  }

  Future<Map<String, dynamic>> _discover() async {
    if (_oidcDiscovery != null) return _oidcDiscovery!;
    final base = reliquaryBaseUrl.endsWith('/')
        ? reliquaryBaseUrl
        : '$reliquaryBaseUrl/';
    final response = await http.get(
      Uri.parse('${base}api/auth/oidc/discovery'),
    );
    if (response.statusCode != 200) {
      throw Exception('OIDC discovery failed: ${response.statusCode}');
    }
    _oidcDiscovery = jsonDecode(response.body) as Map<String, dynamic>;
    return _oidcDiscovery!;
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return false;
    final cfg = await _getAuthConfig();
    return _exchangeToken({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId,
    });
  }

  Future<bool> _exchangeToken(Map<String, String> payload) async {
    final base = reliquaryBaseUrl.endsWith('/')
        ? reliquaryBaseUrl
        : '$reliquaryBaseUrl/';
    final response = await http.post(
      Uri.parse('${base}api/auth/oidc/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      return false;
    }

    final tokens = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = tokens['access_token'] as String?;
    if (accessToken == null) return false;

    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _providerKey, value: 'oidc');
    await _storage.write(key: _roleKey, value: 'user');
    final refreshToken = tokens['refresh_token'] as String?;
    final idToken = tokens['id_token'] as String?;
    final username = tokens['username'] as String?;
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (idToken != null) {
      await _storage.write(key: _idTokenKey, value: idToken);
    }
    if (username != null && username.isNotEmpty) {
      await _storage.write(key: _usernameKey, value: username);
    }
    return true;
  }

  String _redirectUri(OidcAuthConfig cfg) {
    if (cfg.redirectUri.startsWith('http')) return cfg.redirectUri;
    return '${Uri.base.origin}/callback';
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

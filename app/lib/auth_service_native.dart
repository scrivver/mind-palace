import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth_models.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String issuer;
  String clientId;
  final String mobileRedirectUrl;
  final String engramBaseUrl;
  final String reliquaryBaseUrl;
  final bool passwordMode;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _idTokenKey = 'id_token';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';
  static const _passwordTokenKey = 'password_token';
  static const _providerKey = 'auth_provider';

  Map<String, dynamic>? _oidcConfig;

  AuthService({
    required this.issuer,
    required this.clientId,
    this.mobileRedirectUrl = 'com.mindpalace.app://callback',
    this.engramBaseUrl = '',
    this.reliquaryBaseUrl = '',
    this.passwordMode = false,
  });

  /// Probe a Reliquary server for its auth configuration.
  static Future<AuthConfig> probe(String reliquaryUrl) async {
    final url = reliquaryUrl.endsWith('/') ? reliquaryUrl : '$reliquaryUrl/';
    final response = await http.get(Uri.parse('${url}api/auth/config'));
    if (response.statusCode != 200) {
      throw Exception('Failed to get auth config: ${response.statusCode}');
    }
    return AuthConfig.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  bool get _useAppAuth =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<bool> completeRedirectIfPresent() async => false;

  Future<Map<String, dynamic>> _discover() async {
    if (_oidcConfig != null) return _oidcConfig!;
    final url = issuer.endsWith('/')
        ? '$issuer.well-known/openid-configuration'
        : '$issuer/.well-known/openid-configuration';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('OIDC discovery failed: ${response.statusCode}');
    }
    _oidcConfig = jsonDecode(response.body);
    return _oidcConfig!;
  }

  Future<bool> isLoggedIn() async {
    final passwordToken = await _secureStorage.read(key: _passwordTokenKey);
    if (passwordToken != null) return true;
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null) return false;

    try {
      await getUserInfo();
      return true;
    } catch (_) {
      return await _refreshTokens();
    }
  }

  Future<bool> isOidc() async => issuer.isNotEmpty;

  Future<bool> isPasswordMode() async => passwordMode;

  Future<bool> login() async {
    if (issuer.isEmpty) return false;
    if (_useAppAuth) {
      return _loginWithAppAuth();
    }
    return _loginWithLoopback();
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

      await _secureStorage.write(key: _passwordTokenKey, value: token);
      await _secureStorage.write(key: _providerKey, value: 'password');
      final returnedUsername = body['username'] as String?;
      if (returnedUsername != null && returnedUsername.isNotEmpty) {
        await _secureStorage.write(key: _usernameKey, value: returnedUsername);
      }
      final returnedRole = body['role'] as String?;
      if (returnedRole != null && returnedRole.isNotEmpty) {
        await _secureStorage.write(key: _roleKey, value: returnedRole);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final idToken = await _secureStorage.read(key: _idTokenKey);

    // Clear local tokens first
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _idTokenKey);
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _roleKey);
    await _secureStorage.delete(key: _passwordTokenKey);
    await _secureStorage.delete(key: _providerKey);

    // End the session on authentik
    try {
      final config = await _discover();
      final endSessionEndpoint = config['end_session_endpoint'] as String?;
      if (endSessionEndpoint != null && idToken != null) {
        final logoutUrl = Uri.parse(endSessionEndpoint).replace(
          queryParameters: {
            'id_token_hint': idToken,
            'post_logout_redirect_uri': 'http://127.0.0.1/logged-out',
          },
        );
        await launchUrl(logoutUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Best-effort logout from IdP
    }
  }

  /// Returns the current access token, refreshing if needed.
  /// Returns null if not logged in and refresh fails.
  Future<String?> getAccessToken() async {
    final passwordToken = await _secureStorage.read(key: _passwordTokenKey);
    if (passwordToken != null) return passwordToken;
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token != null) return token;
    if (await _refreshTokens()) {
      return _secureStorage.read(key: _accessTokenKey);
    }
    return null;
  }

  Future<String?> getProvider() async {
    return _secureStorage.read(key: _providerKey);
  }

  Future<String?> getRole() async {
    return _secureStorage.read(key: _roleKey);
  }

  Future<String?> getUsername() async {
    return _secureStorage.read(key: _usernameKey);
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final passwordUsername = await _secureStorage.read(key: _usernameKey);
    if (passwordUsername != null) {
      return {'preferred_username': passwordUsername};
    }
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    if (accessToken == null) return null;

    final config = await _discover();
    final userinfoEndpoint = config['userinfo_endpoint'] as String;

    final response = await http.get(
      Uri.parse(userinfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get user info: ${response.statusCode}');
  }

  Future<Map<String, dynamic>?> getIdTokenClaims() async {
    final idToken = await _secureStorage.read(key: _idTokenKey);
    if (idToken == null) return null;

    final parts = idToken.split('.');
    if (parts.length != 3) return null;

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded);
  }

  // ── Mobile: use flutter_appauth (Android, iOS, macOS) ──

  Future<bool> _loginWithAppAuth() async {
    try {
      const appAuth = FlutterAppAuth();
      final result = await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          mobileRedirectUrl,
          issuer: issuer,
          scopes: ['openid', 'profile', 'email', 'offline_access'],
          allowInsecureConnections: true,
        ),
      );

      await _storeTokensFromAppAuth(result);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Desktop/Web: manual OAuth2 PKCE with loopback server ──

  Future<bool> _loginWithLoopback() async {
    try {
      final config = await _discover();
      final authorizationEndpoint = config['authorization_endpoint'] as String;
      final tokenEndpoint = config['token_endpoint'] as String;

      // Start a local HTTP server to receive the callback
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/callback';

      // Generate PKCE code verifier and challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateState();

      final authUrl = Uri.parse(authorizationEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'scope': 'openid profile email offline_access',
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      debugPrint('Auth URL: $authUrl');
      debugPrint('Redirect URI: $redirectUri');
      debugPrint('Launching browser...');

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        debugPrint('Failed to launch browser');
        await server.close();
        return false;
      }

      debugPrint('Browser launched, waiting for callback on port $port...');

      // Wait for the callback
      String? authCode;
      try {
        final request = await server.first.timeout(const Duration(minutes: 5));

        final uri = request.requestedUri;
        final returnedState = uri.queryParameters['state'];
        authCode = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        if (error != null) {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body><h1>Login failed</h1><p>$error</p>'
              '<p>You can close this tab.</p></body></html>',
            );
          await request.response.close();
          await server.close();
          return false;
        }

        if (authCode == null || returnedState != state) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body><h1>Invalid response</h1>'
              '<p>You can close this tab.</p></body></html>',
            );
          await request.response.close();
          await server.close();
          return false;
        }

        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body><h1>Login successful!</h1>'
            '<p>You can close this tab and return to Mind Palace.</p></body></html>',
          );
        await request.response.close();
      } finally {
        await server.close();
      }

      // Exchange the authorization code for tokens
      final tokenResponse = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': authCode,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        debugPrint(
          'Token exchange failed: ${tokenResponse.statusCode} ${tokenResponse.body}',
        );
        return false;
      }

      final tokens = jsonDecode(tokenResponse.body);
      await _storeTokensFromMap(tokens);
      debugPrint('Login successful!');
      return true;
    } catch (e, stack) {
      debugPrint('Login error: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  // ── Token refresh ──

  Future<bool> _refreshTokens() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final config = await _discover();
      final tokenEndpoint = config['token_endpoint'] as String;

      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
        },
      );

      if (response.statusCode != 200) return false;

      final tokens = jsonDecode(response.body);
      await _storeTokensFromMap(tokens);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Token storage ──

  Future<void> _storeTokensFromAppAuth(TokenResponse result) async {
    if (result.accessToken != null) {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: result.accessToken,
      );
    }
    if (result.refreshToken != null) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: result.refreshToken,
      );
    }
    if (result.idToken != null) {
      await _secureStorage.write(key: _idTokenKey, value: result.idToken);
    }
    await _secureStorage.write(key: _providerKey, value: 'oidc');
    await _secureStorage.write(key: _roleKey, value: 'user');
  }

  Future<void> _storeTokensFromMap(Map<String, dynamic> tokens) async {
    if (tokens['access_token'] != null) {
      await _secureStorage.write(
        key: _accessTokenKey,
        value: tokens['access_token'],
      );
    }
    if (tokens['refresh_token'] != null) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: tokens['refresh_token'],
      );
    }
    if (tokens['id_token'] != null) {
      await _secureStorage.write(key: _idTokenKey, value: tokens['id_token']);
    }
    await _secureStorage.write(key: _providerKey, value: 'oidc');
    await _secureStorage.write(key: _roleKey, value: 'user');
  }

  // ── PKCE helpers ──

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

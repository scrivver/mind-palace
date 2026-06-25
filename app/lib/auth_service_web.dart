import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import 'auth_models.dart';

class AuthService {
  final _WebTokenStorage _storage = _WebTokenStorage();
  final _OAuthParamStorage _oauthParams = _OAuthParamStorage();

  final String issuer;
  final String clientId;
  final String mobileRedirectUrl;
  final String engramBaseUrl;
  final String reliquaryBaseUrl;
  final bool passwordMode;

  static const _accessTokenKey = 'access_token';
  static const _accessTokenExpiresAtKey = 'access_token_expires_at';
  static const _refreshTokenKey = 'refresh_token';
  static const _idTokenKey = 'id_token';
  static const _usernameKey = 'username';
  static const _roleKey = 'role';
  static const _stateKey = 'oidc_state';
  static const _verifierKey = 'oidc_code_verifier';
  static const _oidcIssuerKey = 'oidc_issuer';
  static const _oidcClientIdKey = 'oidc_client_id';
  static const _passwordTokenKey = 'password_token';
  static const _providerKey = 'auth_provider';
  static const _refreshSkew = Duration(minutes: 1);

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
    final params = _oidcCallbackParams();
    if (params.isEmpty) {
      if (Uri.base.path.endsWith('/callback')) _clearOidcCallbackUrl();
      return false;
    }

    try {
      final expectedState = await _oauthParams.read(_stateKey);
      final verifier = await _oauthParams.read(_verifierKey);
      final savedClientId = await _oauthParams.read(_oidcClientIdKey);
      final code = params['code'];
      final returnedState = params['state'];

      if (params['error'] != null ||
          code == null ||
          code.isEmpty ||
          verifier == null ||
          returnedState == null ||
          expectedState == null ||
          returnedState != expectedState) {
        _clearOidcCallbackUrl();
        return false;
      }

      final cfg = await _getAuthConfig();
      final ok = await _exchangeToken({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri(cfg.oidc),
        'code_verifier': verifier,
        'client_id':
            savedClientId ??
            (cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId),
      });
      await _oauthParams.delete(_stateKey);
      await _oauthParams.delete(_verifierKey);
      await _oauthParams.delete(_oidcIssuerKey);
      await _oauthParams.delete(_oidcClientIdKey);
      _clearOidcCallbackUrl();
      return ok;
    } catch (_) {
      _clearOidcCallbackUrl();
      return false;
    }
  }

  Map<String, String> _oidcCallbackParams() {
    final stored = web.window.sessionStorage.getItem('oidc_callback');
    if (stored != null) {
      web.window.sessionStorage.removeItem('oidc_callback');
      final parsed = jsonDecode(stored) as Map<String, dynamic>;
      final code = parsed['code'] as String?;
      final state = parsed['state'] as String?;
      final error = parsed['error'] as String?;
      if (code != null || state != null || error != null) {
        final params = <String, String>{};
        if (code != null) params['code'] = code;
        if (state != null) params['state'] = state;
        if (error != null) params['error'] = error;
        return params;
      }
      return const {};
    }
    final uri = Uri.base;
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    final error = uri.queryParameters['error'];
    if (code == null && state == null && error == null) {
      return const {};
    }
    final params = <String, String>{};
    if (code != null) params['code'] = code;
    if (state != null) params['state'] = state;
    if (error != null) params['error'] = error;
    return params;
  }

  void _clearOidcCallbackUrl() {
    web.window.history.replaceState(null, '', Uri.base.origin);
  }

  Future<bool> isLoggedIn() async {
    final passwordToken = await _storage.read(_passwordTokenKey);
    if (passwordToken != null) return true;
    final token = await _storage.read(_accessTokenKey);
    if (token != null && !await _isAccessTokenExpiring()) return true;
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
    await _oauthParams.write(_stateKey, state);
    await _oauthParams.write(_verifierKey, verifier);
    await _oauthParams.write(_oidcIssuerKey, cfg.oidc.issuerUrl);
    await _oauthParams.write(
      _oidcClientIdKey,
      cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId,
    );

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

      await _storage.write(_passwordTokenKey, token);
      await _storage.write(_providerKey, 'password');
      final returnedUsername = body['username'] as String?;
      if (returnedUsername != null && returnedUsername.isNotEmpty) {
        await _storage.write(_usernameKey, returnedUsername);
      }
      final returnedRole = body['role'] as String?;
      if (returnedRole != null && returnedRole.isNotEmpty) {
        await _storage.write(_roleKey, returnedRole);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(_accessTokenKey);
    await _storage.delete(_accessTokenExpiresAtKey);
    await _storage.delete(_refreshTokenKey);
    await _storage.delete(_idTokenKey);
    await _storage.delete(_usernameKey);
    await _storage.delete(_roleKey);
    await _storage.delete(_stateKey);
    await _storage.delete(_verifierKey);
    await _storage.delete(_oidcIssuerKey);
    await _storage.delete(_oidcClientIdKey);
    await _storage.delete(_passwordTokenKey);
    await _storage.delete(_providerKey);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(_passwordTokenKey);
    if (token != null) return token;
    final oidcToken = await _storage.read(_accessTokenKey);
    if (oidcToken != null && !await _isAccessTokenExpiring()) return oidcToken;
    if (await _refreshTokens()) {
      return _storage.read(_accessTokenKey);
    }
    return null;
  }

  Future<String?> getProvider() async {
    return _storage.read(_providerKey);
  }

  Future<String?> getRole() async {
    return _storage.read(_roleKey);
  }

  Future<String?> getUsername() async {
    return _storage.read(_usernameKey);
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    final username = await _storage.read(_usernameKey);
    if (username != null) {
      return {'preferred_username': username};
    }
    return getIdTokenClaims();
  }

  Future<Map<String, dynamic>?> getIdTokenClaims() async {
    final idToken = await _storage.read(_idTokenKey);
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
    final refreshToken = await _storage.read(_refreshTokenKey);
    if (refreshToken == null) return false;
    final cfg = await _getAuthConfig();
    try {
      return await _exchangeToken({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': cfg.oidc.clientId.isEmpty ? clientId : cfg.oidc.clientId,
      });
    } catch (_) {
      return false;
    }
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
    if (response.statusCode != 200) return false;

    final tokens = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = tokens['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return false;

    await _storage.write(_accessTokenKey, accessToken);
    await _storeAccessTokenExpiry(tokens, accessToken);
    await _storage.write(_providerKey, 'oidc');
    await _storage.write(_roleKey, 'user');
    final refreshToken = tokens['refresh_token'] as String?;
    final idToken = tokens['id_token'] as String?;
    final username = tokens['username'] as String?;
    if (refreshToken != null) {
      await _storage.write(_refreshTokenKey, refreshToken);
    }
    if (idToken != null) {
      await _storage.write(_idTokenKey, idToken);
    }
    if (username != null && username.isNotEmpty) {
      await _storage.write(_usernameKey, username);
    }
    return true;
  }

  Future<bool> _isAccessTokenExpiring() async {
    final raw = await _storage.read(_accessTokenExpiresAtKey);
    final storedExpiresAt = raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
    final token = await _storage.read(_accessTokenKey);
    final expiresAt =
        storedExpiresAt ?? (token == null ? null : _jwtExpiresAt(token));
    if (expiresAt == null) return false;
    final refreshAt = expiresAt.subtract(_refreshSkew);
    return !DateTime.now().isBefore(refreshAt);
  }

  Future<void> _storeAccessTokenExpiry(
    Map<String, dynamic> tokens,
    String accessToken,
  ) async {
    final expiresIn = (tokens['expires_in'] as num?)?.toInt();
    final expiresAt = expiresIn != null && expiresIn > 0
        ? DateTime.now().add(Duration(seconds: expiresIn))
        : _jwtExpiresAt(accessToken);
    if (expiresAt == null) return;
    await _storage.write(
      _accessTokenExpiresAtKey,
      expiresAt.millisecondsSinceEpoch.toString(),
    );
  }

  DateTime? _jwtExpiresAt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = (claims['exp'] as num?)?.toInt();
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
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

class _WebTokenStorage {
  Future<String?> read(String key) async {
    return web.window.localStorage.getItem(key);
  }

  Future<void> write(String key, String value) async {
    web.window.localStorage.setItem(key, value);
  }

  Future<void> delete(String key) async {
    web.window.localStorage.removeItem(key);
  }
}

class _OAuthParamStorage {
  Future<String?> read(String key) async {
    return _readCookie(key) ?? web.window.localStorage.getItem(key);
  }

  Future<void> write(String key, String value) async {
    _setCookie(key, value);
    web.window.localStorage.setItem(key, value);
  }

  Future<void> delete(String key) async {
    _deleteCookie(key);
    web.window.localStorage.removeItem(key);
  }

  String? _readCookie(String name) {
    final cookieHeader = web.document.cookie;
    if (cookieHeader.isEmpty) return null;
    final cookies = cookieHeader.split('; ');
    for (final cookie in cookies) {
      final idx = cookie.indexOf('=');
      if (idx < 0) continue;
      if (cookie.substring(0, idx) == name) {
        return cookie.substring(idx + 1);
      }
    }
    return null;
  }

  void _setCookie(String name, String value) {
    web.document.cookie =
        '$name=$value; path=/; max-age=300; SameSite=Lax; Secure';
  }

  void _deleteCookie(String name) {
    web.document.cookie = '$name=; path=/; max-age=0; SameSite=Lax; Secure';
  }
}

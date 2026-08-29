import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServerUrlStore {
  static const _prefsKey = 'base_server_url';

  static String baseServerUrl = '';
  static bool hasSavedUrls = false;

  static String get engramBaseUrl {
    return '${_norm(baseServerUrl)}api/engram/';
  }

  static String get reliquaryBaseUrl {
    return '${_norm(baseServerUrl)}api/reliquary/';
  }

  /// Origin to build shareable in-app links against, e.g. the `<origin>` in
  /// `<origin>/file/<id>`.
  ///
  /// Prefers the configured server, which in every supported topology also
  /// serves the app. Falls back to the page's own origin for a web build in
  /// relative mode, where [baseServerUrl] is deliberately empty.
  static String get appOrigin {
    final configured = baseServerUrl.trim();
    if (configured.isNotEmpty) {
      final parsed = Uri.tryParse(configured);
      if (parsed != null && parsed.hasScheme) return parsed.origin;
    }
    if (kIsWeb) return Uri.base.origin;
    return '';
  }

  static const String _dartDefineUrl = String.fromEnvironment(
    'DEFAULT_API_BASE_URL',
  );

  static String get _defaultBaseUrl {
    if (_dartDefineUrl.isNotEmpty) return _dartDefineUrl;
    if (!kIsWeb) return 'http://127.0.0.1:2080';
    if (_isLocalhost) return 'http://127.0.0.1:2080';
    return '';
  }

  static bool get _isLocalhost {
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    hasSavedUrls = saved != null && saved.isNotEmpty;
    baseServerUrl = hasSavedUrls ? saved! : _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    baseServerUrl = _norm(url);
    hasSavedUrls = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, baseServerUrl);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    hasSavedUrls = false;
    baseServerUrl = _defaultBaseUrl;
  }

  static Future<bool> validateUrl(String baseUrl) async {
    final probeUrl = engramBaseUrlFromBase(baseUrl);
    try {
      final response = await http.get(Uri.parse('${probeUrl}api/auth/config'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String engramBaseUrlFromBase(String rawBase) {
    return '${_norm(rawBase)}api/engram/';
  }

  static String _norm(String url) {
    url = url.trim();
    if (url.isEmpty) return url;
    if (!url.endsWith('/')) url = '$url/';
    return url;
  }
}

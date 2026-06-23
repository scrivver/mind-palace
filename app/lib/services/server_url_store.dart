import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ServerUrlStore {
  static const _prefsKey = 'base_server_url';

  static String baseServerUrl = '';
  static bool hasSavedUrls = false;

  static String get engramBaseUrl {
    if (kIsWeb) return '/api/engram/';
    return '${_norm(baseServerUrl)}api/engram/';
  }

  static String get reliquaryBaseUrl {
    if (kIsWeb) return '/api/reliquary/';
    return '${_norm(baseServerUrl)}api/reliquary/';
  }

  static String get _defaultBaseUrl =>
      kIsWeb ? '' : 'http://127.0.0.1:2080';

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

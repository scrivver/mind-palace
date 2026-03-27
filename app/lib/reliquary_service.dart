import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// HTTP client for Reliquary API that attaches the Authentik access token
/// and handles 401 responses by refreshing the token and retrying once.
class ReliquaryService {
  final AuthService auth;
  final String baseUrl;

  ReliquaryService({required this.auth, required this.baseUrl});

  /// GET request with auth.
  Future<http.Response> get(String path,
      {Map<String, String>? queryParams}) async {
    return _request('GET', path, queryParams: queryParams);
  }

  /// POST request with auth.
  Future<http.Response> post(String path, {Object? body}) async {
    return _request('POST', path, body: body);
  }

  /// DELETE request with auth.
  Future<http.Response> delete(String path,
      {Map<String, String>? queryParams}) async {
    return _request('DELETE', path, queryParams: queryParams);
  }

  /// PUT request with auth.
  Future<http.Response> put(String path, {Object? body}) async {
    return _request('PUT', path, body: body);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Object? body,
  }) async {
    var token = await auth.getAccessToken();
    if (token == null) {
      throw AuthException('Not logged in');
    }

    var response = await _send(method, path, token,
        queryParams: queryParams, body: body);

    // On 401, try refreshing the token once and retry.
    if (response.statusCode == 401) {
      token = await auth.getAccessToken();
      if (token == null) {
        throw AuthException('Session expired');
      }
      response = await _send(method, path, token,
          queryParams: queryParams, body: body);
    }

    return response;
  }

  Future<http.Response> _send(
    String method,
    String path,
    String token, {
    Map<String, String>? queryParams,
    Object? body,
  }) async {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = {
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'PUT':
        return http.put(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

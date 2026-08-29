import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth_service.dart';
import 'models/file_item.dart';

/// Dio-based client for the Reliquary API.
/// Attaches the Authentik access token and handles 401 with token refresh.
class ReliquaryService {
  final AuthService auth;
  final String baseUrl;
  void Function()? onUnauthorized;
  late final Dio dio;

  // Cache presigned URLs for 10 minutes (they're valid for 15).
  final Map<String, _CachedUrl> _urlCache = {};
  static const _cacheTtl = Duration(minutes: 10);

  /// Origin of baseUrl (scheme://host[:port]), used to resolve server-relative
  /// URLs like `/storage/...` that presigned responses return.
  late final String _origin;

  ReliquaryService({
    required this.auth,
    required String baseUrl,
    this.onUnauthorized,
  }) : baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/' {
    final parsedBaseUrl = Uri.parse(this.baseUrl);
    // Falls back to the page origin for a web build in relative mode, where
    // baseUrl is deliberately scheme-less. Storage URLs must come out absolute:
    // they are now fetched through dio, which would otherwise resolve a bare
    // `/storage/...` against baseUrl rather than against the origin.
    _origin = parsedBaseUrl.hasScheme
        ? parsedBaseUrl.origin
        : (kIsWeb ? Uri.base.origin : '');
    dio = Dio(BaseOptions(baseUrl: this.baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await auth.getAccessToken();
          options.extra['hadAccessToken'] = token != null;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['hadAccessToken'] != true) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<FileListResult> listFiles({int offset = 0, int limit = 50}) async {
    final response = await dio.get(
      '/api/files',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = response.data;
    final files =
        (data['files'] as List?)
            ?.map((f) => FileItem.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];
    return FileListResult(
      files: files,
      totalCount: data['total_count'] as int,
      offset: data['offset'] as int,
      limit: data['limit'] as int,
    );
  }

  Future<({String key, bool duplicate})> uploadFile(
    String filename,
    List<int> bytes,
    String contentType, {
    String? relativePath,
    void Function(int, int)? onProgress,
  }) async {
    final map = <String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    };
    if (relativePath != null) {
      map['path'] = relativePath;
    }
    final formData = FormData.fromMap(map);

    final response = await dio.post(
      '/api/upload',
      data: formData,
      onSendProgress: onProgress,
    );

    return (
      key: response.data['key'] as String,
      duplicate: response.data['duplicate'] == true,
    );
  }

  Future<String> presignDownload(String key) async {
    final cached = _urlCache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.url;
    }

    final response = await dio.get(
      '/api/files/presign',
      queryParameters: {'key': key},
    );
    final relativePath = response.data['url'] as String;
    final url = _origin + relativePath;

    _urlCache[key] = _CachedUrl(
      url: url,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return url;
  }

  Future<String> presignDownloadForSave(String key) async {
    final response = await dio.get(
      '/api/files/presign',
      queryParameters: {'key': key, 'download': 'true'},
    );
    final relativePath = response.data['url'] as String;
    return _origin + relativePath;
  }

  /// Fetches the raw bytes of an object from `/storage/*`.
  ///
  /// Goes through dio so the interceptor attaches the bearer token: Caddy's
  /// forward_auth asks Reliquary to authorize the request before MinIO serves
  /// it, so an unauthenticated fetch — `Image.network`, a bare `http.get`, or
  /// a pasted URL — is rejected. That rejection is the point: it is what stops
  /// a leaked presigned link from working.
  Future<Uint8List> fetchContent(String key, {bool download = false}) async {
    final url = download
        ? await presignDownloadForSave(key)
        : await presignDownload(key);
    final response = await dio.getUri<List<int>>(
      Uri.parse(url),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<void> deleteFile(String key) async {
    await dio.delete('/api/files', queryParameters: {'key': key});
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await dio.get('/api/stats');
    return response.data as Map<String, dynamic>;
  }

  // ── Admin user management ──

  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await dio.get('/api/admin/users');
    return (response.data as List)
        .map((u) => u as Map<String, dynamic>)
        .toList();
  }

  Future<void> createUser(String username, String password) async {
    await dio.post(
      '/api/admin/users',
      data: {'username': username, 'password': password},
    );
  }

  Future<void> deleteUser(String username, {bool permanent = false}) async {
    await dio.delete(
      '/api/admin/users/$username',
      queryParameters: {'permanent': permanent.toString()},
    );
  }

  Future<void> activateUser(String username) async {
    await dio.put('/api/admin/users/$username/activate');
  }

  Future<void> changePassword(String username, String password) async {
    await dio.put(
      '/api/admin/users/$username/password',
      data: {'password': password},
    );
  }
}

class FileListResult {
  final List<FileItem> files;
  final int totalCount;
  final int offset;
  final int limit;

  FileListResult({
    required this.files,
    required this.totalCount,
    required this.offset,
    required this.limit,
  });

  bool get hasMore => offset + files.length < totalCount;
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  _CachedUrl({required this.url, required this.expiresAt});
}

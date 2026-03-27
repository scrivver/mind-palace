import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'models/file_item.dart';

/// Dio-based client for the Reliquary API.
/// Attaches the Authentik access token and handles 401 with token refresh.
class ReliquaryService {
  final AuthService auth;
  final String baseUrl;
  final void Function()? onUnauthorized;
  late final Dio dio;

  // Cache presigned URLs for 10 minutes (they're valid for 15).
  final Map<String, _CachedUrl> _urlCache = {};
  static const _cacheTtl = Duration(minutes: 10);

  ReliquaryService({
    required this.auth,
    required this.baseUrl,
    this.onUnauthorized,
  }) {
    dio = Dio(BaseOptions(baseUrl: baseUrl));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await auth.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  Future<FileListResult> listFiles({int offset = 0, int limit = 50}) async {
    final response = await dio.get('/api/files', queryParameters: {
      'offset': offset,
      'limit': limit,
    });
    final data = response.data;
    final files = (data['files'] as List?)
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
      'file': MultipartFile.fromBytes(bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType)),
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

    final response =
        await dio.get('/api/files/presign', queryParameters: {'key': key});
    final relativePath = response.data['url'] as String;
    final url = baseUrl + relativePath;

    _urlCache[key] =
        _CachedUrl(url: url, expiresAt: DateTime.now().add(_cacheTtl));
    return url;
  }

  Future<String> presignDownloadForSave(String key) async {
    final response = await dio.get('/api/files/presign',
        queryParameters: {'key': key, 'download': 'true'});
    final relativePath = response.data['url'] as String;
    return baseUrl + relativePath;
  }

  Future<void> deleteFile(String key) async {
    await dio.delete('/api/files', queryParameters: {'key': key});
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await dio.get('/api/stats');
    return response.data as Map<String, dynamic>;
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

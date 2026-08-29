import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'models/engram_file.dart';

/// Dio-based client for the Engram API.
/// Attaches the Authentik access token and surfaces 401s via the callback.
class EngramService {
  final AuthService auth;
  final String baseUrl;
  void Function()? onUnauthorized;
  late final Dio dio;

  EngramService({
    required this.auth,
    required String baseUrl,
    this.onUnauthorized,
  }) : baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/' {
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

  Future<List<EngramFile>> listFiles({
    int offset = 0,
    int limit = 50,
    String? query,
    List<String> tags = const [],
    String? fileType,
    DateTime? from,
    DateTime? to,
    String? sort,
    String? scope,
    String? path,
  }) async {
    final params = <String, dynamic>{'offset': offset, 'limit': limit};
    if (scope != null && scope.isNotEmpty) {
      params['scope'] = scope;
    }
    if (path != null && path.isNotEmpty) {
      params['path'] = path;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (tags.isNotEmpty) {
      // Engram expects repeated ?tag=a&tag=b (not tag[]=).
      params['tag'] = tags;
    }
    if (fileType != null && fileType.isNotEmpty) {
      params['type'] = fileType;
    }
    if (from != null) {
      params['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      params['to'] = to.toUtc().toIso8601String();
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }
    final response = await dio.get(
      '/api/files',
      queryParameters: params,
      options: Options(listFormat: ListFormat.multi),
    );
    final data = response.data as List?;
    return (data ?? [])
        .map((f) => EngramFile.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<EngramFile> getFile(String id) async {
    final response = await dio.get('/api/files/$id');
    return EngramFile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Lists the immediate subfolders of [path]. Engram returns the complete set
  /// for that directory — folders are not paginated — with recursive file
  /// counts that honour the same filters as [listFiles].
  Future<List<Map<String, dynamic>>> listFolders({
    String path = '',
    String? query,
    List<String> tags = const [],
    String? fileType,
  }) async {
    final params = <String, dynamic>{};
    if (path.isNotEmpty) {
      params['path'] = path;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (tags.isNotEmpty) {
      params['tag'] = tags;
    }
    if (fileType != null && fileType.isNotEmpty) {
      params['type'] = fileType;
    }
    final response = await dio.get(
      '/api/folders',
      queryParameters: params,
      options: Options(listFormat: ListFormat.multi),
    );
    final data = response.data as List?;
    return (data ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listTags() async {
    final response = await dio.get('/api/tags');
    final data = response.data as List?;
    return (data ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await dio.get('/api/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActivity({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await dio.get(
      '/api/activity',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data as Map<String, dynamic>;
  }
}

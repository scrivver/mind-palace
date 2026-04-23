import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'models/engram_file.dart';

/// Dio-based client for the Engram API.
/// Attaches the Authentik access token and surfaces 401s via the callback.
class EngramService {
  final AuthService auth;
  final String baseUrl;
  final void Function()? onUnauthorized;
  late final Dio dio;

  EngramService({
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

  Future<List<EngramFile>> listFiles({
    int offset = 0,
    int limit = 50,
    String? query,
    List<String> tags = const [],
  }) async {
    final params = <String, dynamic>{
      'offset': offset,
      'limit': limit,
    };
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (tags.isNotEmpty) {
      // Engram expects repeated ?tag=a&tag=b (not tag[]=).
      params['tag'] = tags;
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

  Future<List<Map<String, dynamic>>> listTags() async {
    final response = await dio.get('/api/tags');
    final data = response.data as List?;
    return (data ?? []).cast<Map<String, dynamic>>();
  }
}

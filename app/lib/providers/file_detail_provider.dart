import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/engram_file.dart';
import 'service_providers.dart';

final fileDetailProvider = FutureProvider.family<EngramFile, String>((
  ref,
  fileId,
) async {
  final engram = await ref.watch(engramServiceProvider.future);
  try {
    return await engram.getFile(fileId);
  } on DioException catch (e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 404) {
      throw const FileDetailLoadException(FileDetailLoadFailure.notFound);
    }
    if (statusCode == 401 || statusCode == 403) {
      throw const FileDetailLoadException(FileDetailLoadFailure.forbidden);
    }
    rethrow;
  }
});

enum FileDetailLoadFailure { notFound, forbidden }

class FileDetailLoadException implements Exception {
  final FileDetailLoadFailure failure;

  const FileDetailLoadException(this.failure);
}

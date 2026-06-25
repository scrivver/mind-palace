import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engram_file.dart';
import 'service_providers.dart';

final fileDetailProvider = FutureProvider.family<EngramFile, String>((
  ref,
  fileId,
) async {
  final engram = await ref.watch(engramServiceProvider.future);
  return engram.getFile(fileId);
});

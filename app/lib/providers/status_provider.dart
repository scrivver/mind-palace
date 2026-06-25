import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

final storageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final reliquary = await ref.watch(reliquaryServiceProvider.future);
  return reliquary.getStats();
});

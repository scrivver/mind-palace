import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_providers.dart';

final adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final reliquary = await ref.watch(reliquaryServiceProvider.future);
  return reliquary.listUsers();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) {
  final service = ThemeService();
  ref.onDispose(() => service.dispose());
  return service;
});

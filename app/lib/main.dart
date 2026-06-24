import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'auth_service.dart';
import 'router/app_router.dart';
import 'services/server_url_store.dart';
import 'providers/service_providers.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
    const channel = MethodChannel('desktop_drop');
    channel.setMethodCallHandler((call) async => null);
  }
  await ServerUrlStore.load();
  runApp(const ProviderScope(child: MindPalaceApp()));
}

class MindPalaceApp extends ConsumerStatefulWidget {
  const MindPalaceApp({super.key});

  @override
  ConsumerState<MindPalaceApp> createState() => _MindPalaceAppState();
}

class _MindPalaceAppState extends ConsumerState<MindPalaceApp> {
  bool _authInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeService = ref.read(themeServiceProvider);
    final theme = await themeService.getTheme();
    if (mounted) {
      ref.read(currentThemeProvider.notifier).state = theme;
    }
  }

  Future<void> _initializeAuth(AuthService auth) async {
    await ref.read(appAuthProvider.notifier).initialize(auth);
    if (mounted) {
      setState(() => _authInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSetting = ref.watch(currentThemeProvider);

    ref.listen(authServiceProvider, (prev, next) {
      next.whenData((auth) {
        if (!mounted || _authInitialized) return;
        _initializeAuth(auth);
      });
    });

    if (!_authInitialized) {
      return MaterialApp(
        title: 'Mind Palace',
        debugShowCheckedModeBanner: false,
        theme: MindPalaceTheme.light(themeSetting.seedColor),
        darkTheme: MindPalaceTheme.dark(themeSetting.seedColor),
        themeMode: themeSetting.brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Mind Palace',
      debugShowCheckedModeBanner: false,
      theme: MindPalaceTheme.light(themeSetting.seedColor),
      darkTheme: MindPalaceTheme.dark(themeSetting.seedColor),
      themeMode: themeSetting.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'auth_service.dart';
import 'router/app_router.dart' show routerProvider, routerRefreshNotifier;
import 'services/post_login_redirect_store.dart';
import 'services/server_url_store.dart';
import 'providers/service_providers.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
    const channel = MethodChannel('desktop_drop');
    channel.setMethodCallHandler((call) async => null);
  }
  await ServerUrlStore.load();
  await PostLoginRedirectStore.load();
  runApp(const ProviderScope(child: MindPalaceApp()));
}

class MindPalaceApp extends ConsumerStatefulWidget {
  const MindPalaceApp({super.key});

  @override
  ConsumerState<MindPalaceApp> createState() => _MindPalaceAppState();
}

class _MindPalaceAppState extends ConsumerState<MindPalaceApp> {
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
  }

  @override
  Widget build(BuildContext context) {
    final themeSetting = ref.watch(currentThemeProvider);

    ref.listen(authServiceProvider, (prev, next) {
      next.whenData((auth) {
        if (!mounted) return;
        _initializeAuth(auth);
      });
    });

    ref.listen(appAuthProvider, (prev, next) {
      routerRefreshNotifier.refresh();
    });

    return MaterialApp.router(
      title: 'Mind Palace',
      debugShowCheckedModeBanner: false,
      theme: MindPalaceTheme.light(themeSetting.seedColor),
      darkTheme: MindPalaceTheme.dark(themeSetting.seedColor),
      themeMode: themeSetting.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, child) {
            final isLoading = ref.watch(
              appAuthProvider.select((s) => s.isLoading),
            );
            return Stack(
              children: [
                ?child,
                if (isLoading)
                  const AppLoadingScreen(
                    message: 'Completing sign-in and preparing your routes...',
                  ),
              ],
            );
          },
          child: child,
        );
      },
    );
  }
}

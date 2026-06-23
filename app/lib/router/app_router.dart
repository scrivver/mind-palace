import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/engram_file.dart';
import '../screens/file_detail_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/login_view.dart';
import '../screens/server_setup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/status_screen.dart';
import '../screens/upload_screen.dart';
import '../services/server_url_store.dart';
import '../services/theme_service.dart';
import '../widgets/app_shell.dart';
import '../providers/service_providers.dart';
import '../providers/theme_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  final authState = ref.watch(appAuthProvider);
  final authAsync = ref.watch(authServiceProvider);
  final engramAsync = ref.watch(engramServiceProvider);
  final reliquaryAsync = ref.watch(reliquaryServiceProvider);

  final needsSetup = !ServerUrlStore.hasSavedUrls && !kIsWeb;

  return _createRouter(
    ref,
    themeService,
    authState,
    authAsync,
    engramAsync,
    reliquaryAsync,
    needsSetup,
  );
});

GoRouter _createRouter(
  Ref ref,
  ThemeService themeService,
  AppAuthState authState,
  AsyncValue authAsync,
  AsyncValue engramAsync,
  AsyncValue reliquaryAsync,
  bool needsSetup,
) {
  void _invalidateServices() {
    ref.invalidate(authServiceProvider);
    ref.invalidate(authConfigProvider);
    ref.invalidate(engramServiceProvider);
    ref.invalidate(reliquaryServiceProvider);
  }

  return GoRouter(
    initialLocation: '/vault',
    redirect: (context, state) {
      final path = state.uri.path;
      if (needsSetup && path != '/setup') {
        return '/setup';
      }
      if (!needsSetup && !authState.isLoggedIn &&
          path != '/login' && path != '/setup') {
        return '/login';
      }
      if (authState.isLoggedIn && path == '/login') {
        return '/vault';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          return ServerSetupScreen(
            initialUrl: ServerUrlStore.baseServerUrl,
            onConfigured: () async {
              _invalidateServices();
              final auth = await ref.read(authServiceProvider.future);
              await ref.read(appAuthProvider.notifier).initialize(auth);
              context.go('/vault');
            },
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return LoginView(
            onLogin: () => ref.read(appAuthProvider.notifier).login(),
            error: authState.error,
            loading: authState.isLoading,
            onConfigureServer: kIsWeb
                ? null
                : () => context.go('/setup'),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final segment = state.uri.pathSegments.isNotEmpty
              ? state.uri.pathSegments.first
              : 'vault';
          final navIndex = _navIndexForSegment(segment);
          return AppShell(
            child: child,
            selectedIndex: navIndex,
            username: authState.username ?? '',
            onDestinationChanged: (index) {
              final path = _segmentForNavIndex(index);
              context.go('/$path');
            },
            onLogout: () {
              ref.read(appAuthProvider.notifier).logout();
              context.go('/login');
            },
          );
        },
        routes: [
          GoRoute(
            path: '/vault',
            builder: (context, state) {
              return GalleryScreen(
                engram: engramAsync.valueOrNull!,
                reliquary: reliquaryAsync.valueOrNull!,
                onLogout: () {
                  ref.read(appAuthProvider.notifier).logout();
                  context.go('/login');
                },
                username: authState.username ?? '',
                onNavigateToUpload: () => context.go('/upload'),
                onOpenDetail: (file) => context.go('/file/${file.id}'),
                refreshTrigger: 0,
              );
            },
          ),
          GoRoute(
            path: '/status',
            builder: (context, state) {
              return StatusScreen(
                reliquary: reliquaryAsync.valueOrNull!,
              );
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              return SettingsScreen(
                themeService: themeService,
                currentTheme: ThemeSetting.mindPalace,
                onThemeChanged: (setting) {},
                isExternalIdp: true,
                authentikBase: '',
                onServerUrlChanged: () {
                  _invalidateServices();
                  context.go('/vault');
                },
              );
            },
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) {
              return UploadScreen(
                reliquary: reliquaryAsync.valueOrNull!,
                onLogout: () {
                  ref.read(appAuthProvider.notifier).logout();
                  context.go('/login');
                },
                username: authState.username ?? '',
                onBack: () => context.go('/vault'),
              );
            },
          ),
          GoRoute(
            path: '/file/:fileId',
            builder: (context, state) {
              final fileId = state.pathParameters['fileId']!;
              return FileDetailScreen(
                initial: EngramFile(
                  id: fileId,
                  filename: '',
                  size: 0,
                  hash: '',
                  filePath: '',
                  deviceName: '',
                  status: '',
                  storageType: '',
                  mtime: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
                engram: engramAsync.valueOrNull!,
                reliquary: reliquaryAsync.valueOrNull!,
                onBack: ({bool deleted = false}) => context.go('/vault'),
              );
            },
          ),
        ],
      ),
    ],
  );
}

int _navIndexForSegment(String segment) {
  switch (segment) {
    case 'status':
      return 1;
    case 'settings':
      return 2;
    case 'upload':
      return 3;
    case 'file':
      return 4;
    default:
      return 0;
  }
}

String _segmentForNavIndex(int index) {
  switch (index) {
    case 1:
      return 'status';
    case 2:
      return 'settings';
    case 3:
      return 'upload';
    case 4:
      return 'file';
    default:
      return 'vault';
  }
}

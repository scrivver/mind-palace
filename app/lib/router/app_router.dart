import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/engram_file.dart';
import '../screens/admin_screen.dart';
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
    ref.invalidate(reliquaryAuthConfigProvider);
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
      if (!needsSetup &&
          !authState.isLoggedIn &&
          path != '/login' &&
          path != '/setup') {
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
          final authAsyncValue = ref.read(authServiceProvider);
          final isPasswordMode = authAsyncValue.whenOrNull(
                data: (auth) => auth.passwordMode,
              ) ??
              false;
          final isOidcMode = authAsyncValue.whenOrNull(
                data: (auth) => auth.issuer.isNotEmpty,
              ) ??
              false;
          return LoginView(
            onLogin: () => ref.read(appAuthProvider.notifier).login(),
            onPasswordLogin: (username, password) async {
              await ref
                  .read(appAuthProvider.notifier)
                  .loginWithPassword(username, password);
            },
            isPasswordMode: isPasswordMode,
            isOidcMode: isOidcMode,
            error: authState.error,
            loading: authState.isLoading,
            onConfigureServer: kIsWeb ? null : () => context.go('/setup'),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final segment = state.uri.pathSegments.isNotEmpty
              ? state.uri.pathSegments.first
              : 'vault';
          final isAdmin = authState.isAdmin;
          final navIndex = _navIndexForSegment(segment, isAdmin);
          return AppShell(
            child: child,
            selectedIndex: navIndex,
            username: authState.username ?? '',
            isAdmin: isAdmin,
            onDestinationChanged: (index) {
              final path = _segmentForNavIndex(index, isAdmin);
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
                onNavigateToUpload: () => context.go('/upload'),
                onOpenDetail: (file) => context.go('/file/${file.id}'),
                refreshTrigger: 0,
              );
            },
          ),
          GoRoute(
            path: '/status',
            builder: (context, state) {
              return StatusScreen(reliquary: reliquaryAsync.valueOrNull!);
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              final themeSetting = ref.read(currentThemeProvider);
              final reliquary = reliquaryAsync.valueOrNull;
              final auth = authAsync.valueOrNull;
              return SettingsScreen(
                themeService: themeService,
                currentTheme: themeSetting,
                onThemeChanged: (setting) {
                  themeService.setTheme(setting);
                },
                reliquary: reliquary!,
                auth: auth!,
                onServerUrlChanged: () {
                  _invalidateServices();
                  context.go('/vault');
                },
              );
            },
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) {
              final reliquary = reliquaryAsync.valueOrNull!;
              return AdminScreen(reliquary: reliquary);
            },
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) {
              return UploadScreen(
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
                onBack: ({bool deleted = false}) => context.go('/vault'),
              );
            },
          ),
        ],
      ),
    ],
  );
}

int _navIndexForSegment(String segment, bool isAdmin) {
  switch (segment) {
    case 'status':
      return 1;
    case 'settings':
      return 2;
    case 'admin':
      return 3;
    case 'upload':
      return isAdmin ? 4 : 3;
    case 'file':
      return isAdmin ? 5 : 4;
    default:
      return 0;
  }
}

String _segmentForNavIndex(int index, bool isAdmin) {
  switch (index) {
    case 1:
      return 'status';
    case 2:
      return 'settings';
    case 3:
      return isAdmin ? 'admin' : 'upload';
    case 4:
      return isAdmin ? 'upload' : 'file';
    case 5:
      return 'file';
    default:
      return 'vault';
  }
}

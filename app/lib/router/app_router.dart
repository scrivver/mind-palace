import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../widgets/app_shell.dart';
import '../providers/service_providers.dart';
import '../providers/theme_provider.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerRefreshNotifier = RouterRefreshNotifier();

final routerProvider = Provider<GoRouter>((ref) {
  final needsSetup = !ServerUrlStore.hasSavedUrls && !kIsWeb;

  void invalidateServices() {
    ref.invalidate(authServiceProvider);
    ref.invalidate(reliquaryAuthConfigProvider);
    ref.invalidate(engramServiceProvider);
    ref.invalidate(reliquaryServiceProvider);
  }

  return GoRouter(
    initialLocation: '/vault',
    refreshListenable: routerRefreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(appAuthProvider);
      final path = state.uri.path;
      if (authState.isLoading) return null;
      if (needsSetup && path != '/setup') return '/setup';
      if (!authState.isLoggedIn && path != '/login' && path != '/setup') return '/login';
      if (authState.isLoggedIn && (path == '/login' || path == '/callback')) return '/vault';
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          return ServerSetupScreen(
            initialUrl: ServerUrlStore.baseServerUrl,
            onConfigured: () async {
              invalidateServices();
              final auth = await ref.read(authServiceProvider.future);
              await ref.read(appAuthProvider.notifier).initialize(auth);
              context.go('/vault');
            },
          );
        },
      ),
      GoRoute(
        path: '/callback',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final auth = ref.read(authServiceProvider).valueOrNull;
          final authState = ref.read(appAuthProvider);
          final isPasswordMode = auth?.passwordMode ?? false;
          final isOidcMode = auth?.issuer.isNotEmpty ?? false;
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
          return Consumer(builder: (context, ref, _) {
            final authState = ref.watch(appAuthProvider);
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
          });
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
              return Consumer(builder: (context, ref, _) {
                final reliquary = ref.watch(reliquaryServiceProvider).valueOrNull;
                if (reliquary == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StatusScreen(reliquary: reliquary);
              });
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              return Consumer(builder: (context, ref, _) {
                final reliquary = ref.watch(reliquaryServiceProvider).valueOrNull;
                final auth = ref.watch(authServiceProvider).valueOrNull;
                if (reliquary == null || auth == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final themeService = ref.watch(themeServiceProvider);
                final themeSetting = ref.watch(currentThemeProvider);
                return SettingsScreen(
                  themeService: themeService,
                  currentTheme: themeSetting,
                  onThemeChanged: (setting) {
                    themeService.setTheme(setting);
                    ref.read(currentThemeProvider.notifier).state = setting;
                  },
                  reliquary: reliquary,
                  auth: auth,
                  onServerUrlChanged: () {
                    invalidateServices();
                    context.go('/vault');
                  },
                );
              });
            },
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) {
              return Consumer(builder: (context, ref, _) {
                final reliquary = ref.watch(reliquaryServiceProvider).valueOrNull;
                if (reliquary == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return AdminScreen(reliquary: reliquary);
              });
            },
          ),
          GoRoute(
            path: '/upload',
            builder: (context, state) {
              return UploadScreen(onBack: () => context.go('/vault'));
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
});

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

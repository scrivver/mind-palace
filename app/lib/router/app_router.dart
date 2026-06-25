import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/admin_screen.dart';
import '../screens/file_detail_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/login_view.dart';
import '../screens/not_found_screen.dart';
import '../screens/server_setup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/status_screen.dart';
import '../screens/upload_screen.dart';
import '../services/post_login_redirect_store.dart';
import '../services/server_url_store.dart';
import '../widgets/app_loading_screen.dart';
import '../widgets/app_shell.dart';
import '../providers/service_providers.dart';
import '../providers/theme_provider.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerRefreshNotifier = RouterRefreshNotifier();

final routerProvider = Provider<GoRouter>((ref) {
  void invalidateServices() {
    ref.invalidate(authServiceProvider);
    ref.invalidate(reliquaryAuthConfigProvider);
    ref.invalidate(engramServiceProvider);
    ref.invalidate(reliquaryServiceProvider);
  }

  return GoRouter(
    initialLocation: '/vault',
    refreshListenable: routerRefreshNotifier,
    errorBuilder: (context, state) =>
        NotFoundScreen(onGoHome: () => context.go('/vault')),
    redirect: (context, state) {
      final authState = ref.read(appAuthProvider);
      final path = state.uri.path;
      final isAdminPath =
          state.uri.pathSegments.isNotEmpty &&
          state.uri.pathSegments.first == 'admin';
      final needsSetup = !ServerUrlStore.hasSavedUrls && !kIsWeb;
      if (authState.isLoading) return null;
      if (needsSetup && path != '/setup') return '/setup';
      if (!_isKnownRoute(state.uri)) return '/not-found';
      if (!authState.isLoggedIn && path != '/login' && path != '/setup') {
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }
      if (authState.isLoggedIn && isAdminPath && !authState.isAdmin) {
        return '/not-found';
      }
      if (authState.isLoggedIn && (path == '/login' || path == '/callback')) {
        return _safePostLoginPath(
          state.uri.queryParameters['from'] ?? PostLoginRedirectStore.take(),
        );
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
              invalidateServices();
              final auth = await ref.read(authServiceProvider.future);
              await ref.read(appAuthProvider.notifier).initialize(auth);
              if (!context.mounted) return;
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
          final returnTo = _safePostLoginPath(
            state.uri.queryParameters['from'],
          );
          return LoginView(
            onLogin: () => ref
                .read(appAuthProvider.notifier)
                .login(returnTo: returnTo == '/vault' ? null : returnTo),
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
      GoRoute(
        path: '/not-found',
        builder: (context, state) =>
            NotFoundScreen(onGoHome: () => context.go('/vault')),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(
            builder: (context, ref, _) {
              final authState = ref.watch(appAuthProvider);
              if (authState.isLoading) {
                return const AppLoadingScreen(
                  message: 'Restoring your session...',
                );
              }
              final segment = state.uri.pathSegments.isNotEmpty
                  ? state.uri.pathSegments.first
                  : 'vault';
              final isAdmin = authState.isAdmin;
              final navIndex = _navIndexForSegment(segment, isAdmin);
              return AppShell(
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
                child: child,
              );
            },
          );
        },
        routes: [
          GoRoute(
            path: '/vault',
            builder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              final type = state.uri.queryParameters['type'];
              final tags = (state.uri.queryParameters['tags'] ?? '')
                  .split(',')
                  .where((tag) => tag.isNotEmpty)
                  .toSet();
              return GalleryScreen(
                onNavigateToUpload: () => context.go('/upload'),
                onOpenDetail: (file) => context.go('/file/${file.id}'),
                initialSearchQuery: query,
                initialType: type,
                initialTags: tags,
                onRouteStateChanged:
                    ({
                      required searchQuery,
                      required selectedType,
                      required selectedTags,
                    }) {
                      final params = <String, String>{};
                      if (searchQuery.isNotEmpty) params['q'] = searchQuery;
                      if (selectedType != null && selectedType != 'all') {
                        params['type'] = selectedType;
                      }
                      if (selectedTags.isNotEmpty) {
                        params['tags'] = selectedTags.join(',');
                      }
                      context.go(
                        Uri(path: '/vault', queryParameters: params).toString(),
                      );
                    },
                refreshTrigger: 0,
              );
            },
          ),
          GoRoute(
            path: '/status',
            builder: (context, state) {
              return const StatusScreen();
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  final reliquary = ref
                      .watch(reliquaryServiceProvider)
                      .valueOrNull;
                  final authState = ref.watch(appAuthProvider);
                  if (reliquary == null) {
                    return const AppLoadingScreen(
                      title: 'Loading Settings',
                      message: 'Connecting to your Reliquary...',
                    );
                  }
                  final themeService = ref.watch(themeServiceProvider);
                  final themeSetting = ref.watch(currentThemeProvider);
                  return SettingsScreen(
                    currentTheme: themeSetting,
                    onThemeChanged: (setting) {
                      themeService.setTheme(setting);
                      ref.read(currentThemeProvider.notifier).state = setting;
                    },
                    reliquary: reliquary,
                    username: authState.username,
                    provider: authState.provider,
                    onServerUrlChanged: () {
                      invalidateServices();
                      context.go('/vault');
                    },
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  final authState = ref.watch(appAuthProvider);
                  if (authState.isLoading || !authState.isAdmin) {
                    return const AppLoadingScreen(
                      title: 'Checking Access',
                      message: 'Verifying admin permissions...',
                    );
                  }
                  return const AdminScreen();
                },
              );
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
                fileId: fileId,
                onBack: ({bool deleted = false}) => context.go('/vault'),
                onUnavailable: () => context.go('/not-found'),
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

String _safePostLoginPath(String? from) {
  if (from == null || from.isEmpty) return '/vault';
  final uri = Uri.tryParse(from);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !from.startsWith('/')) {
    return '/vault';
  }
  if (uri.path == '/login' || uri.path == '/callback' || uri.path == '/setup') {
    return '/vault';
  }
  if (!_isKnownRoute(uri)) return '/vault';
  return from;
}

bool _isKnownRoute(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.isEmpty) return false;
  if (segments.length == 1) {
    return switch (segments.first) {
      'setup' ||
      'callback' ||
      'login' ||
      'not-found' ||
      'vault' ||
      'status' ||
      'settings' ||
      'admin' ||
      'upload' => true,
      _ => false,
    };
  }
  return segments.length == 2 &&
      segments.first == 'file' &&
      segments.last.isNotEmpty;
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

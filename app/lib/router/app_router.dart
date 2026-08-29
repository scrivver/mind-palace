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
import '../providers/file_list_provider.dart';
import '../providers/service_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/gallery/gallery_view_model.dart';

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
      StatefulShellRoute.indexedStack(
        // Each branch keeps its own Navigator alive inside an IndexedStack, so
        // switching sections is an index change rather than a rebuild: screens
        // keep their scroll offset, filters, and already-loaded previews.
        builder: (context, state, navigationShell) {
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
                  // goBranch restores where the branch was left rather than
                  // resetting it to the section's root.
                  navigationShell.goBranch(
                    _branchForSegment(_segmentForNavIndex(index, isAdmin)),
                  );
                },
                onLogout: () {
                  ref.read(appAuthProvider.notifier).logout();
                  context.go('/login');
                },
                child: navigationShell,
              );
            },
          );
        },
        branches: [
          // Order must match the _branch* constants below.
          StatefulShellBranch(
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
                  final galleryRoute = GalleryRouteState.fromQuery(
                    state.uri.queryParameters,
                  );
                  return GalleryScreen(
                    onNavigateToUpload: () => StatefulNavigationShell.of(
                      context,
                    ).goBranch(_branchUpload),
                    // Pushed rather than gone-to so the gallery stays mounted
                    // underneath and returning restores it as it was.
                    onOpenDetail: (file) => context.push('/file/${file.id}'),
                    initialSearchQuery: query,
                    initialType: type,
                    initialTags: tags,
                    initialViewMode: galleryRoute.viewMode,
                    initialGroupingMode: galleryRoute.groupingMode,
                    initialFolderPath: galleryRoute.folderPath.path,
                    onRouteStateChanged:
                        ({
                          required searchQuery,
                          required selectedType,
                          required selectedTags,
                          required viewMode,
                          required groupingMode,
                          required folderPath,
                        }) {
                          final params = GalleryRouteState(
                            searchQuery: searchQuery,
                            selectedType: selectedType,
                            selectedTags: selectedTags,
                            viewMode: viewMode,
                            groupingMode: groupingMode,
                            folderPath: GalleryFolderPath(folderPath),
                          ).toQueryParameters();
                          context.go(
                            Uri(
                              path: '/vault',
                              queryParameters: params,
                            ).toString(),
                          );
                        },
                    refreshTrigger: 0,
                  );
                },
              ),
              GoRoute(
                path: '/file/:fileId',
                builder: (context, state) {
                  final fileId = state.pathParameters['fileId']!;
                  return FileDetailScreen(
                    fileId: fileId,
                    onBack: ({bool deleted = false}) {
                      // The gallery is still mounted below, so a delete has to
                      // be pushed into the list rather than waiting for the
                      // rebuild that no longer happens.
                      if (deleted) {
                        ref.read(fileListProvider.notifier).invalidate();
                      }
                      // A deep link straight to a file has nothing to pop back
                      // to.
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/vault');
                      }
                    },
                    onUnavailable: () => context.go('/not-found'),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/status',
                builder: (context, state) {
                  return const StatusScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
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
                          ref.read(currentThemeProvider.notifier).state =
                              setting;
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
            ],
          ),
          StatefulShellBranch(
            routes: [
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
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upload',
                builder: (context, state) {
                  return UploadScreen(
                    onBack: () => StatefulNavigationShell.of(
                      context,
                    ).goBranch(_branchVault),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Branch indices for the shell's IndexedStack. These must stay in the same
/// order as the `branches` list above.
const int _branchVault = 0;
const int _branchStatus = 1;
const int _branchSettings = 2;
const int _branchAdmin = 3;
const int _branchUpload = 4;

int _branchForSegment(String segment) {
  switch (segment) {
    case 'status':
      return _branchStatus;
    case 'settings':
      return _branchSettings;
    case 'admin':
      return _branchAdmin;
    case 'upload':
      return _branchUpload;
    default:
      return _branchVault;
  }
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

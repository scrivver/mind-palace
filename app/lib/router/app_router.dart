import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_service.dart';
import '../engram_service.dart';
import '../models/engram_file.dart';
import '../reliquary_service.dart';
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

AppAuthState _lastAuthState = const AppAuthState(isLoading: true);

class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _authRefreshProvider = Provider<Listenable>((ref) {
  final notifier = _AuthRefreshNotifier();
  ref.listen(appAuthProvider, (_, next) {
    _lastAuthState = next;
    notifier.refresh();
  });
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_authRefreshProvider);
  final themeService = ref.watch(themeServiceProvider);
  final authService = ref.watch(
    authServiceProvider.select((a) => a.valueOrNull),
  );
  final engramService = ref.watch(
    engramServiceProvider.select((a) => a.valueOrNull),
  );
  final reliquaryService = ref.watch(
    reliquaryServiceProvider.select((a) => a.valueOrNull),
  );

  final needsSetup = !ServerUrlStore.hasSavedUrls && !kIsWeb;

  return _createRouter(
    ref,
    themeService,
    authService,
    engramService,
    reliquaryService,
    needsSetup,
    refreshNotifier,
  );
});

String? _pendingRedirect;

GoRouter _createRouter(
  Ref ref,
  ThemeService themeService,
  AuthService? authService,
  EngramService? engramService,
  ReliquaryService? reliquaryService,
  bool needsSetup,
  Listenable refreshNotifier,
) {
  AppAuthState _auth() => _lastAuthState;

  void _invalidateServices() {
    ref.invalidate(authServiceProvider);
    ref.invalidate(reliquaryAuthConfigProvider);
    ref.invalidate(engramServiceProvider);
    ref.invalidate(reliquaryServiceProvider);
  }

  String? _loadingTarget() {
    final target = _pendingRedirect;
    _pendingRedirect = null;
    return target;
  }

  return GoRouter(
    initialLocation: '/vault',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = _auth();
      final path = state.uri.path;
      if (needsSetup && path != '/setup') {
        return '/setup';
      }
      if (authState.isLoading) {
        if (path != '/loading') {
          _pendingRedirect = path;
          return '/loading';
        }
        return null;
      }
      if (path == '/loading') {
        return _loadingTarget() ?? '/vault';
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
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
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
        path: '/callback',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final auth = ref.read(authServiceProvider).valueOrNull;
          final authState = _auth();
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
          final authState = _auth();
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
              return StatusScreen(reliquary: reliquaryService!);
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              final themeSetting = ref.read(currentThemeProvider);
              return SettingsScreen(
                themeService: themeService,
                currentTheme: themeSetting,
                onThemeChanged: (setting) {
                  themeService.setTheme(setting);
                  ref.read(currentThemeProvider.notifier).state = setting;
                },
                reliquary: reliquaryService!,
                auth: authService!,
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
              return AdminScreen(reliquary: reliquaryService!);
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

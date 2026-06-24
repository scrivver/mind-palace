import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../auth_models.dart';
import '../auth_service.dart';
import '../engram_service.dart';
import '../reliquary_service.dart';
import '../services/server_url_store.dart';

final serverUrlReadyProvider = FutureProvider<void>((ref) async {
  await ServerUrlStore.load();
});

final reliquaryAuthConfigProvider = FutureProvider<AuthConfig>((ref) async {
  await ref.watch(serverUrlReadyProvider.future);
  final configResp = await http.get(
    Uri.parse('${ServerUrlStore.reliquaryBaseUrl}api/auth/config'),
  );
  if (configResp.statusCode == 200) {
    return AuthConfig.fromJson(
      jsonDecode(configResp.body) as Map<String, dynamic>,
    );
  }
  return AuthConfig(
    password: PasswordAuthConfig(enabled: false),
    oidc: OidcAuthConfig(
      enabled: false,
      issuerUrl: '',
      clientId: '',
      usernameClaim: 'preferred_username',
      redirectUri: '/callback',
    ),
    none: NoneAuthConfig(enabled: true),
  );
});

final authServiceProvider = FutureProvider<AuthService>((ref) async {
  AuthConfig config;
  try {
    config = await ref.watch(reliquaryAuthConfigProvider.future);
  } catch (_) {
    config = AuthConfig(
      password: PasswordAuthConfig(enabled: false),
      oidc: OidcAuthConfig(
        enabled: true,
        issuerUrl: '',
        clientId: '',
        usernameClaim: 'preferred_username',
        redirectUri: '/callback',
      ),
      none: NoneAuthConfig(enabled: false),
    );
  }
  final issuer = config.oidc.enabled ? config.oidc.issuerUrl : '';
  final clientId = config.oidc.enabled ? config.oidc.clientId : 'mind-palace';
  return AuthService(
    issuer: issuer,
    clientId: clientId,
    passwordMode: config.password.enabled,
    engramBaseUrl: ServerUrlStore.engramBaseUrl,
    reliquaryBaseUrl: ServerUrlStore.reliquaryBaseUrl,
  );
});

final engramServiceProvider = FutureProvider<EngramService>((ref) async {
  final auth = await ref.watch(authServiceProvider.future);
  return EngramService(
    auth: auth,
    baseUrl: ServerUrlStore.engramBaseUrl,
    onUnauthorized: () => ref.read(appAuthProvider.notifier).logout(),
  );
});

final reliquaryServiceProvider = FutureProvider<ReliquaryService>((ref) async {
  final auth = await ref.watch(authServiceProvider.future);
  return ReliquaryService(
    auth: auth,
    baseUrl: ServerUrlStore.reliquaryBaseUrl,
    onUnauthorized: () => ref.read(appAuthProvider.notifier).logout(),
  );
});

class AppAuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? username;
  final String? role;
  final String? provider;
  final String? error;
  final AuthService? authService;

  const AppAuthState({
    this.isLoading = true,
    this.isLoggedIn = false,
    this.username,
    this.role,
    this.provider,
    this.error,
    this.authService,
  });

  bool get isAdmin => role == 'admin';

  AppAuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? username,
    String? role,
    String? provider,
    String? error,
    AuthService? authService,
  }) {
    return AppAuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      username: username ?? this.username,
      role: role ?? this.role,
      provider: provider ?? this.provider,
      error: error,
      authService: authService ?? this.authService,
    );
  }
}

class AppAuthNotifier extends StateNotifier<AppAuthState> {
  AppAuthNotifier() : super(const AppAuthState());

  Future<void> initialize(AuthService auth) async {
    state = state.copyWith(isLoading: true, error: null, authService: auth);
    try {
      await auth.completeRedirectIfPresent();
    } catch (_) {
      // completeRedirectIfPresent catches its own errors; this catches
      // only unexpected failures from isLoggedIn/getUserInfo etc.
    }
    final loggedIn = await auth.isLoggedIn();
    if (loggedIn) {
      final userInfo = await auth.getUserInfo();
      final role = await auth.getRole();
      final provider = await auth.getProvider();
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        username: userInfo?['preferred_username'] as String? ?? 'unknown',
        role: role,
        provider: provider,
      );
    } else {
      state = state.copyWith(isLoading: false, isLoggedIn: false);
    }
  }

  Future<void> login() async {
    final auth = state.authService;
    if (auth == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await auth.login();
      if (success) {
        final userInfo = await auth.getUserInfo();
        final role = await auth.getRole();
        final provider = await auth.getProvider();
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          username: userInfo?['preferred_username'] as String? ?? 'unknown',
          role: role,
          provider: provider,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Login was cancelled or failed',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loginWithPassword(String username, String password) async {
    final auth = state.authService;
    if (auth == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await auth.loginWithPassword(username, password);
      if (success) {
        final userInfo = await auth.getUserInfo();
        final role = await auth.getRole();
        final provider = await auth.getProvider();
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          username: userInfo?['preferred_username'] as String? ?? 'unknown',
          role: role,
          provider: provider,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid username or password',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    final auth = state.authService;
    await auth?.logout();
    state = AppAuthState(isLoading: false, isLoggedIn: false, authService: auth);
  }
}

final appAuthProvider = StateNotifierProvider<AppAuthNotifier, AppAuthState>((
  ref,
) {
  return AppAuthNotifier();
});

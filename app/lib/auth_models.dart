class AuthConfig {
  final PasswordAuthConfig password;
  final OidcAuthConfig oidc;
  final NoneAuthConfig none;

  const AuthConfig({
    required this.password,
    required this.oidc,
    required this.none,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      password: PasswordAuthConfig.fromJson(
        (json['password'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      oidc: OidcAuthConfig.fromJson(
        (json['oidc'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      none: NoneAuthConfig.fromJson(
        (json['none'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class PasswordAuthConfig {
  final bool enabled;

  const PasswordAuthConfig({required this.enabled});

  factory PasswordAuthConfig.fromJson(Map<String, dynamic> json) {
    return PasswordAuthConfig(enabled: json['enabled'] == true);
  }
}

class OidcAuthConfig {
  final bool enabled;
  final String issuerUrl;
  final String clientId;
  final String usernameClaim;
  final String redirectUri;

  const OidcAuthConfig({
    required this.enabled,
    required this.issuerUrl,
    required this.clientId,
    required this.usernameClaim,
    required this.redirectUri,
  });

  factory OidcAuthConfig.fromJson(Map<String, dynamic> json) {
    return OidcAuthConfig(
      enabled: json['enabled'] == true,
      issuerUrl: (json['issuer_url'] as String?) ?? '',
      clientId: (json['client_id'] as String?) ?? '',
      usernameClaim:
          (json['username_claim'] as String?) ?? 'preferred_username',
      redirectUri: (json['redirect_uri'] as String?) ?? '/callback',
    );
  }
}

class NoneAuthConfig {
  final bool enabled;

  const NoneAuthConfig({required this.enabled});

  factory NoneAuthConfig.fromJson(Map<String, dynamic> json) {
    return NoneAuthConfig(enabled: json['enabled'] == true);
  }
}

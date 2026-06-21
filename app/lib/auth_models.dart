class AuthConfig {
  final OidcAuthConfig oidc;
  final NoneAuthConfig none;

  const AuthConfig({required this.oidc, required this.none});

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      oidc: OidcAuthConfig.fromJson(
        (json['oidc'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      none: NoneAuthConfig.fromJson(
        (json['none'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
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

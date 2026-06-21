import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/auth_models.dart';

void main() {
  test('AuthConfig parses Engram OIDC helper response', () {
    final config = AuthConfig.fromJson({
      'oidc': {
        'enabled': true,
        'issuer_url': 'http://localhost:2080/application/o/mind-palace/',
        'client_id': 'mind-palace',
        'username_claim': 'preferred_username',
        'redirect_uri': 'http://localhost:2080/callback',
      },
      'none': {'enabled': false},
    });

    expect(config.oidc.enabled, isTrue);
    expect(config.oidc.clientId, 'mind-palace');
    expect(config.oidc.redirectUri, 'http://localhost:2080/callback');
    expect(config.none.enabled, isFalse);
  });

  test('AuthConfig treats missing OIDC fields as disabled defaults', () {
    final config = AuthConfig.fromJson(const {});

    expect(config.oidc.enabled, isFalse);
    expect(config.oidc.usernameClaim, 'preferred_username');
    expect(config.none.enabled, isFalse);
  });
}

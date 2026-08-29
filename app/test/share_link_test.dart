import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/services/server_url_store.dart';

void main() {
  tearDown(() => ServerUrlStore.baseServerUrl = '');

  group('ServerUrlStore.appOrigin', () {
    test('uses the configured server origin', () {
      ServerUrlStore.baseServerUrl = 'http://localhost:2080/';

      expect(ServerUrlStore.appOrigin, 'http://localhost:2080');
    });

    test('drops any path from the configured base', () {
      ServerUrlStore.baseServerUrl = 'https://palace.example.com/mind/';

      expect(ServerUrlStore.appOrigin, 'https://palace.example.com');
    });

    test(
      'ignores a base with no scheme rather than emitting a broken link',
      () {
        ServerUrlStore.baseServerUrl = 'palace.example.com';

        expect(ServerUrlStore.appOrigin, isNot(contains('palace.example.com')));
      },
    );
  });

  group('shared file link', () {
    // The link points at the app route, never at /storage: a presigned URL is
    // authorized per-request at the proxy now, so a pasted one fails for
    // everybody, including the person who copied it.
    test('is an in-app route, not a storage URL', () {
      ServerUrlStore.baseServerUrl = 'http://localhost:2080/';
      const id = '123c70a1-010f-4213-abc5-5ac602ba14a8';

      final link = '${ServerUrlStore.appOrigin}/file/$id';

      expect(link, 'http://localhost:2080/file/$id');
      expect(link, isNot(contains('/storage/')));
      expect(link, isNot(contains('X-Amz-Signature')));
    });
  });
}

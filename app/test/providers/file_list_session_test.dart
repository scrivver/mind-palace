import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/auth_service.dart';
import 'package:mind_palace/engram_service.dart';
import 'package:mind_palace/models/engram_file.dart';
import 'package:mind_palace/providers/file_list_provider.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService()
    : super(
        issuer: 'test',
        clientId: 'test',
        mobileRedirectUrl: 'test://callback',
        engramBaseUrl: 'http://localhost:2080/api/engram/',
      );
}

EngramFile _file(String owner) {
  final now = DateTime(2026, 1, 1);
  return EngramFile(
    id: '$owner-1',
    filename: '$owner.pdf',
    size: 1,
    hash: 'h',
    filePath: 'files/$owner/$owner.pdf',
    deviceName: 'd',
    status: 'ready',
    storageType: 'hot',
    mtime: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeEngram extends EngramService {
  _FakeEngram(this.owner)
    : super(auth: _FakeAuthService(), baseUrl: 'http://localhost:2080');

  final String owner;
  int listFilesCalls = 0;

  @override
  Future<List<EngramFile>> listFiles({
    int offset = 0,
    int limit = 50,
    String? query,
    List<String> tags = const [],
    String? fileType,
    DateTime? from,
    DateTime? to,
    String? sort,
    String? scope,
    String? path,
  }) async {
    listFilesCalls++;
    return [_file(owner)];
  }

  @override
  Future<List<Map<String, dynamic>>> listFolders({
    String path = '',
    String? query,
    List<String> tags = const [],
    String? fileType,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listTags() async => [
    {'name': '$owner-tag'},
  ];
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('signing out drops the listing and re-arms the initial load', () async {
    final engram = _FakeEngram('alice');
    final notifier = FileListNotifier(engram, true);

    notifier.loadInitialIfReady();
    await settle();
    expect(notifier.state.files.single.id, 'alice-1');
    expect(notifier.state.availableTags, isNotEmpty);

    notifier.setLoggedIn(false);
    expect(notifier.state.files, isEmpty, reason: 'listing dropped on logout');
    expect(notifier.state.availableTags, isEmpty);

    // A different user signing in on the same tab must trigger a real fetch,
    // not fall through the _didLoadInitial latch onto the stale listing.
    final before = engram.listFilesCalls;
    notifier.setLoggedIn(true);
    await settle();
    expect(engram.listFilesCalls, greaterThan(before));
    expect(notifier.state.files, isNotEmpty);
  });

  test('a replaced service reloads; the same instance does not', () async {
    final engram = _FakeEngram('alice');
    final notifier = FileListNotifier(engram, true);

    notifier.loadInitialIfReady();
    await settle();
    final afterInitial = engram.listFilesCalls;

    // Riverpod re-emitting the same service must not refetch.
    notifier.setEngram(engram);
    await settle();
    expect(engram.listFilesCalls, afterInitial);

    // A reconfigured server URL builds a new service: the old server's
    // listing is meaningless, so this must reload.
    final replacement = _FakeEngram('bob');
    notifier.setEngram(replacement);
    await settle();
    expect(replacement.listFilesCalls, 1);
    expect(notifier.state.files.single.id, 'bob-1');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/auth_service.dart';
import 'package:mind_palace/models/engram_file.dart';
import 'package:mind_palace/reliquary_service.dart';
import 'package:mind_palace/widgets/gallery/file_tile.dart';

class _MockAuthService extends AuthService {
  _MockAuthService()
      : super(
          issuer: 'test',
          clientId: 'test',
          mobileRedirectUrl: 'test://callback',
          engramBaseUrl: 'http://localhost:2080/api/engram/',
        );
}

class _MockReliquary extends ReliquaryService {
  _MockReliquary()
      : super(
          auth: _MockAuthService(),
          baseUrl: 'http://localhost:2080',
        );

  @override
  Future<String> presignDownload(String key) async =>
      'https://example.com/$key';

  @override
  Future<String> presignDownloadForSave(String key) async =>
      'https://example.com/$key';
}

Widget createTestApp(EngramFile file) {
  return MaterialApp(
    home: Scaffold(
      body: FileTile(
        file: file,
        reliquary: _MockReliquary(),
        onTap: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('FileTile shows filename, size, and type badge', (tester) async {
    final file = EngramFile(
      id: 'test-1',
      filename: 'document.pdf',
      size: 1024 * 50,
      hash: 'abc123',
      filePath: 'files/test/document.pdf',
      deviceName: 'laptop',
      status: 'active',
      storageType: 's3',
      mtime: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: 'application/pdf',
      tags: ['important'],
    );

    await tester.pumpWidget(createTestApp(file));
    await tester.pumpAndSettle();

    expect(find.text('document.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('50.0 KB'), findsOneWidget);
  });

  testWidgets('FileTile shows IMG badge for images', (tester) async {
    final file = EngramFile(
      id: 'test-2',
      filename: 'photo.png',
      size: 2048 * 500,
      hash: 'def456',
      filePath: 'files/test/photo.png',
      deviceName: 'phone',
      status: 'active',
      storageType: 's3',
      mtime: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: 'image/png',
    );

    await tester.pumpWidget(createTestApp(file));
    await tester.pumpAndSettle();

    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('IMG'), findsOneWidget);
  });

  testWidgets('FileTile uses ValueKey(file.id)', (tester) async {
    final file = EngramFile(
      id: 'keyed-file',
      filename: 'keyed.txt',
      size: 100,
      hash: 'key123',
      filePath: 'files/test/keyed.txt',
      deviceName: 'laptop',
      status: 'active',
      storageType: 's3',
      mtime: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: 'text/plain',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FileTile(
          key: ValueKey(file.id),
          file: file,
          reliquary: _MockReliquary(),
          onTap: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is FileTile && widget.key == ValueKey(file.id),
      ),
      findsOneWidget,
    );
  });

  testWidgets('FileTile calls onTap when tapped', (tester) async {
    bool tapped = false;
    final file = EngramFile(
      id: 'test-3',
      filename: 'notes.txt',
      size: 100,
      hash: 'ghi789',
      filePath: 'files/test/notes.txt',
      deviceName: 'laptop',
      status: 'active',
      storageType: 's3',
      mtime: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: 'text/plain',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FileTile(
          file: file,
          reliquary: _MockReliquary(),
          onTap: () => tapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('notes.txt'));
    expect(tapped, isTrue);
  });
}

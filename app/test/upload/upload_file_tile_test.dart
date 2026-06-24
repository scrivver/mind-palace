import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mind_palace/widgets/upload/upload_file_tile.dart';
import 'package:mind_palace/widgets/upload/upload_progress.dart';

Widget createTestApp({
  required PlatformFile file,
  UploadProgress? progress,
  VoidCallback? onRemove,
}) {
  return MaterialApp(
    home: Scaffold(
      body: UploadFileTile(file: file, progress: progress, onRemove: onRemove),
    ),
  );
}

void main() {
  testWidgets('UploadFileTile shows filename and size', (tester) async {
    final file = PlatformFile(
      name: 'report.pdf',
      size: 1024 * 200,
      path: '/tmp/report.pdf',
    );

    await tester.pumpWidget(createTestApp(file: file));
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('200.0 KB'), findsOneWidget);
    expect(find.textContaining('Pending'), findsOneWidget);
  });

  testWidgets('UploadFileTile shows done state', (tester) async {
    final file = PlatformFile(
      name: 'photo.png',
      size: 1024 * 50,
      path: '/tmp/photo.png',
    );
    final progress = const UploadProgress(status: 'Completed', done: true);

    await tester.pumpWidget(createTestApp(file: file, progress: progress));
    await tester.pumpAndSettle();

    expect(find.text('photo.png'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('UploadFileTile shows error state', (tester) async {
    final file = PlatformFile(
      name: 'bad_file.zip',
      size: 100,
      path: '/tmp/bad_file.zip',
    );
    final progress = const UploadProgress(
      status: 'Failed: network error',
      error: true,
    );

    await tester.pumpWidget(createTestApp(file: file, progress: progress));
    await tester.pumpAndSettle();

    expect(find.text('bad_file.zip'), findsOneWidget);
    expect(find.textContaining('Failed: network error'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('UploadFileTile calls onRemove', (tester) async {
    bool removed = false;
    final file = PlatformFile(
      name: 'temp.txt',
      size: 50,
      path: '/tmp/temp.txt',
    );

    await tester.pumpWidget(
      createTestApp(file: file, onRemove: () => removed = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });
}

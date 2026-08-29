import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/models/engram_file.dart';
import 'package:mind_palace/providers/file_list_provider.dart';
import 'package:mind_palace/widgets/gallery/file_row.dart';
import 'package:mind_palace/widgets/gallery/folder_row.dart';
import 'package:mind_palace/widgets/gallery/folder_tile.dart';
import 'package:mind_palace/widgets/gallery/gallery_view_model.dart';

EngramFile file({
  required String id,
  required String name,
  required String path,
}) {
  final now = DateTime(2026, 7, 12);
  return EngramFile(
    id: id,
    filename: name,
    size: 2048,
    hash: id,
    filePath: path,
    deviceName: 'reliquary',
    status: 'ready',
    storageType: 's3',
    mimeType: 'application/pdf',
    mtime: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('FolderTile renders name and loaded item count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderTile(
            folder: const FolderEntry(name: '2026', path: '2026', count: 2),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2 loaded items'), findsOneWidget);
  });

  testWidgets('FolderRow calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderRow(
            folder: const FolderEntry(name: 'photos', path: 'photos', count: 1),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('photos'));
    expect(tapped, isTrue);
  });

  testWidgets('FileRow shows name, directory, size, and type context', (
    tester,
  ) async {
    final projection = GalleryFileProjection.fromFile(
      file(
        id: '1',
        name: 'docs/report.pdf',
        path: 'files/alice/2026/06/docs/report.pdf',
      ),
      showFullPath: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileRow(projection: projection, onTap: () {}),
        ),
      ),
    );

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('docs'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  group('folder scoping', () {
    // Folder scope is what makes Engram return a single directory. Search must
    // escape it, or results would be silently confined to the current folder.
    test('folder mode without a search is scoped', () {
      const state = FileListState(groupingMode: GalleryGroupingMode.folders);

      expect(state.isFolderScoped, isTrue);
    });

    test('an active search is never scoped', () {
      const state = FileListState(
        groupingMode: GalleryGroupingMode.folders,
        searchQuery: 'invoice',
      );

      expect(state.isFolderScoped, isFalse);
    });

    test('all-files mode is never scoped', () {
      const state = FileListState(groupingMode: GalleryGroupingMode.allFiles);

      expect(state.isFolderScoped, isFalse);
    });

    // Traversal segments are dropped, not resolved, so `..` can never walk out
    // of the tree. Engram's normalizeDisplayPath mirrors this exactly.
    test('searching drops folder scope and normalizes the path', () {
      final notifier = FileListNotifier(null, false);

      notifier.setFolder(
        groupingMode: GalleryGroupingMode.folders,
        folderPath: '/docs/../notes/',
      );
      expect(notifier.state.folderPath, 'docs/notes');
      expect(notifier.state.isFolderScoped, isTrue);

      notifier.setSearchQuery('invoice');
      expect(notifier.state.isFolderScoped, isFalse);
    });

    test('clearing the search restores folder scope', () {
      final notifier = FileListNotifier(null, false);
      notifier.setFolder(
        groupingMode: GalleryGroupingMode.folders,
        folderPath: 'docs',
      );

      notifier.setSearchQuery('invoice');
      notifier.setSearchQuery('');

      expect(notifier.state.isFolderScoped, isTrue);
      expect(notifier.state.folderPath, 'docs');
    });
  });
}

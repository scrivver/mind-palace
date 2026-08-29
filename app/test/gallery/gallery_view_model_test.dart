import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/models/engram_file.dart';
import 'package:mind_palace/widgets/gallery/gallery_view_model.dart';

EngramFile file({
  required String id,
  required String filename,
  required String path,
  String mime = 'text/plain',
}) {
  final now = DateTime(2026, 7, 12);
  return EngramFile(
    id: id,
    filename: filename,
    size: 1024,
    hash: id,
    filePath: path,
    deviceName: 'reliquary',
    status: 'ready',
    storageType: 's3',
    mimeType: mime,
    mtime: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('displayPathForFile', () {
    test('prefers filename when it contains a relative directory', () {
      final f = file(
        id: '1',
        filename: 'docs/myfile.pdf',
        path: 'files/alice/2026/06/docs/myfile.pdf',
      );

      expect(displayPathForFile(f), 'docs/myfile.pdf');
    });

    test('strips Reliquary storage date prefix from file path', () {
      final f = file(
        id: '1',
        filename: 'report.pdf',
        path: 'files/alice/2026/06/report.pdf',
      );

      expect(displayPathForFile(f), 'report.pdf');
    });

    test('recovers the folder path from a pre-008 basename filename', () {
      final f = file(
        id: '1',
        filename: 'report.pdf',
        path: 'files/alice/2026/07/docs/report.pdf',
      );

      expect(displayPathForFile(f), 'docs/report.pdf');
    });

    test('uses filename verbatim without consulting the storage key', () {
      final f = file(
        id: '1',
        filename: 'docs/report.pdf',
        path: 'akadmin/2026/06/report.pdf',
      );

      expect(displayPathForFile(f), 'docs/report.pdf');
    });

    test('returns the basename for pre-restructure storage keys', () {
      final f = file(
        id: '1',
        filename: 'report.pdf',
        path: 'akadmin/2026/06/report.pdf',
      );

      expect(displayPathForFile(f), 'report.pdf');
    });

    test('returns the basename for unrecognized storage keys', () {
      final f = file(id: '1', filename: 'notes.md', path: '/archive/notes.md');

      expect(displayPathForFile(f), 'notes.md');
    });

    test('never derives a directory from a pre-restructure storage key', () {
      final files = [
        file(
          id: '1',
          filename: 'report.pdf',
          path: 'akadmin/2026/06/report.pdf',
        ),
      ];

      final projections = visibleFilesFor(
        files: files,
        currentPath: '',
        showFullPath: false,
      );

      expect(projections.single.directoryPath, '');
      expect(projections.single.displayName, 'report.pdf');
    });
  });

  group('FolderEntry.fromJson', () {
    test('maps the Engram folder payload', () {
      final entry = FolderEntry.fromJson({
        'name': 'notes',
        'path': 'docs/notes',
        'file_count': 12,
      });

      expect(entry.name, 'notes');
      expect(entry.path, 'docs/notes');
      expect(entry.count, 12);
    });

    test('defaults a missing count to zero rather than throwing', () {
      final entry = FolderEntry.fromJson({'name': 'docs', 'path': 'docs'});

      expect(entry.count, 0);
    });
  });

  group('file projection', () {
    // Engram decides membership; these files are what it returned for the
    // current directory, so the projection must show all of them.
    final files = [
      file(
        id: '1',
        filename: '2026/06/report.pdf',
        path: 'files/alice/2026/06/report.pdf',
      ),
      file(
        id: '2',
        filename: '2026/06/notes.md',
        path: 'files/alice/2026/06/notes.md',
      ),
    ];

    test('labels files relative to the current directory', () {
      final visible = visibleFilesFor(
        files: files,
        currentPath: '2026/06',
        showFullPath: false,
      );

      expect(visible.map((p) => p.relativeLabel), ['notes.md', 'report.pdf']);
    });

    test('shows full display paths when not scoped to a folder', () {
      final visible = visibleFilesFor(
        files: files,
        currentPath: '',
        showFullPath: true,
      );

      expect(visible.map((p) => p.displayPath), [
        '2026/06/notes.md',
        '2026/06/report.pdf',
      ]);
    });

    // Regression guard for the trap that replaced client-side filtering: a row
    // the server placed here whose display path disagrees must still render,
    // not silently vanish from every directory.
    test('never drops a file whose display path disagrees with the scope', () {
      final visible = visibleFilesFor(
        files: [
          file(
            id: '9',
            filename: 'docs/deep/nested.pdf',
            path: 'files/alice/2026/06/docs/deep/nested.pdf',
          ),
        ],
        currentPath: 'somewhere/else',
        showFullPath: false,
      );

      expect(visible, hasLength(1));
    });

    test('all-files mode keeps directory context for duplicate names', () {
      final duplicateFiles = [
        file(
          id: '1',
          filename: 'a/report.pdf',
          path: 'files/alice/2026/06/a/report.pdf',
        ),
        file(
          id: '2',
          filename: 'b/report.pdf',
          path: 'files/alice/2026/06/b/report.pdf',
        ),
      ];
      final visible = visibleFilesFor(
        files: duplicateFiles,
        currentPath: 'a',
        showFullPath: true,
      );

      expect(visible.map((p) => p.displayPath), [
        'a/report.pdf',
        'b/report.pdf',
      ]);
      expect(visible.map((p) => p.directoryPath), ['a', 'b']);
    });
  });

  group('route state', () {
    test('parses invalid modes safely', () {
      final state = GalleryRouteState.fromQuery({
        'view': 'table',
        'group': 'tree',
        'path': '../2026//06',
      });

      expect(state.viewMode, GalleryViewMode.grid);
      expect(state.groupingMode, GalleryGroupingMode.allFiles);
      expect(state.folderPath.path, '2026/06');
    });

    test('round trips non-default query values', () {
      final state = GalleryRouteState(
        searchQuery: 'report',
        selectedType: 'pdf',
        selectedTags: {'work', 'tax'},
        viewMode: GalleryViewMode.list,
        groupingMode: GalleryGroupingMode.folders,
        folderPath: GalleryFolderPath('2026/06'),
      );

      expect(state.toQueryParameters(), {
        'q': 'report',
        'type': 'pdf',
        'tags': 'work,tax',
        'view': 'list',
        'group': 'folders',
        'path': '2026/06',
      });
    });
  });
}

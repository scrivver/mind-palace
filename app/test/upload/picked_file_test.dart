import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_palace/models/picked_file.dart';
import 'package:mind_palace/providers/upload_provider.dart';
import 'package:mind_palace/services/file_picker_native.dart';

void main() {
  group('basenameOfPath', () {
    test('strips posix and windows directories', () {
      expect(basenameOfPath('/home/u/Docs/a.pdf'), 'a.pdf');
      expect(basenameOfPath(r'C:\Users\u\Docs\a.pdf'), 'a.pdf');
      expect(basenameOfPath('a.pdf'), 'a.pdf');
    });
  });

  group('relativeToRoot', () {
    // The whole point of PickedFile: an absolute filesystem path must never
    // reach Reliquary as a relative upload path, or uploads land in folders
    // named after the user's home directory.
    test('makes a nested path relative to the chosen folder', () {
      expect(
        relativeToRoot('/home/u/Docs/sub/a.pdf', '/home/u/Docs'),
        'sub/a.pdf',
      );
    });

    test('handles a trailing separator on the base', () {
      expect(
        relativeToRoot('/home/u/Docs/sub/a.pdf', '/home/u/Docs/'),
        'sub/a.pdf',
      );
    });

    test('falls back to the basename when the file is outside the base', () {
      expect(relativeToRoot('/elsewhere/a.pdf', '/home/u/Docs'), 'a.pdf');
    });

    test('never returns an absolute path', () {
      final result = relativeToRoot('/home/u/Docs/a.pdf', '/home/u/Docs');

      expect(result.startsWith('/'), isFalse);
    });
  });

  group('PickedFile', () {
    PlatformFile plain(String name) => PlatformFile(name: name, size: 1);

    test('a plain selection carries no folder context', () {
      final picked = PickedFile(plain('a.pdf'));

      expect(picked.relativePath, isNull);
      expect(picked.name, 'a.pdf');
    });

    test('keeps the relative path alongside the basename', () {
      final picked = PickedFile(
        plain('a.pdf'),
        relativePath: 'Photos/2026/a.pdf',
      );

      expect(picked.name, 'a.pdf');
      expect(picked.relativePath, 'Photos/2026/a.pdf');
    });

    // Two files sharing a basename in different folders must stay distinct in
    // the upload list, which keys off the relative path when one exists.
    test('same basename in different folders yields distinct keys', () {
      final a = PickedFile(plain('a.pdf'), relativePath: 'x/a.pdf');
      final b = PickedFile(plain('a.pdf'), relativePath: 'y/a.pdf');

      expect(UploadNotifier.key(a), isNot(UploadNotifier.key(b)));
    });
  });
}

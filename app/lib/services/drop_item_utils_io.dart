import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart' as dd;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Expand DropItem entries on IO platforms. If a dropped path is a directory,
/// walk it recursively and return PlatformFile entries pointing to the files
/// (path set, bytes left null). If an item is a file, return a PlatformFile
/// with path set.
Future<List<PlatformFile>> expandDropItemsIo(List<dynamic> items) async {
  final out = <PlatformFile>[];
  for (final item in items) {
    final path = item.path;
    if (path == null) continue;

    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      final base = path;
      await for (final e in Directory(base).list(recursive: true)) {
        if (e is File) {
          final filePath = e.path;
          final size = await e.length();
          final rel = p.relative(filePath, from: base);
          out.add(PlatformFile(name: rel, size: size, path: filePath));
        }
      }
    } else if (entity == FileSystemEntityType.file) {
      final f = File(path);
      final size = await f.length();
      out.add(PlatformFile(name: p.basename(path), size: size, path: path));
    }
  }
  return out;
}

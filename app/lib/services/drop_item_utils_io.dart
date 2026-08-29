import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/picked_file.dart';

/// Expand DropItem entries on IO platforms. A dropped directory is walked
/// recursively; each file keeps its absolute `path` for byte reading and
/// carries its position inside the dropped folder as [PickedFile.relativePath].
/// A dropped file has no folder context.
Future<List<PickedFile>> expandDropItemsIo(List<dynamic> items) async {
  final out = <PickedFile>[];
  for (final item in items) {
    final path = item.path;
    if (path == null) continue;

    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.directory) {
      final base = path;
      final root = basenameOfPath(base);
      await for (final e in Directory(base).list(recursive: true)) {
        if (e is File) {
          final filePath = e.path;
          final size = await e.length();
          out.add(
            PickedFile(
              PlatformFile(
                name: basenameOfPath(filePath),
                size: size,
                path: filePath,
              ),
              // Rooted at the dropped folder's name, matching the shape the
              // browser produces for webkitRelativePath.
              relativePath: '$root/${_relativePath(filePath, base)}',
            ),
          );
        }
      }
    } else if (entity == FileSystemEntityType.file) {
      final f = File(path);
      final size = await f.length();
      out.add(
        PickedFile(
          PlatformFile(name: basenameOfPath(path), size: size, path: path),
        ),
      );
    }
  }
  return out;
}

String _relativePath(String filePath, String basePath) {
  final prefix = basePath.endsWith(Platform.pathSeparator)
      ? basePath
      : '$basePath${Platform.pathSeparator}';
  final relative = filePath.startsWith(prefix)
      ? filePath.substring(prefix.length)
      : basenameOfPath(filePath);
  return relative.replaceAll('\\', '/');
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../models/picked_file.dart';

Future<List<PickedFile>?> pickFiles({bool allowMultiple = true}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type: FileType.any,
  );
  if (result == null || result.files.isEmpty) return null;
  // A plain file selection carries no folder context. `path` stays absolute so
  // byte reading works, and is deliberately not offered as a relative path.
  return result.files.map((f) => PickedFile(f)).toList();
}

Future<List<PickedFile>?> pickFolder() async {
  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null) return null;

  final dir = Directory(dirPath);
  final root = basenameOfPath(dirPath);
  final files = <PickedFile>[];

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      final stat = await entity.stat();
      files.add(
        PickedFile(
          PlatformFile(
            name: basenameOfPath(entity.path),
            size: stat.size,
            path: entity.path,
          ),
          // Rooted at the chosen folder's name so it matches the shape of the
          // browser's webkitRelativePath.
          relativePath: '$root/${relativeToRoot(entity.path, dirPath)}',
        ),
      );
    }
  }

  if (files.isEmpty) return null;
  return files;
}

/// Path of [filePath] relative to [basePath], or its basename when it does not
/// sit under that base.
String relativeToRoot(String filePath, String basePath) {
  final prefix = basePath.endsWith(Platform.pathSeparator)
      ? basePath
      : '$basePath${Platform.pathSeparator}';
  final relative = filePath.startsWith(prefix)
      ? filePath.substring(prefix.length)
      : basenameOfPath(filePath);
  return relative.replaceAll('\\', '/');
}

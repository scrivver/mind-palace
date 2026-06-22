import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type: FileType.any,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files;
}

Future<List<PlatformFile>?> pickFolder() async {
  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null) return null;

  final dir = Directory(dirPath);
  final files = <PlatformFile>[];

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      final stat = await entity.stat();
      files.add(PlatformFile(
        name: p.basename(entity.path),
        size: stat.size,
        path: entity.path,
      ));
    }
  }

  if (files.isEmpty) return null;
  return files;
}

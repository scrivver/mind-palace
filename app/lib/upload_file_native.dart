import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';

Future<List<int>> readPlatformFileBytes(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes != null) return bytes;
  final path = file.path;
  if (path == null) {
    throw Exception('No file data available for ${file.name}');
  }
  return File(path).readAsBytes();
}

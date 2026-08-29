import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Asks where to put the file, then writes bytes already fetched over an
/// authenticated request. Returns without writing if the user cancels.
Future<void> saveBytes(
  String filename,
  Uint8List bytes,
  String contentType,
) async {
  final path = await FilePicker.platform.saveFile(fileName: filename);
  if (path == null) return;
  await File(path).writeAsBytes(bytes, flush: true);
}

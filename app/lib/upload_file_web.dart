import 'package:file_picker/file_picker.dart';

Future<List<int>> readPlatformFileBytes(PlatformFile file) async {
  final bytes = file.bytes;
  if (bytes == null) {
    throw Exception('No file data available for ${file.name}');
  }
  return bytes;
}

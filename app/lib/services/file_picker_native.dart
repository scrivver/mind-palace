import 'package:file_picker/file_picker.dart';

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    type: FileType.any,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files;
}

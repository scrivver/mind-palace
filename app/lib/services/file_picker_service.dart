import 'package:file_picker/file_picker.dart';

import 'file_picker_native.dart'
    if (dart.library.js_interop) 'file_picker_web.dart'
    as impl;

Future<List<PlatformFile>?> pickFiles({bool allowMultiple = true}) {
  return impl.pickFiles(allowMultiple: allowMultiple);
}

import '../models/picked_file.dart';

import 'file_picker_native.dart'
    if (dart.library.html) 'file_picker_web.dart'
    as impl;

Future<List<PickedFile>?> pickFiles({bool allowMultiple = true}) {
  return impl.pickFiles(allowMultiple: allowMultiple);
}

Future<List<PickedFile>?> pickFolder() {
  return impl.pickFolder();
}
